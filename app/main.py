"""Start the Umbra Vault Qt Quick application."""

import sys
from pathlib import Path

from PySide6.QtCore import QStandardPaths, QUrl
from PySide6.QtGui import QFont, QFontDatabase, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

from app.metadata import NAME, VERSION
from app.ui.controller import DemoController


def user_vault_path():
    directory = QStandardPaths.writableLocation(QStandardPaths.StandardLocation.GenericDataLocation)
    return Path(directory) / NAME / "Data" / "vault.umbra"


def load_window(preferences=None, *, path=None, demo=False):
    """Load the installed QML resources and return their owning engine."""
    engine = QQmlApplicationEngine()
    controller = DemoController(engine, preferences=preferences, demo=demo,
                                path=None if demo else path, default_path=user_vault_path())
    engine.addImageProvider("entryicons", controller.icon_provider())
    engine.setInitialProperties({"vault": controller})
    source = Path(__file__).parent / "ui" / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(source)))
    application = QGuiApplication.instance()
    if engine.rootObjects() and application.platformName() == "windows":
        from app.ui.session_lock import WindowsSessionLock
        engine.session_lock = WindowsSessionLock(application, engine.rootObjects()[0], controller.lock)
    return engine


def configure_application():
    QGuiApplication.setApplicationName(NAME)
    QGuiApplication.setApplicationVersion(VERSION)
    QGuiApplication.setWindowIcon(QIcon(str(Path(__file__).parent / "ui" / "assets" / "umbra.ico")))
    QQuickStyle.setStyle("Basic")
    font = QFont()
    candidates = ("Segoe UI Variable", "Segoe UI")
    available = set(QFontDatabase.families())
    font.setFamilies([name for name in candidates if name in available] + [font.family()])
    font.setPixelSize(14)
    QGuiApplication.setFont(font)


def main():
    if sys.platform == "win32":
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("Umbra.UmbraVault")
    application = QGuiApplication(sys.argv)
    configure_application()
    engine = load_window(demo=not getattr(sys, "frozen", False) and "--demo" in sys.argv[1:])
    if not engine.rootObjects():
        return 1
    return application.exec()


if __name__ == "__main__":
    sys.exit(main())
