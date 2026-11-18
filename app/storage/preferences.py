"""Local preferences. The records themselves belong to the demo process."""

from PySide6.QtCore import QByteArray, QSettings


class Preferences:
    def __init__(self, settings: QSettings | None = None):
        self.settings = settings if settings is not None else QSettings(
            "Umbra Vault", "Umbra Vault"
        )

    def get(self, key, default):
        return self.settings.value(key, default, type=type(default))

    def set(self, key, value):
        self.settings.setValue(key, value)

    def sample_style(self, entry):
        prefix = f"samples/{entry.id}"
        return (
            self.get(f"{prefix}/icon", entry.icon),
            self.get(f"{prefix}/accent", entry.accent),
            bytes(self.settings.value(f"{prefix}/png", QByteArray(), type=QByteArray)),
        )

    def set_sample_style(self, entry_id, icon, accent, png):
        self.set(f"samples/{entry_id}/icon", icon)
        self.set(f"samples/{entry_id}/accent", accent)
        self.set(f"samples/{entry_id}/png", QByteArray(png))
