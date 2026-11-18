"""Qt bridge for locked and unlocked vault sessions."""

import secrets
from dataclasses import replace
from pathlib import Path
from uuid import uuid4

from PySide6.QtCore import QEvent, QMimeData, QObject, Property, Qt, QThreadPool, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication

from app.core.entries import Entry, Folder
from app.core.appearance import ACCENTS, ACCENT_IDS, DEFAULT_THEME, THEMES, THEME_ALIASES
from app.metadata import VERSION
from app.services.generator import generate_password
from app.storage.preferences import Preferences
from app.storage import vault_file
from app.ui.icon_catalog import ICONS, catalog
from app.ui.icons import EntryIconProvider, import_icon, stored_icon_is_valid
from app.ui.vault_job import VaultJob

CLIPBOARD_MARKER = "application/x-umbra-vault-copy"
WINDOWS_CLIPBOARD_EXCLUSION = 'application/x-qt-windows-mime;value="ExcludeClipboardContentFromMonitorProcessing"'
ACTIVITY_EVENTS = {
    QEvent.Type.KeyPress,
    QEvent.Type.MouseButtonPress,
    QEvent.Type.MouseMove,
    QEvent.Type.Wheel,
    QEvent.Type.TouchBegin,
}


class DemoController(QObject):
    routeChanged = Signal()
    listChanged = Signal()
    detailChanged = Signal()
    settingsChanged = Signal()
    feedback = Signal(str)
    busyChanged = Signal()
    operationErrorChanged = Signal()
    entrySaveFinished = Signal(str)

    def __init__(self, parent=None, *, preferences=None, path=None, demo=None, default_path=None):
        super().__init__(parent)
        self._path = path
        self._demo = path is None if demo is None else demo
        self._default_path = default_path
        self._route = ("welcome" if self._demo else "vaultPicker" if path is None
                       else "locked" if path.exists() else "setup")
        self._session = None
        self._busy = False
        self._operation_error = ""
        self._job_number = 0
        self._completion = None
        self._entries: list[Entry] | None = None
        self._folders: dict[str, Folder] = {}
        self._selected = ""
        self._section = "all"
        self._query = ""
        self._preferences = preferences if preferences is not None else Preferences()
        self._icon_data: dict[str, bytes] = {}
        self._pending_icon = ""
        theme = self._preferences.get("ui/theme", DEFAULT_THEME)
        theme = THEME_ALIASES.get(theme, theme)
        self._theme = theme if theme in THEMES else DEFAULT_THEME
        self._compact = self._preferences.get("ui/compact", False)
        self._collapsed = self._preferences.get("ui/collapsed", False)
        self._reduced_motion = self._preferences.get("ui/reducedMotion", False)
        minutes = self._preferences.get("security/idleMinutes", 5)
        self._idle_minutes = minutes if minutes in (0, 1, 5, 10, 15) else 5

        self._idle = QTimer(self, singleShot=True)
        self._idle.timeout.connect(self.lock)
        self._clipboard_timer = QTimer(self, singleShot=True, interval=20_000)
        self._clipboard_timer.timeout.connect(self.clear_clipboard)
        self._copied: tuple[str, bytes] | None = None

        app = QGuiApplication.instance()
        app.installEventFilter(self)
        app.aboutToQuit.connect(self.clear_clipboard)

    def eventFilter(self, watched, event):
        if self._route == "workspace" and event.type() in ACTIVITY_EVENTS:
            self._restart_idle()
        return False

    def _restart_idle(self):
        if self._idle_minutes:
            self._idle.start(self._idle_minutes * 60_000)

    def icon_provider(self):
        return EntryIconProvider(self._icon_data)

    @Property("QVariantList", constant=True)
    def iconCatalog(self):
        return catalog()

    @Property("QVariantList", constant=True)
    def entryAccents(self):
        return [
            {"id": key, "label": label, "dark": dark, "light": light}
            for key, label, dark, light in ACCENTS
        ]

    @Property(str, notify=routeChanged)
    def route(self):
        return self._route

    @Property(str, constant=True)
    def demoCode(self):
        if not self.demoMode:
            return ""
        from app.core.samples import DEMO_CODE
        return DEMO_CODE

    @Property(bool, constant=True)
    def demoMode(self):
        return self._demo

    @Property(str, notify=routeChanged)
    def vaultFileName(self):
        return self._path.name if self._path is not None else ""

    @Property(str, notify=routeChanged)
    def vaultFilePath(self):
        return str(self._path) if self._path is not None else ""

    def _recent_path(self):
        saved = self._preferences.get("vault/recentPath", "")
        path = Path(saved) if saved else None
        try:
            if path is not None and path.is_absolute() and path.is_file():
                return path
            if self._default_path is not None and self._default_path.is_file():
                return self._default_path
        except OSError:
            pass
        return None

    @Property(str, notify=routeChanged)
    def recentVaultName(self):
        if self._route != "vaultPicker":
            return ""
        path = self._recent_path()
        return path.name if path is not None else ""

    @Slot()
    def openRecentVault(self):
        if self._route == "vaultPicker":
            path = self._recent_path()
            if path is not None:
                self.chooseVault(QUrl.fromLocalFile(str(path)), False)

    @Slot(QUrl, bool)
    def chooseVault(self, url, creating):
        if self._route != "vaultPicker" or self._busy:
            return
        self.clearOperationError()
        try:
            raw = Path(url.toLocalFile())
            if not url.isLocalFile() or not raw.is_absolute():
                raise ValueError("Выберите файл хранилища.")
            path = raw.resolve()
            if creating:
                if path.exists():
                    raise ValueError("Файл уже существует. Выберите другое имя или откройте его.")
                if not path.parent.is_dir():
                    raise ValueError("Выберите существующую папку.")
            elif not path.is_file():
                raise ValueError("Файл хранилища не найден.")
        except ValueError as error:
            self._operation_error = str(error)
        except (OSError, RuntimeError):
            self._operation_error = "Не удалось получить доступ к выбранному файлу."
        else:
            self._path = path
            self._set_route("setup" if creating else "locked")
            return
        self.operationErrorChanged.emit()

    @Slot()
    def closeVault(self):
        if self.demoMode or self._busy or self._route == "vaultPicker":
            return
        self._release_session()
        self._path = None
        self._section = "all"
        self.clearOperationError()
        self._set_route("vaultPicker")

    @Property(str, constant=True)
    def appVersion(self):
        return VERSION

    @Property(bool, notify=busyChanged)
    def busy(self):
        return self._busy

    @Property(str, notify=operationErrorChanged)
    def operationError(self):
        return self._operation_error

    @Slot()
    def clearOperationError(self):
        if self._operation_error:
            self._operation_error = ""
            self.operationErrorChanged.emit()

    def _start_job(self, operation, args, completion):
        self.clearOperationError()
        self._job_number += 1
        job = VaultJob(self._job_number, operation, *args)
        job.signals.finished.connect(self._finish_job, Qt.ConnectionType.QueuedConnection)
        self._completion = completion
        self._busy = True
        self.busyChanged.emit()
        QThreadPool.globalInstance().start(job)

    @Slot(int, object, str)
    def _finish_job(self, number, result, error):
        if number != self._job_number:
            return
        callback, self._completion = self._completion, None
        self._busy = False
        self.busyChanged.emit()
        if callback is not None:
            callback(result, error)
        elif self._route == "setup" and self._path.exists():
            self._set_route("locked")

    @Slot(str, str)
    def createVault(self, password, confirmation):
        if self._route != "setup" or self._busy:
            return
        if password != confirmation:
            self._operation_error = "Мастер-пароли не совпадают."
            self.operationErrorChanged.emit()
            return
        self._start_job(vault_file.create, (self._path, password), self._finish_opening)

    def _finish_opening(self, result, error):
        if error:
            if self._route == "setup" and self._path.exists():
                self._set_route("locked")
            self._operation_error = error
            self.operationErrorChanged.emit()
            return
        self._session, self._entries, images = result
        self._folders = self._session.folders
        self._icon_data.update(images)
        self._preferences.set("vault/recentPath", str(self._path))
        self._enter_workspace()

    @Property(bool, notify=routeChanged)
    def hasSample(self):
        return self._entries is not None

    @Property(str, notify=listChanged)
    def section(self):
        return self._section

    @Property("QVariantList", notify=listChanged)
    def folders(self):
        if self._route != "workspace":
            return []
        return [
            {"id": folder_id, "name": folder.name, "accent": folder.accent}
            for folder_id, folder in sorted(self._folders.items(), key=lambda item: item[1].name.casefold())
        ]

    @Property(str, notify=listChanged)
    def currentFolder(self):
        if self._section.startswith("folder:"):
            return self._section.removeprefix("folder:")
        return ""

    @Property(str, notify=listChanged)
    def currentFolderName(self):
        folder = self._folders.get(self.currentFolder)
        return folder.name if folder else ""

    @Property(str, notify=listChanged)
    def query(self):
        return self._query

    @Property(str, notify=settingsChanged)
    def theme(self):
        return self._theme

    @Property(bool, notify=settingsChanged)
    def compactList(self):
        return self._compact

    @Property(bool, notify=settingsChanged)
    def sidebarCollapsed(self):
        return self._collapsed

    @Property(bool, notify=settingsChanged)
    def reducedMotion(self):
        return self._reduced_motion

    @Property(int, notify=settingsChanged)
    def idleMinutes(self):
        return self._idle_minutes

    def _visible(self):
        if self._route != "workspace" or self._entries is None:
            return []
        return [entry for entry in self._entries if entry.matches(self._section, self._query)]

    @Property("QVariantList", notify=listChanged)
    def rows(self):
        return [
            {"id": entry.id, "title": entry.title, "kind": entry.kind,
             "subtitle": entry.username or ", ".join(entry.tags), "favorite": entry.favorite,
             "icon": entry.icon, "accent": entry.accent}
            for entry in self._visible()
        ]

    @Property(int, notify=listChanged)
    def total(self):
        return len(self._entries or []) if self._route == "workspace" else 0

    def _find(self, entry_id):
        if self._route == "workspace":
            return next((entry for entry in self._entries or [] if entry.id == entry_id), None)
        return None

    @Property("QVariantMap", notify=detailChanged)
    def detail(self):
        entry = self._find(self._selected)
        if entry is None or self._section == "settings":
            return {}
        return {
            "id": entry.id, "title": entry.title, "kind": entry.kind,
            "username": entry.username, "url": entry.url, "notes": entry.notes,
            "tags": list(entry.tags), "favorite": entry.favorite, "hasPassword": bool(entry.password),
            "icon": entry.icon, "accent": entry.accent,
            "folder": entry.folder,
        }

    def _refresh(self):
        visible = self._visible()
        if not any(entry.id == self._selected for entry in visible):
            self._selected = visible[0].id if visible else ""
        self.listChanged.emit()
        self.detailChanged.emit()

    def _set_route(self, route):
        self._route = route
        self.routeChanged.emit()
        self._refresh()

    @Slot()
    def openSample(self):
        if self._route == "welcome":
            if self._entries is None:
                from app.core.samples import sample_entries
                self._entries = sample_entries()
                for index, entry in enumerate(self._entries):
                    icon, accent, data = self._preferences.sample_style(entry)
                    if stored_icon_is_valid(icon, data):
                        self._icon_data[icon] = data
                    elif icon and icon not in ICONS:
                        icon = entry.icon
                    self._entries[index] = replace(
                        entry, icon=icon, accent=accent if accent in ACCENT_IDS or not accent else entry.accent
                    )
            self._set_route("unlock")

    @Slot()
    def newDemo(self):
        if self._route == "welcome":
            self._entries = []
            self._folders = {}
            self.discardIconPreview()
            self._set_route("unlock")

    @Slot()
    def welcome(self):
        if not self.demoMode:
            return
        self._idle.stop()
        self.clear_clipboard()
        self.discardIconPreview()
        self._set_route("welcome")

    @Slot(str, result=bool)
    def unlock(self, code):
        if not self.demoMode:
            if self._route != "locked" or self._busy:
                return False
            self._start_job(vault_file.open_vault, (self._path, code), self._finish_opening)
            return True
        if self._route not in ("unlock", "locked") or code != self.demoCode:
            return False
        self._enter_workspace()
        return True

    def _enter_workspace(self):
        self._section = "all"
        self._query = ""
        self._set_route("workspace")
        self._restart_idle()

    @Slot()
    def lock(self):
        if self._busy and not self.demoMode:
            self._completion = None
        if self._route == "workspace":
            self._release_session()
            self._set_route("locked")

    def _release_session(self):
        self._idle.stop()
        self.clear_clipboard()
        self.discardIconPreview()
        if not self.demoMode:
            self._session = None
            self._entries = None
            self._folders = {}
            self._selected = ""
            self._query = ""
            self._icon_data.clear()

    @Slot(str)
    def setSection(self, section):
        is_folder = section.startswith("folder:") and section.removeprefix("folder:") in self._folders
        if self._route == "workspace" and (is_folder or section in ("all", "favorites", "password", "note", "settings")):
            self._section = section
            self._refresh()

    @Slot(str, str, result=str)
    def saveFolder(self, folder_id, name):
        if self._route != "workspace" or self._busy:
            return "Дождитесь завершения текущей операции."
        if folder_id and folder_id not in self._folders:
            return "Папка не найдена."
        name = name.strip()
        if not name or len(name) > vault_file.MAX_FOLDER_NAME:
            return "Введите название папки длиной до 80 символов."
        if any(key != folder_id and folder.name.casefold() == name.casefold()
               for key, folder in self._folders.items()):
            return "Папка с таким названием уже существует."
        if not folder_id and len(self._folders) >= vault_file.MAX_FOLDERS:
            return "Достигнут предел количества папок."
        new_folder = not folder_id
        folder_id = folder_id or uuid4().hex
        previous = self._folders.get(folder_id)
        folders = {**self._folders, folder_id: Folder(name, previous.accent if previous else "")}
        self._commit(self._entries, "Папка сохранена.", folders=folders,
                     section=f"folder:{folder_id}" if new_folder else None)
        return ""

    @Slot(str, str)
    def setFolderAccent(self, folder_id, accent):
        if self._route != "workspace" or folder_id not in self._folders:
            return
        if accent and accent not in ACCENT_IDS:
            return
        folder = self._folders[folder_id]
        if folder.accent != accent:
            self._commit(self._entries, "Цвет папки сохранён.",
                         folders={**self._folders, folder_id: replace(folder, accent=accent)})

    @Slot(str)
    def removeFolder(self, folder_id):
        if self._route != "workspace" or folder_id not in self._folders:
            return
        folders = {key: name for key, name in self._folders.items() if key != folder_id}
        entries = [replace(entry, folder="") if entry.folder == folder_id else entry for entry in self._entries]
        self._commit(entries, "Папка удалена. Записи сохранены.", folders=folders,
                     section="all" if self.currentFolder == folder_id else None)

    @Slot(str)
    def search(self, query):
        if self._route == "workspace" and query != self._query:
            self._query = query
            self._refresh()

    @Slot(str)
    def select(self, entry_id):
        if any(entry.id == entry_id for entry in self._visible()):
            self._selected = entry_id
            self.detailChanged.emit()

    @Slot(str, result=str)
    def reveal(self, entry_id):
        entry = self._find(entry_id)
        return entry.password if entry is not None else ""

    @Slot("QVariantMap", result=str)
    def save(self, values):
        if self._route != "workspace" or self._entries is None:
            return "Сессия заблокирована."
        if self._busy:
            return "Дождитесь завершения сохранения."
        title = values["title"].strip()
        if not title:
            return "Введите название."
        entry_id = values["id"]
        existing = self._find(entry_id)
        if entry_id and existing is None:
            return "Запись не найдена."
        kind = values["kind"]
        if kind not in ("password", "note"):
            return "Выберите тип записи."
        tags = tuple(dict.fromkeys(tag.strip() for tag in values["tags"].split(",") if tag.strip()))
        folder = values.get("folder", existing.folder if existing else self.currentFolder)
        if folder and folder not in self._folders:
            return "Выбранная папка больше не существует."
        entry = Entry(
            title=title, kind=kind,
            username=values["username"].strip() if kind == "password" else "",
            password=values["password"] if kind == "password" else "",
            url=values["url"].strip() if kind == "password" else "",
            notes=values["notes"], tags=tags,
            favorite=existing.favorite if existing else self._section == "favorites",
            icon=existing.icon if existing else "",
            accent=existing.accent if existing else "",
            folder=folder,
        )
        entries = self._entries.copy()
        if existing is None:
            entries.insert(0, entry)
        else:
            entry = replace(entry, id=existing.id)
            entries[entries.index(existing)] = entry
        self._commit(entries, "Запись сохранена.", selected=entry, editor=True)
        return ""

    def _commit(self, entries, message="", *, selected=None, editor=False, folders=None, section=None):
        if self._busy:
            self.feedback.emit("Дождитесь завершения сохранения.")
            return

        folders = self._folders if folders is None else folders

        def apply():
            self._entries = entries
            self._folders = folders
            if section is not None:
                self._section = section
                self._query = ""
            self._prune_icons()
            if selected is None:
                self._refresh()
            else:
                self._select_after_write(selected)
            if message:
                self.feedback.emit(message)

        if self.demoMode:
            apply()
            return

        def finish(state, error):
            if error:
                self.feedback.emit(error)
            else:
                self._session = state
                self._icon_data.update(images)
                apply()
            if editor:
                self.entrySaveFinished.emit(error)

        # Keep the selected image even if its picker closes before the worker finishes.
        images = self._icon_data.copy()
        self._start_job(vault_file.save, (self._path, self._session, entries, images, folders), finish)

    def _select_after_write(self, entry):
        if self._section == "settings" or not entry.matches(self._section, self._query):
            self._section = "all"
            self._query = ""
        self._selected = entry.id
        self._refresh()

    @Slot(str)
    def duplicate(self, entry_id):
        entry = self._find(entry_id)
        if entry is not None:
            duplicate = replace(entry, id=uuid4().hex, title=entry.title[:232] + " (копия)")
            entries = self._entries.copy()
            entries.insert(entries.index(entry) + 1, duplicate)
            self._commit(entries, "Создана копия записи.", selected=duplicate)

    @Slot(QUrl, result="QVariantMap")
    def importIconPreview(self, url):
        if self._route != "workspace":
            return {"error": "Сессия заблокирована."}
        try:
            icon, data = import_icon(url)
        except ValueError as error:
            return {"error": str(error)}
        self.discardIconPreview()
        self._icon_data[icon] = data
        self._pending_icon = icon
        return {"icon": icon}

    @Slot()
    def discardIconPreview(self):
        self._pending_icon = ""
        self._prune_icons()

    def _prune_icons(self):
        used = {entry.icon for entry in self._entries or ()}
        used.add(self._pending_icon)
        for icon in self._icon_data.keys() - used:
            del self._icon_data[icon]

    def _set_style(self, entry, **fields):
        updated = replace(entry, **fields)
        entries = self._entries.copy()
        entries[entries.index(entry)] = updated
        if self.demoMode and updated.id.startswith("sample-"):
            self._preferences.set_sample_style(
                updated.id, updated.icon, updated.accent, self._icon_data.get(updated.icon, b"")
            )
        self._commit(entries)

    @Slot(str, str)
    def setEntryIcon(self, entry_id, icon):
        entry = self._find(entry_id)
        if entry is not None and (not icon or icon in ICONS or icon in self._icon_data):
            self._set_style(entry, icon=icon)

    @Slot(str, str)
    def setEntryAccent(self, entry_id, accent):
        entry = self._find(entry_id)
        if entry is not None and (not accent or accent in ACCENT_IDS):
            self._set_style(entry, accent=accent)

    @Slot(str)
    def toggleFavorite(self, entry_id):
        entry = self._find(entry_id)
        if entry is not None:
            self._set_style(entry, favorite=not entry.favorite)

    @Slot(str)
    def remove(self, entry_id):
        entry = self._find(entry_id)
        if entry is not None:
            self._commit([item for item in self._entries if item.id != entry_id], "Запись удалена.")

    @Slot(str)
    def setTheme(self, theme):
        theme = THEME_ALIASES.get(theme, theme)
        if theme in THEMES and theme != self._theme:
            self._theme = theme
            self._preferences.set("ui/theme", theme)
            self.settingsChanged.emit()

    @Slot(bool)
    def setCompactList(self, compact):
        self._compact = compact
        self._preferences.set("ui/compact", compact)
        self.settingsChanged.emit()

    @Slot(bool)
    def setSidebarCollapsed(self, collapsed):
        self._collapsed = collapsed
        self._preferences.set("ui/collapsed", collapsed)
        self.settingsChanged.emit()

    @Slot(bool)
    def setReducedMotion(self, reduced):
        self._reduced_motion = reduced
        self._preferences.set("ui/reducedMotion", reduced)
        self.settingsChanged.emit()

    @Slot(int)
    def setIdleMinutes(self, minutes):
        if minutes in (0, 1, 5, 10, 15):
            self._idle_minutes = minutes
            self._preferences.set("security/idleMinutes", minutes)
            self._idle.stop()
            if self._route == "workspace":
                self._restart_idle()
            self.settingsChanged.emit()

    @Slot(int, bool, bool, bool, bool, result=str)
    def generate(self, length, lower, upper, digits, symbols):
        if self._route == "workspace" and any((lower, upper, digits, symbols)):
            return generate_password(length, lower, upper, digits, symbols) if 8 <= length <= 128 else ""
        return ""

    @Slot(str, str)
    def copyField(self, entry_id, field):
        entry = self._find(entry_id)
        if entry is not None and field in ("username", "password", "url", "notes"):
            self._copy(getattr(entry, field), transient=field in ("password", "notes"))

    @Slot(str)
    def copyGenerated(self, text):
        if self._route == "workspace":
            self._copy(text, transient=True)

    def _copy(self, text, *, transient):
        if not text:
            return
        self._clipboard_timer.stop()
        self._copied = None
        clipboard = QGuiApplication.clipboard()
        if transient:
            marker = secrets.token_bytes(16)
            mime = QMimeData()
            mime.setText(text)
            mime.setData(CLIPBOARD_MARKER, marker)
            if QGuiApplication.platformName() == "windows":
                mime.setData(WINDOWS_CLIPBOARD_EXCLUSION, b"\x01")
            clipboard.setMimeData(mime)
            self._copied = text, marker
            self._clipboard_timer.start()
            self.feedback.emit("Скопировано. Буфер очистится через 20 секунд.")
        else:
            clipboard.setText(text)
            self.feedback.emit("Скопировано.")

    @Slot()
    def clear_clipboard(self):
        self._clipboard_timer.stop()
        copied, self._copied = self._copied, None
        if copied is None:
            return
        clipboard = QGuiApplication.clipboard()
        mime = clipboard.mimeData()
        text, marker = copied
        if mime is not None and mime.text() == text and mime.data(CLIPBOARD_MARKER) == marker:
            clipboard.clear()
