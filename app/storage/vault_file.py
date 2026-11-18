"""Bounded serialization, atomic saves and optimistic concurrency control."""

import base64
import binascii
import json
from contextlib import contextmanager
from dataclasses import asdict, dataclass, field, replace
from hashlib import sha256
from pathlib import Path

from PySide6.QtCore import QIODevice, QLockFile, QSaveFile

from app.core.appearance import ACCENT_IDS
from app.core.entries import Entry, Folder
from app.security.envelope import MAX_FILE, SessionKey, VaultError, decrypt, encrypt, new_key

MAX_RECORDS = 4000
MAX_FOLDERS = 256
MAX_FOLDER_NAME = 80
MAX_ICON_BYTES = 128 * 1024
TEXT_LIMITS = {
    "id": 64, "title": 240, "kind": 8, "username": 512, "password": 8192,
    "url": 2048, "notes": 128 * 1024, "icon": 96, "accent": 24,
}
RECORD_KEYS = TEXT_LIMITS.keys() | {"tags", "favorite"}


@dataclass(frozen=True)
class OpenVault:
    key: SessionKey = field(repr=False)
    revision: bytes
    folders: dict[str, Folder]


def _folders(payload):
    folders = payload.get("folders", {})
    if type(folders) is not dict or len(folders) > MAX_FOLDERS:
        raise ValueError()
    names = set()
    result = {}
    for folder_id, value in folders.items():
        if isinstance(value, str):
            name, accent = value, ""
        elif type(value) is dict and value.keys() == {"name", "accent"}:
            name, accent = value["name"], value["accent"]
        else:
            raise ValueError()
        if (type(folder_id) is not str or not 1 <= len(folder_id) <= 64
                or type(name) is not str or not name.strip() or len(name) > MAX_FOLDER_NAME
                or name.casefold() in names or type(accent) is not str
                or (accent and accent not in ACCENT_IDS)):
            raise ValueError()
        folder_id.encode("utf-8")
        name.encode("utf-8")
        names.add(name.casefold())
        result[folder_id] = Folder(name, accent)
    return result


def _records(payload):
    entries = payload["entries"]
    icons = payload["icons"]
    if type(entries) is not list or len(entries) > MAX_RECORDS or type(icons) is not dict:
        raise ValueError()
    result = []
    folders = _folders(payload)
    ids = set()
    for item in entries:
        if type(item) is not dict or item.keys() - {"folder"} != RECORD_KEYS:
            raise ValueError()
        folder = item.get("folder", "")
        if type(folder) is not str or (folder and folder not in folders):
            raise ValueError()
        for name, limit in TEXT_LIMITS.items():
            if type(item[name]) is not str or len(item[name]) > limit:
                raise ValueError()
            item[name].encode("utf-8")
        if (not item["id"] or item["id"] in ids or not item["title"].strip()
                or item["kind"] not in ("password", "note") or type(item["favorite"]) is not bool):
            raise ValueError()
        tags = item["tags"]
        if type(tags) not in (list, tuple) or len(tags) > 256 or any(
            type(tag) is not str or len(tag) > 512 for tag in tags
        ):
            raise ValueError()
        ids.add(item["id"])
        result.append(Entry(**{**item, "tags": tuple(tags)}))

    used = {entry.icon for entry in result if entry.icon.startswith("custom-")}
    if used != icons.keys():
        raise ValueError()
    return result, icons, folders


def _encode(entries, images, folders):
    try:
        records = [asdict(entry) for entry in entries]
        for record in records:
            if not record["folder"]:
                del record["folder"]
        icons = {icon: base64.b64encode(images[icon]).decode("ascii")
                 for icon in {entry.icon for entry in entries if entry.icon.startswith("custom-")}}
        payload = {"entries": records, "icons": icons}
        if folders:
            payload["folders"] = {
                folder_id: asdict(folder) if folder.accent else folder.name
                for folder_id, folder in folders.items()
            }
        _records(payload)
        return json.dumps(payload, ensure_ascii=False,
                          separators=(",", ":")).encode("utf-8")
    except (KeyError, ValueError, UnicodeError):
        raise VaultError("Запись превышает допустимые размеры или содержит ошибку.") from None


def _decode(raw):
    try:
        payload = json.loads(raw.decode("utf-8"))
        if type(payload) is not dict or payload.keys() - {"folders"} != {"entries", "icons"}:
            raise ValueError()
        entries, images, folders = _records(payload)
        decoded = {}
        for icon, encoded in images.items():
            if not isinstance(encoded, str) or len(encoded) > ((MAX_ICON_BYTES + 2) // 3) * 4:
                raise ValueError()
            png = base64.b64decode(encoded, validate=True)
            if len(png) > MAX_ICON_BYTES or icon != "custom-" + sha256(png).hexdigest():
                raise ValueError()
            decoded[icon] = png
        return entries, decoded, folders
    except (KeyError, ValueError, UnicodeError, RecursionError, binascii.Error):
        raise VaultError("Файл содержит повреждённые записи.") from None


def _read(path: Path):
    try:
        with path.open("rb") as source:
            return source.read(MAX_FILE + 1)
    except OSError:
        raise VaultError("Не удалось прочитать файл хранилища.") from None


@contextmanager
def _write_lock(path: Path):
    lock = QLockFile(str(path.with_suffix(path.suffix + ".lock")))
    lock.setStaleLockTime(0)
    if not lock.tryLock(0):
        raise VaultError("Не удалось заблокировать файл для записи. Проверьте права и открытые копии.")
    try:
        yield
    finally:
        lock.unlock()


def _atomic_write(path: Path, ciphertext: bytes):
    output = QSaveFile(str(path))
    output.setDirectWriteFallback(False)
    if not output.open(QIODevice.OpenModeFlag.WriteOnly):
        raise VaultError("Не удалось создать временный файл хранилища.")
    if output.write(ciphertext) != len(ciphertext):
        output.cancelWriting()
        raise VaultError("Не удалось записать хранилище. Проверьте свободное место.")
    if not output.commit():
        raise VaultError("Не удалось заменить файл хранилища. Проверьте доступ к папке.")


def create(path: Path, password: str) -> tuple[OpenVault, list[Entry], dict[str, bytes]]:
    key = new_key(password)
    ciphertext = encrypt(key, _encode([], {}, {}))
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        raise VaultError("Не удалось создать папку хранилища.") from None
    with _write_lock(path):
        if path.exists():
            raise VaultError("Хранилище уже существует. Откройте его с мастер-паролем.")
        _atomic_write(path, ciphertext)
    return OpenVault(key, sha256(ciphertext).digest(), {}), [], {}


def open_vault(path: Path, password: str) -> tuple[OpenVault, list[Entry], dict[str, bytes]]:
    raw = _read(path)
    key, payload = decrypt(password, raw)
    entries, images, folders = _decode(payload)
    return OpenVault(key, sha256(raw).digest(), folders), entries, images


def save(path: Path, state: OpenVault, entries, images, folders=None) -> OpenVault:
    folders = state.folders if folders is None else folders
    ciphertext = encrypt(state.key, _encode(entries, images, folders))
    with _write_lock(path):
        if sha256(_read(path)).digest() != state.revision:
            raise VaultError("Файл изменился в другом окне. Заблокируйте и откройте хранилище снова.")
        _atomic_write(path, ciphertext)
    return replace(state, revision=sha256(ciphertext).digest(), folders=folders)
