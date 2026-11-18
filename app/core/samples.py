"""Source-only demo data. Excluded from the Windows installer."""

from app.core.entries import Entry

DEMO_CODE = "demo"


def sample_entries():
    return [
        Entry("Linear", username="alex@example.test", password="Sample-Linear-29!",
              url="https://linear.example.test", tags=("Работа",), favorite=True,
              id="sample-linear", icon="layers", accent="violet"),
        Entry("GitHub", username="alex-dev", password="Sample-GitHub-63!",
              url="https://github.example.test", tags=("Разработка",), favorite=True,
              id="sample-github", icon="code", accent="indigo"),
        Entry("Figma", username="alex@example.test", password="Sample-Figma-41!",
              url="https://figma.example.test", tags=("Дизайн",),
              id="sample-figma", icon="design", accent="rose"),
        Entry("Домашняя сеть", username="guest", password="Sample-Wifi-74!",
              tags=("Личное",), id="sample-network", icon="wifi", accent="teal"),
        Entry("Поездка в Берлин", kind="note", notes="Вымышленные данные: рейс UV 204.",
              tags=("Личное",), id="sample-trip", icon="plane", accent="sky"),
        Entry("Лицензии и подписки", kind="note",
              notes="Пример заметки о подписках.", tags=("Работа",),
              id="sample-licenses", icon="note", accent="amber"),
    ]
