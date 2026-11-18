"""Stable identifiers for the built-in entry accents and application themes."""

DEFAULT_THEME = "umbra"
THEMES = (DEFAULT_THEME, "midnight", "snow", "forest", "graphite")
THEME_ALIASES = {"light": "snow", "dark": DEFAULT_THEME, "system": DEFAULT_THEME}

ACCENTS = (
    ("violet", "Фиолетовый", "#c7b4fc", "#6743a1"),
    ("indigo", "Индиго", "#b3bbff", "#4653a8"),
    ("blue", "Синий", "#a2c9ff", "#275c9d"),
    ("sky", "Голубой", "#8bd7fc", "#226784"),
    ("teal", "Бирюзовый", "#85ded4", "#14675e"),
    ("green", "Зелёный", "#a9dea8", "#346b3a"),
    ("lime", "Лаймовый", "#cddd90", "#54681e"),
    ("amber", "Янтарный", "#f6d185", "#795413"),
    ("orange", "Оранжевый", "#ffbb92", "#904410"),
    ("red", "Красный", "#ffadb0", "#983b44"),
    ("rose", "Розовый", "#f4b2d2", "#884267"),
    ("slate", "Сланцевый", "#c2cbd8", "#48596e"),
)
ACCENT_IDS = {item[0] for item in ACCENTS}
