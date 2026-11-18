"""Generate passwords with the operating system's cryptographic randomness."""

import secrets
import string

SYMBOLS = "!@#$%^&*()-_=+[]{}:,.?"


def generate_password(length: int, lower: bool, upper: bool, digits: bool, symbols: bool) -> str:
    if not 8 <= length <= 128:
        raise ValueError("Длина пароля должна быть от 8 до 128 символов.")

    groups = [
        alphabet
        for enabled, alphabet in (
            (lower, string.ascii_lowercase),
            (upper, string.ascii_uppercase),
            (digits, string.digits),
            (symbols, SYMBOLS),
        )
        if enabled
    ]
    if not groups:
        raise ValueError("Выберите хотя бы один набор символов.")

    alphabet = "".join(groups)
    while True:
        password = "".join(secrets.choice(alphabet) for _ in range(length))
        if all(any(character in group for character in password) for group in groups):
            return password
