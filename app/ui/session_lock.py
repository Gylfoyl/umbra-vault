"""Subscribe to Windows session notifications for the main window."""

import ctypes
from ctypes import wintypes

from PySide6.QtCore import QAbstractNativeEventFilter

WM_WTSSESSION_CHANGE = 0x02B1
LOCK_EVENTS = {2, 4, 6, 7}  # Console disconnect, remote disconnect, logoff, lock.


class WindowsSessionLock(QAbstractNativeEventFilter):
    def __init__(self, application, window, lock):
        super().__init__()
        self.application = application
        self.hwnd = int(window.winId())
        self.lock = lock
        wts = ctypes.WinDLL("wtsapi32")
        register = wts.WTSRegisterSessionNotification
        register.argtypes = (wintypes.HWND, wintypes.DWORD)
        register.restype = wintypes.BOOL
        self._unregister = wts.WTSUnRegisterSessionNotification
        self._unregister.argtypes = (wintypes.HWND,)
        self._unregister.restype = wintypes.BOOL
        self.registered = bool(register(self.hwnd, 0))
        if self.registered:
            application.installNativeEventFilter(self)
            application.aboutToQuit.connect(self.close)

    def nativeEventFilter(self, event_type, message):
        if event_type == b"windows_generic_MSG":
            msg = wintypes.MSG.from_address(int(message))
            if msg.message == WM_WTSSESSION_CHANGE and msg.wParam in LOCK_EVENTS:
                self.lock()
        return False, 0

    def close(self):
        if self.registered:
            self.application.removeNativeEventFilter(self)
            self._unregister(self.hwnd)
            self.registered = False
