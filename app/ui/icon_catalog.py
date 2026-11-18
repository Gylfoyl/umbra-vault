"""Bundled 24-unit stroke SVG library for entry icons."""

# Shapes use one coordinate grid and inherit the active entry accent.
ICONS = {
    "folder": ("Папка", "Базовые", "folder", "M3 6h7l2 2h9v11H3z"),
    "key": ("Ключ", "Базовые", "key password пароль", "M14 7a5 5 0 1 0-4 8l2 2h3v-3h3v-3l2-2"),
    "note": ("Заметка", "Базовые", "note document", "M6 3h8l4 4v14H6zM14 3v5h4M9 12h6m-6 4h6"),
    "shield": ("Щит", "Базовые", "shield security защита", "m12 3 8 3v6c0 4-3 6-8 9-5-3-8-5-8-9V6zM8.5 12l2 2 5-5"),
    "lock": ("Замок", "Базовые", "lock пароль", "M5 10h14v10H5zM8 10V7a4 4 0 1 1 8 0v3m-4 4v2"),
    "star": ("Звезда", "Базовые", "star favorite избранное", "m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-2.9L6.4 20l1.1-6.2L3 9.5l6.2-.9z"),
    "heart": ("Сердце", "Личное", "heart health здоровье", "M12 20 4.5 13a5 5 0 1 1 7.5-6 5 5 0 1 1 7.5 6z"),
    "home": ("Дом", "Личное", "home house", "m3 10 9-7 9 7M6 9v11h12V9M10 20v-6h4v6"),
    "plane": ("Путешествие", "Личное", "plane travel самолёт", "m3 12 7 2 3 7 2-1-1-7 6-6a2 2 0 0 0-3-3l-6 6-7-1z"),
    "gift": ("Подарок", "Личное", "gift shopping покупки", "M4 10h16v3H4zm2 3v7h12v-7M12 10v10m0-10H8a2 2 0 1 1 2-3l2 3Zm0 0h4a2 2 0 1 0-2-3z"),
    "camera": ("Камера", "Личное", "camera photo фото", "M3 7h4l2-3h6l2 3h4v13H3zM16 13a4 4 0 1 1-8 0 4 4 0 1 1 8 0Z"),
    "book": ("Книга", "Личное", "book reading чтение", "M12 5c-3-2-6-2-9-1v14c3-1 6-1 9 1 3-2 6-2 9-1V4c-3-1-6-1-9 1Zm0 0v14"),
    "globe": ("Веб-сайт", "Сервисы", "web globe сайт", "M21 12a9 9 0 1 1-18 0 9 9 0 1 1 18 0ZM3.5 12h17M12 3c5 5 5 13 0 18-5-5-5-13 0-18z"),
    "mail": ("Почта", "Сервисы", "mail email письмо", "M3 5h18v14H3zM3 6l9 7 9-7"),
    "cloud": ("Облако", "Сервисы", "cloud storage", "M7 18a4 4 0 0 1-1-8 6 6 0 0 1 11-2 5 5 0 0 1 0 10z"),
    "wifi": ("Wi-Fi", "Сервисы", "wifi internet сеть", "M3 8a14 14 0 0 1 18 0M6 12a9 9 0 0 1 12 0m-9 4a5 5 0 0 1 6 0m-3 4h.01"),
    "phone": ("Телефон", "Сервисы", "phone mobile", "M7 3h10v18H7zM11 17h2"),
    "wallet": ("Кошелёк", "Сервисы", "wallet money банк оплата", "M20 8V5H5a2 2 0 0 0-2 2v11h17V8H5a1 1 0 0 1 0-2m15 5h-6v4h6m-3-2h.01"),
    "code": ("Код", "Работа", "code git разработка", "m8 6-6 6 6 6m8-12 6 6-6 6m-2-15-4 18"),
    "terminal": ("Терминал", "Работа", "terminal cli console консоль", "M3 5h18v14H3zm4 4 3 3-3 3m6 0h4"),
    "briefcase": ("Портфель", "Работа", "briefcase work офис", "M3 8h18v12H3zm5 0V4h8v4M3 13h18m-9-2v4"),
    "design": ("Палитра", "Работа", "design palette дизайн", "M21 12a9 9 0 1 0-10 9c2 0 3-1 2-3s0-3 3-3h2a3 3 0 0 0 3-3ZM7 11h.01M10 7h.01M15 7h.01M18 10h.01"),
    "layers": ("Слои", "Работа", "layers project проект", "m12 3 9 5-9 5-9-5zm-9 9 9 5 9-5M3 16l9 5 9-5"),
    "server": ("Сервер", "Работа", "server database база", "M3 4h18v7H3zm0 9h18v7H3zM7 7.5h.01M7 16.5h.01"),
}


def catalog():
    return [
        {"id": key, "label": label, "category": category, "keywords": keywords}
        for key, (label, category, keywords, _) in ICONS.items()
    ]


def svg_for(key, ink):
    path = ICONS[key][3]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        f'<path fill="none" stroke="{ink}" stroke-width="1.7" '
        f'stroke-linecap="round" stroke-linejoin="round" d="{path}"/></svg>'
    ).encode("ascii")
