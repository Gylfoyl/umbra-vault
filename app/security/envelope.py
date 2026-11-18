"""Version 1 authenticated file envelope."""

import secrets
from dataclasses import dataclass, field
from struct import Struct

MAGIC = b"UMBRAVLT"
VERSION = 1
HEADER = Struct(">8sBIIB16s12s")
MAX_PAYLOAD = 8 * 1024 * 1024
MAX_FILE = HEADER.size + MAX_PAYLOAD + 16


class VaultError(Exception):
    """User-facing error messages contain no user data."""


@dataclass(frozen=True)
class Kdf:
    memory: int = 65_536
    time: int = 3
    parallelism: int = 2

    def validate(self):
        if not (32_768 <= self.memory <= 262_144 and 2 <= self.time <= 5
                and 1 <= self.parallelism <= 4):
            raise VaultError("Файл содержит неподдерживаемые параметры защиты.")


@dataclass(frozen=True)
class SessionKey:
    kdf: Kdf
    salt: bytes
    value: bytes = field(repr=False)


def _derive(password: str, kdf: Kdf, salt: bytes) -> SessionKey:
    kdf.validate()
    from argon2.exceptions import HashingError
    from argon2.low_level import Type, hash_secret_raw

    try:
        encoded = password.encode("utf-8")
        if not encoded:
            raise VaultError("Введите мастер-пароль.")
        key = hash_secret_raw(encoded, salt, time_cost=kdf.time, memory_cost=kdf.memory,
                              parallelism=kdf.parallelism, hash_len=32, type=Type.ID, version=19)
    except (HashingError, UnicodeError):
        raise VaultError("Не удалось обработать мастер-пароль.") from None
    return SessionKey(kdf, salt, key)


def new_key(password: str) -> SessionKey:
    return _derive(password, Kdf(), secrets.token_bytes(16))


def encrypt(key: SessionKey, payload: bytes) -> bytes:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    if len(payload) > MAX_PAYLOAD:
        raise VaultError("Достигнут предел размера хранилища (8 МиБ).")
    nonce = secrets.token_bytes(12)
    header = HEADER.pack(MAGIC, VERSION, key.kdf.memory, key.kdf.time,
                         key.kdf.parallelism, key.salt, nonce)
    return header + AESGCM(key.value).encrypt(nonce, payload, header)


def decrypt(password: str, blob: bytes) -> tuple[SessionKey, bytes]:
    from cryptography.exceptions import InvalidTag
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    if not HEADER.size + 16 <= len(blob) <= MAX_FILE:
        raise VaultError("Файл неполный или превышает допустимый размер.")
    magic, version, mem, time, parallelism, salt, nonce = HEADER.unpack_from(blob)
    if magic != MAGIC:
        raise VaultError("Файл не распознан как хранилище Umbra Vault.")
    if version != VERSION:
        raise VaultError("Версия формата хранилища не поддерживается.")
    key = _derive(password, Kdf(mem, time, parallelism), salt)
    try:
        return key, AESGCM(key.value).decrypt(nonce, blob[HEADER.size:], blob[:HEADER.size])
    except InvalidTag:
        raise VaultError("Мастер-пароль неверен или файл повреждён.") from None
