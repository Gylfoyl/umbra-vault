import string
import unittest

from app.core.entries import Entry
from app.services.generator import SYMBOLS, generate_password


class EntryTest(unittest.TestCase):
    def test_search_filters_metadata_and_category(self):
        entry = Entry("Пример", username="sam", password="secret", notes="private",
                      tags=("Работа",), favorite=True)
        self.assertTrue(entry.matches("favorites", "РАБОТА пример"))
        self.assertTrue(entry.matches("password", "sam"))
        self.assertFalse(entry.matches("note", "sam"))
        self.assertFalse(entry.matches("all", "secret"))
        self.assertFalse(entry.matches("all", "private"))


class GeneratorTest(unittest.TestCase):
    def test_each_enabled_group_is_represented(self):
        password = generate_password(20, True, True, True, True)
        self.assertEqual(len(password), 20)
        for group in (string.ascii_lowercase, string.ascii_uppercase, string.digits, SYMBOLS):
            self.assertTrue(set(password).intersection(group))

    def test_single_group_and_invalid_inputs(self):
        self.assertTrue(generate_password(128, False, False, True, False).isdigit())
        with self.assertRaises(ValueError):
            generate_password(7, True, True, True, False)
        with self.assertRaises(ValueError):
            generate_password(20, False, False, False, False)
