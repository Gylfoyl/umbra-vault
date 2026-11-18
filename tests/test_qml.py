"""Load the application's real QML in the offscreen Qt platform."""

import os
import time
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QPointF, QSettings, Qt, QUrl
from PySide6.QtGui import QColor, QGuiApplication, QImage
from PySide6.QtTest import QSignalSpy, QTest

from app.main import configure_application, load_window
from app.storage.preferences import Preferences
from app.ui.controller import CLIPBOARD_MARKER, DemoController
from app.ui.icons import import_icon


class QmlSmokeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        configure_application()

    def setUp(self):
        directory = TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.preferences_path = self.directory / "preferences.ini"
        self.preferences = self.read_preferences()
        self.engine = load_window(self.preferences, demo=True)
        self.assertEqual(len(self.engine.rootObjects()), 1)
        self.window = self.engine.rootObjects()[0]
        self.vault = self.engine.findChild(DemoController)
        self.warnings = []
        self.engine.warnings.connect(
            lambda errors: self.warnings.extend(error.toString() for error in errors)
        )
        QTest.qWaitForWindowExposed(self.window)

    def read_preferences(self):
        return Preferences(QSettings(str(self.preferences_path), QSettings.Format.IniFormat))

    def tearDown(self):
        self.vault.clear_clipboard()
        self.window.close()
        self.assertEqual(self.warnings, [])

    def find(self, name, parent=None):
        item = (parent or self.window).findChild(QObject, name)
        self.assertIsNotNone(item, name)
        return item

    def click(self, name, parent=None):
        self.assertTrue(QMetaObject.invokeMethod(self.find(name, parent), "clicked"))
        self.app.processEvents()

    def wait_for(self, condition):
        deadline = time.monotonic() + 5
        while not condition() and time.monotonic() < deadline:
            self.app.processEvents()
            time.sleep(0.01)
        self.assertTrue(condition(), self.vault.operationError)

    def test_sample_unlock_search_settings_and_lock(self):
        self.assertEqual(self.window.title(), "Umbra Vault")
        self.click("openSample")
        self.assertEqual(self.vault.route, "unlock")
        self.find("demoCode").setProperty("text", "wrong")
        self.click("unlock")
        self.assertEqual(self.vault.route, "unlock")
        self.find("demoCode").setProperty("text", self.vault.demoCode)
        self.click("unlock")
        self.assertEqual(self.find("entries").property("count"), 6)
        QTest.keyClick(self.window, Qt.Key.Key_F, Qt.KeyboardModifier.ControlModifier)
        self.assertEqual(self.window.activeFocusItem().property("placeholderText"), "Поиск записей")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertNotEqual(self.window.activeFocusItem().property("placeholderText"), "Поиск записей")
        self.vault.setSection("favorites")
        self.assertEqual(self.find("entries").property("count"), 2)
        self.vault.search("github")
        self.assertEqual(self.vault.detail["title"], "GitHub")
        self.assertNotIn("password", self.vault.detail)
        self.vault.search("missing")
        self.assertFalse(self.find("detailsLoader").property("active"))
        self.vault.setSection("settings")
        self.assertTrue(self.find("settingsLoader").property("active"))
        self.vault.setTheme("light")
        self.assertEqual(self.find("themePicker").property("currentIndex"), 2)
        QTest.keyClick(self.window, Qt.Key.Key_L, Qt.KeyboardModifier.ControlModifier)
        self.assertEqual(self.vault.route, "locked")
        self.assertFalse(self.find("workspaceLoader").property("active"))
        self.assertEqual(self.vault.detail, {})

    def test_new_session_editor_generator_and_delete(self):
        self.click("newDemo")
        self.find("demoCode").setProperty("text", self.vault.demoCode)
        self.click("unlock")
        self.assertEqual(self.find("entries").property("count"), 0)
        QTest.keyClick(self.window, Qt.Key.Key_N, Qt.KeyboardModifier.ControlModifier)
        self.assertTrue(self.find("editorLoader").property("active"))
        editor = self.find("editorLoader").property("item")
        self.assertTrue(editor.property("visible"))
        self.click("saveEntry")
        self.assertTrue(editor.property("visible"))
        self.find("entryTitle").setProperty("text", "Test entry")
        self.assertTrue(QMetaObject.invokeMethod(editor, "requestGenerator"))
        self.app.processEvents()
        self.assertTrue(self.find("generatorLoader").property("item").property("visible"))
        password = self.find("generatedPassword").property("text")
        self.assertEqual(len(password), 20)
        self.click("applyPassword")
        self.assertEqual(self.find("entryPassword").property("text"), password)
        self.click("saveEntry")
        self.assertEqual(self.vault.detail["title"], "Test entry")
        entry_id = self.vault.detail["id"]
        self.assertEqual(self.vault.reveal(entry_id), password)
        self.vault.toggleFavorite(entry_id)
        self.assertTrue(self.vault.detail["favorite"])
        details = self.find("detailsLoader").property("item")
        self.assertTrue(QMetaObject.invokeMethod(details, "edit"))
        editor = self.find("editorLoader").property("item")
        self.find("entryTitle", editor).setProperty("text", "Renamed")
        self.click("saveEntry", editor)
        self.assertEqual(self.vault.detail["id"], entry_id)
        self.assertEqual(self.vault.detail["title"], "Renamed")
        self.assertTrue(self.vault.detail["favorite"])
        self.assertEqual(self.vault.reveal(entry_id), password)
        self.vault.remove(entry_id)
        self.assertEqual(self.find("entries").property("count"), 0)

    def test_clipboard_cleanup_preserves_later_copy(self):
        self.vault.openSample()
        self.assertTrue(self.vault.unlock(self.vault.demoCode))
        entry_id = self.vault.detail["id"]
        clipboard = self.app.clipboard()
        self.vault.copyField(entry_id, "password")
        self.assertTrue(clipboard.mimeData().hasFormat(CLIPBOARD_MARKER))
        self.assertEqual(self.vault._clipboard_timer.interval(), 20_000)
        expired = QSignalSpy(self.vault._clipboard_timer.timeout)
        self.vault._clipboard_timer.start(1)
        self.assertTrue(expired.wait(1000))
        self.assertEqual(clipboard.text(), "")
        self.vault.copyField(entry_id, "password")
        duplicated_text = clipboard.text()
        clipboard.setText(duplicated_text)
        self.vault.clear_clipboard()
        self.assertEqual(clipboard.text(), duplicated_text)
        clipboard.clear()

    def test_idle_timer_locks_and_session_reopens(self):
        self.vault.openSample()
        self.assertTrue(self.vault.unlock(self.vault.demoCode))
        self.vault.setIdleMinutes(1)
        self.assertEqual(self.vault._idle.interval(), 60_000)
        self.vault.setIdleMinutes(0)
        self.assertFalse(self.vault._idle.isActive())
        self.vault.setIdleMinutes(1)
        self.vault._idle.start(1)
        QTest.qWait(30)
        self.assertEqual(self.vault.route, "locked")
        self.assertEqual(self.vault.rows, [])
        self.assertTrue(self.vault.unlock(self.vault.demoCode))
        self.assertEqual(len(self.vault.rows), 6)

    def test_menu_selects_row_and_opens_both_pickers(self):
        self.vault.openSample()
        self.assertTrue(self.vault.unlock(self.vault.demoCode))
        entries = self.find("entries")
        self.app.processEvents()
        point = entries.mapToScene(QPointF(30, 78)).toPoint()
        QTest.mouseClick(self.window, Qt.MouseButton.RightButton, Qt.KeyboardModifier.NoModifier, point)
        menu = self.find("entryMenu")
        self.assertTrue(menu.property("visible"))
        self.assertEqual(self.vault.detail["id"], "sample-github")
        self.assertGreaterEqual(menu.property("x"), 0)
        self.assertLessEqual(menu.property("y") + menu.property("height"), self.window.height())
        entry_id = self.vault.detail["id"]
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        QTest.keyClick(self.window, Qt.Key.Key_F10, Qt.KeyboardModifier.ShiftModifier)
        self.assertTrue(menu.property("visible"))
        for action in ("icon", "color"):
            self.assertTrue(QMetaObject.invokeMethod(menu, "close"))
            self.assertTrue(QMetaObject.invokeMethod(
                menu, "chosen", Q_ARG("QString", action), Q_ARG("QString", entry_id),
            ))
            self.app.processEvents()
            loader = self.find("appearancePicker")
            picker = loader.property("item")
            self.assertTrue(picker.property("visible"))
            if action == "icon":
                self.find("iconSearch", picker).setProperty("text", "Почта")
                self.assertEqual(self.find("iconGrid", picker).property("count"), 1)
                picker.setProperty("chosen", "mail")
                self.click("applyIcon", picker)
                self.assertEqual(self.vault.detail["icon"], "mail")
            else:
                picker.setProperty("chosen", "sky")
                self.click("applyColor", picker)
                self.assertEqual(self.vault.detail["accent"], "sky")
            self.assertFalse(loader.property("active"))

        self.assertTrue(QMetaObject.invokeMethod(
            menu, "chosen", Q_ARG("QString", "delete"), Q_ARG("QString", entry_id),
        ))
        self.app.processEvents()
        self.assertTrue(self.find("deleteDialog").property("visible"))
        self.assertEqual(self.vault.total, 6)
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertFalse(self.find("deleteDialog").property("visible"))
        self.assertEqual(self.vault.total, 6)

    def test_themes_density_sidebar_and_appearance_persist(self):
        self.vault.openSample()
        self.assertTrue(self.vault.unlock(self.vault.demoCode))
        palettes = {
            "umbra": "#151419", "midnight": "#111820", "snow": "#f5f4f8",
            "forest": "#111c18", "graphite": "#191a1c",
        }
        for name, color in palettes.items():
            self.vault.setTheme(name)
            self.assertEqual(self.window.color().name(), color)
        self.click("toggleSidebar")
        self.vault.setCompactList(True)
        self.assertTrue(self.vault.sidebarCollapsed)
        QTest.keyClick(self.window, Qt.Key.Key_K, Qt.KeyboardModifier.ControlModifier)
        self.assertEqual(self.window.activeFocusItem().property("placeholderText"), "Поиск записей")

        source = self.directory / "local.svg"
        source.write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                          '<circle cx="12" cy="12" r="10" fill="#ff5500"/></svg>', encoding="utf-8")
        icon = self.vault.importIconPreview(QUrl.fromLocalFile(str(source)))["icon"]
        entry_id = self.vault.detail["id"]
        self.vault.setEntryIcon(entry_id, icon)
        self.vault.setEntryAccent(entry_id, "red")
        self.vault.discardIconPreview()
        self.vault.duplicate(entry_id)
        self.assertNotEqual(self.vault.detail["id"], entry_id)
        self.assertEqual(self.vault.detail["icon"], icon)
        self.assertEqual(self.vault.detail["accent"], "red")
        self.preferences.settings.sync()
        settings = self.read_preferences()
        second = DemoController(preferences=settings)
        second.openSample()
        self.assertTrue(second.unlock(second.demoCode))
        self.assertEqual(second.theme, "graphite")
        self.assertTrue(second.compactList)
        self.assertTrue(second.sidebarCollapsed)
        self.assertEqual(second.detail["id"], entry_id)
        self.assertEqual(second.detail["icon"], icon)
        self.assertEqual(second.detail["accent"], "red")
        self.assertEqual(second.total, 6)
        self.assertNotIn("Sample-Linear", self.preferences_path.read_text(encoding="utf-8"))

    def test_density_keeps_text_and_badge_within_the_row(self):
        self.vault.openSample()
        self.assertTrue(self.vault.unlock(self.vault.demoCode))
        heights = []
        for index in (0, 1, 0):
            self.vault.setSection("settings")
            self.app.processEvents()
            settings = self.find("settingsLoader").property("item")
            picker = self.find("densityPicker", settings)
            self.assertTrue(QMetaObject.invokeMethod(picker, "activated", Q_ARG(int, index)))
            self.vault.setSection("all")
            self.app.processEvents()
            record = self.find("entries").property("currentItem")
            content = record.property("contentItem")
            badge, text_column, _ = content.childItems()
            for item in (badge, *text_column.childItems()):
                top = item.mapToItem(record, QPointF()).y()
                self.assertGreaterEqual(top, record.property("topPadding"))
                self.assertLessEqual(top + item.height(), record.height() - record.property("bottomPadding"))
            heights.append(record.height())
        self.assertLess(heights[1], heights[0])
        self.assertEqual(heights[0], heights[2])

    def test_dark_theme_replaces_the_legacy_system_choice(self):
        self.assertEqual(self.vault.theme, "umbra")
        self.preferences.set("ui/theme", "system")
        previous_installation = DemoController(preferences=self.read_preferences())
        self.assertEqual(previous_installation.theme, "umbra")
        self.vault.openSample()
        self.assertTrue(self.vault.unlock(self.vault.demoCode))
        self.vault.setSection("settings")
        theme_picker = self.find("themePicker")
        self.assertEqual(theme_picker.property("displayText"), "Тёмная тема")
        self.assertEqual(theme_picker.property("count"), 5)

    def test_real_vault_create_edit_lock_reopen_and_delete(self):
        path = self.directory / "profile" / "vault.umbra"
        password = "я"
        self.window.close()
        self.engine = load_window(self.preferences, path=path)
        self.window, = self.engine.rootObjects()
        self.vault = self.engine.findChild(DemoController)
        self.engine.warnings.connect(
            lambda errors: self.warnings.extend(error.toString() for error in errors)
        )
        self.assertTrue(QTest.qWaitForWindowExposed(self.window))
        self.assertEqual(self.vault.route, "setup")
        self.find("demoCode").setProperty("text", password)
        self.find("masterConfirmation").setProperty("text", "bad confirmation")
        self.click("unlock")
        self.assertIn("не совпадают", self.vault.operationError)
        self.assertFalse(path.exists())
        self.find("masterConfirmation").setProperty("text", password)
        self.click("unlock")
        self.wait_for(lambda: not self.vault.busy)
        self.assertEqual(self.vault.route, "workspace")

        self.click("newFolderButton")
        folder_dialog = self.find("folderDialog")
        self.find("folderName", folder_dialog).setProperty("text", "Работа")
        self.click("saveFolder", folder_dialog)
        self.wait_for(lambda: not self.vault.busy)
        folder_id = self.vault.currentFolder
        self.assertTrue(folder_id)
        self.assertEqual(self.vault.currentFolderName, "Работа")
        self.assertEqual(self.find("folderList").property("count"), 1)
        def folder_action(action):
            folders = self.find("folderList")
            point = folders.mapToScene(QPointF(24, 15)).toPoint()
            QTest.mouseClick(self.window, Qt.MouseButton.RightButton, Qt.KeyboardModifier.NoModifier, point)
            folder_menu = self.find("folderMenu")
            self.assertTrue(folder_menu.property("visible"))
            button = self.find(action, folder_menu)
            point = button.mapToScene(QPointF(30, 15)).toPoint()
            QTest.mouseClick(self.window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, point)
            self.app.processEvents()

        folder_action("colorFolderAction")
        color_picker = self.find("appearancePicker").property("item")
        self.assertTrue(color_picker.property("folderMode"))
        color_picker.setProperty("chosen", "teal")
        self.click("applyColor", color_picker)
        self.wait_for(lambda: not self.vault.busy)
        self.assertEqual(self.vault.folders[0]["accent"], "teal")
        folder_action("renameFolderAction")
        self.assertTrue(folder_dialog.property("visible"))
        self.find("folderName", folder_dialog).setProperty("text", "Проекты")
        self.click("saveFolder", folder_dialog)
        self.wait_for(lambda: not self.vault.busy)
        self.assertEqual(self.vault.currentFolderName, "Проекты")

        def save_entry(title):
            editor = self.find("editorLoader").property("item")
            self.find("entryTitle", editor).setProperty("text", title)
            self.find("entryPassword", editor).setProperty("text", "Test fixture value")
            saved = QSignalSpy(self.vault.entrySaveFinished)
            self.click("saveEntry", editor)
            self.wait_for(lambda: saved.count() > 0)
            self.assertEqual(saved.at(0), [""])
            self.assertEqual(self.vault.detail["title"], title)

        self.click("newEntryButton")
        save_entry("Новая запись")
        self.assertEqual(self.vault.detail["folder"], folder_id)
        entry_id = self.vault.detail["id"]
        self.assertTrue(QMetaObject.invokeMethod(self.find("detailsLoader").property("item"), "edit"))
        save_entry("Переименована")
        self.vault.lock()
        self.assertEqual(self.vault.route, "locked")
        self.assertIsNone(self.vault._session)
        self.assertEqual(self.vault.rows, [])

        reopened = DemoController(preferences=self.read_preferences(), path=path)
        self.assertTrue(reopened.unlock("wrong password"))
        self.wait_for(lambda: not reopened.busy)
        self.assertIn("неверен", reopened.operationError)
        self.assertEqual(reopened.route, "locked")
        self.assertTrue(reopened.unlock(password))
        self.wait_for(lambda: not reopened.busy)
        self.assertEqual(reopened.detail["id"], entry_id)
        self.assertEqual(reopened.detail["title"], "Переименована")
        self.assertEqual(reopened.reveal(entry_id), "Test fixture value")
        self.assertEqual(reopened.folders, [{"id": folder_id, "name": "Проекты", "accent": "teal"}])
        reopened.setSection(f"folder:{folder_id}")
        self.assertEqual(reopened.rows[0]["id"], entry_id)
        self.assertEqual(reopened.saveFolder(folder_id, "Личное"), "")
        self.wait_for(lambda: not reopened.busy)
        self.assertEqual(reopened.currentFolderName, "Личное")
        self.assertEqual(reopened.folders[0]["accent"], "teal")
        reopened.removeFolder(folder_id)
        self.wait_for(lambda: not reopened.busy)
        self.assertEqual(reopened.section, "all")
        self.assertEqual(reopened.detail["folder"], "")
        self.assertEqual(reopened.total, 1)
        reopened.remove(entry_id)
        self.wait_for(lambda: not reopened.busy)
        self.assertEqual(reopened.total, 0)
        self.assertNotIn(b"Test fixture value", path.read_bytes())
        reopened.lock()

    def test_switch_between_files_and_never_overwrite_existing_vault(self):
        self.window.close()
        self.engine = load_window(self.preferences)
        self.window, = self.engine.rootObjects()
        self.vault = self.engine.findChild(DemoController)
        self.engine.warnings.connect(
            lambda errors: self.warnings.extend(error.toString() for error in errors)
        )
        self.assertTrue(QTest.qWaitForWindowExposed(self.window))
        self.assertEqual(self.vault.route, "vaultPicker")
        self.assertTrue(self.find("selectNewVault").property("visible"))

        def choose(file, new):
            self.vault.chooseVault(QUrl.fromLocalFile(str(file)), new)
            self.app.processEvents()

        def submit(password):
            self.find("demoCode").setProperty("text", password)
            if self.vault.route == "setup":
                self.find("masterConfirmation").setProperty("text", password)
            self.click("unlock")
            self.wait_for(lambda: not self.vault.busy)

        first = self.directory / "One.umbra"
        second = self.directory / "Two.umbra"
        choose(first, True)
        self.assertEqual(self.vault.route, "setup")
        submit("1")
        self.assertEqual(self.vault.route, "workspace")
        self.assertEqual(self.vault.saveFolder("", "Из первой базы"), "")
        self.vault.closeVault()
        self.assertEqual(self.vault.route, "workspace")
        self.wait_for(lambda: not self.vault.busy)
        workspace = self.find("workspaceLoader").property("item")
        self.click("closeVaultButton", workspace)
        self.assertIsNone(self.vault._session)
        self.assertEqual(self.vault.route, "vaultPicker")
        original = first.read_bytes()
        choose(first, True)
        self.assertIn("уже существует", self.vault.operationError)
        self.assertEqual(first.read_bytes(), original)

        choose(second, True)
        submit("2")
        self.assertEqual(self.vault.route, "workspace")
        self.assertEqual(self.vault.folders, [])
        workspace = self.find("workspaceLoader").property("item")
        self.click("closeVaultButton", workspace)
        self.assertEqual(self.vault.route, "vaultPicker")
        self.assertEqual(self.vault.recentVaultName, "Two.umbra")
        choose(first, False)
        submit("2")
        self.assertEqual(self.vault.route, "locked")
        self.assertIn("неверен", self.vault.operationError)
        submit("1")
        self.assertEqual(self.vault.route, "workspace")
        self.assertEqual(self.vault.folders[0]["name"], "Из первой базы")
        self.assertEqual(first.read_bytes(), original)

    def test_icon_import_rejects_external_content_and_oversized_images(self):
        def source(name, data):
            path = self.directory / name
            path.write_bytes(data)
            return QUrl.fromLocalFile(str(path))

        for filename, data in (
            ("external.svg", b'<svg><image href="https://example.test/image.png"/></svg>'),
            ("entity.svg", b'<!DOCTYPE svg [<!ENTITY x SYSTEM "file:///abc">]><svg>&x;</svg>'),
            ("css.svg", b'<svg><rect width="20" height="20" style="fill:url(file:///abc)"/></svg>'),
            ("animate.svg", b'<svg><rect width="20" height="20"><animate/></rect></svg>'),
            ("oversized.svg", b"x" * (512 * 1024 + 1)),
            ("not-a-png.png", b"<svg/>"),
        ):
            with self.subTest(filename=filename), self.assertRaises(ValueError):
                import_icon(source(filename, data))

        image = QImage(1025, 10, QImage.Format.Format_RGB32)
        image.fill(QColor("#ff5500"))
        original = self.directory / "local.png"
        self.assertTrue(image.save(str(original)))
        with self.assertRaises(ValueError):
            import_icon(QUrl.fromLocalFile(str(original)))

        image = QImage(512, 256, QImage.Format.Format_RGB32)
        image.fill(QColor("#ff5500"))
        image.setText("Comment", "metadata to remove")
        self.assertTrue(image.save(str(original)))
        _, png = import_icon(QUrl.fromLocalFile(str(original)))
        normalized = QImage.fromData(png, "PNG")
        self.assertEqual((normalized.width(), normalized.height()), (128, 64))
        self.assertEqual(normalized.textKeys(), [])
