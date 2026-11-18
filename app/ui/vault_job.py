"""Worker thread bridge for password derivation and disk transactions."""

from PySide6.QtCore import QObject, QRunnable, Signal

from app.security.envelope import VaultError


class JobResult(QObject):
    finished = Signal(int, object, str)


class VaultJob(QRunnable):
    def __init__(self, generation, operation, *args):
        super().__init__()
        self.signals = JobResult()
        self.generation = generation
        self.operation = operation
        self.args = args

    def run(self):
        try:
            result = self.operation(*self.args)
        except VaultError as error:
            self.signals.finished.emit(self.generation, None, str(error))
        except Exception:
            self.signals.finished.emit(self.generation, None, "Операция с хранилищем не завершена.")
        else:
            self.signals.finished.emit(self.generation, result, "")
        finally:
            self.args = ()
