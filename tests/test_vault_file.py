import base64
import json
import unittest
from pathlib import Path
from hashlib import sha256
from tempfile import TemporaryDirectory
from unittest.mock import patch

from app.core.entries import Entry, Folder
from app.security.envelope import HEADER, VaultError, encrypt
from app.storage import vault_file

PASSWORD = "Correct horse test only!"


class VaultFileTest(unittest.TestCase):
    def setUp(self):
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "profile" / "vault.umbra"
        self.state, _, _ = vault_file.create(self.path, PASSWORD)

    def test_authentication_round_trip_and_fresh_nonces(self):
        initial = self.path.read_bytes()
        entry = Entry("Пример", username="fixture-user", password="example fixture password",
                      notes="Не публиковать", accent="red", icon="lock", tags=("тег",))
        state = vault_file.save(self.path, self.state, [entry], {})
        first = self.path.read_bytes()
        vault_file.save(self.path, state, [entry], {})
        second = self.path.read_bytes()
        nonces = {HEADER.unpack_from(blob)[-1] for blob in (initial, first, second)}
        self.assertEqual(len(nonces), 3)
        for secret in (PASSWORD, entry.password, entry.username, entry.notes):
            self.assertNotIn(secret.encode("utf-8"), second)
        self.assertEqual(vault_file.open_vault(self.path, PASSWORD)[1], [entry])
        self.assertEqual(list(self.path.parent.iterdir()), [self.path])
        with self.assertRaisesRegex(VaultError, "неверен"):
            vault_file.open_vault(self.path, "incorrect master password")

    def test_corruption_unsupported_versions_and_bounded_kdf(self):
        original = self.path.read_bytes()
        damaged = bytearray(original)
        damaged[-1] ^= 1
        self.path.write_bytes(damaged)
        with self.assertRaisesRegex(VaultError, "повреждён"):
            vault_file.open_vault(self.path, PASSWORD)

        fields = list(HEADER.unpack_from(original))
        fields[1] = 99
        self.path.write_bytes(HEADER.pack(*fields) + original[HEADER.size:])
        with self.assertRaisesRegex(VaultError, "Версия"):
            vault_file.open_vault(self.path, PASSWORD)

        fields[1] = 1
        fields[2] = 2**31
        self.path.write_bytes(HEADER.pack(*fields) + original[HEADER.size:])
        with patch("argon2.low_level.hash_secret_raw") as derive:
            with self.assertRaisesRegex(VaultError, "параметры"):
                vault_file.open_vault(self.path, PASSWORD)
            derive.assert_not_called()

        bad_payload = json.dumps({"entries": [None], "icons": {}}).encode()
        self.path.write_bytes(encrypt(self.state.key, bad_payload))
        with self.assertRaisesRegex(VaultError, "повреждённые записи"):
            vault_file.open_vault(self.path, PASSWORD)

    def test_failed_atomic_write_and_stale_session_preserve_previous_file(self):
        original = self.path.read_bytes()
        with patch("app.storage.vault_file._atomic_write", side_effect=VaultError("disk full")):
            with self.assertRaises(VaultError):
                vault_file.save(self.path, self.state, [Entry("Новая")], {})
        self.assertEqual(self.path.read_bytes(), original)
        with self.assertRaisesRegex(VaultError, "уже существует"):
            vault_file.create(self.path, PASSWORD)
        self.assertEqual(self.path.read_bytes(), original)

        entry = Entry("Победитель")
        vault_file.save(self.path, self.state, [entry], {})
        with self.assertRaisesRegex(VaultError, "другом окне"):
            vault_file.save(self.path, self.state, [Entry("Старая сессия")], {})
        self.assertEqual(vault_file.open_vault(self.path, PASSWORD)[1], [entry])

    def test_custom_icon_and_accent_round_trip(self):
        png = base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aDaQAAAAASUVORK5CYII="
        )
        icon = "custom-" + sha256(png).hexdigest()
        entry = Entry("Иконка", icon=icon, accent="teal")
        state = vault_file.save(self.path, self.state, [entry], {icon: png})
        self.assertNotIn(png, self.path.read_bytes())
        self.assertEqual(vault_file.open_vault(self.path, PASSWORD)[1:], ([entry], {icon: png}))
        vault_file.save(self.path, state, [], {})
        self.assertEqual(vault_file.open_vault(self.path, PASSWORD)[1:], ([], {}))

    def test_existing_vault_without_folders_can_be_extended(self):
        legacy = {"entries": [{
            "id": "original", "title": "Старая запись", "kind": "password", "username": "",
            "password": "fixture", "url": "", "notes": "", "tags": [], "favorite": False,
            "icon": "", "accent": "",
        }], "icons": {}}
        self.path.write_bytes(encrypt(self.state.key, json.dumps(legacy).encode()))
        state, entries, images = vault_file.open_vault(self.path, PASSWORD)
        self.assertEqual(state.folders, {})
        self.assertEqual(entries[0].folder, "")
        self.assertEqual(entries[0].password, "fixture")
        folders = {"empty": Folder("Пустая папка")}
        vault_file.save(self.path, state, entries, images, folders)
        updated, reopened, _ = vault_file.open_vault(self.path, PASSWORD)
        self.assertEqual(updated.folders, folders)
        self.assertEqual(reopened, entries)
        self.assertNotIn("Пустая папка".encode(), self.path.read_bytes())

        legacy["folders"] = {"work": "Работа"}
        legacy["entries"][0]["folder"] = "work"
        self.path.write_bytes(encrypt(state.key, json.dumps(legacy).encode()))
        updated, reopened, _ = vault_file.open_vault(self.path, PASSWORD)
        self.assertEqual(updated.folders, {"work": Folder("Работа")})
        self.assertEqual(reopened[0].folder, "work")
