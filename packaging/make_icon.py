"""Render the original Umbra mark as a multi-resolution Windows icon."""

import struct
from pathlib import Path

from PySide6.QtCore import QBuffer, QIODevice, Qt
from PySide6.QtGui import QImage

ASSETS = Path(__file__).resolve().parents[1] / "app" / "ui" / "assets"
SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def main():
    logo = QImage(str(ASSETS / "umbra.png"))
    if logo.isNull() or logo.width() != logo.height():
        raise SystemExit("Expected a square Umbra PNG.")
    offset = 6 + len(SIZES) * 16
    directory = bytearray(struct.pack("<HHH", 0, 1, len(SIZES)))
    images = []
    for size in SIZES:
        image = logo.scaled(size, size, Qt.AspectRatioMode.KeepAspectRatio,
                            Qt.TransformationMode.SmoothTransformation)
        buffer = QBuffer()
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        if not image.save(buffer, "PNG"):
            raise SystemExit("Cannot encode icon.")
        data = bytes(buffer.data())
        directory.extend(struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32,
                                     len(data), offset))
        images.append(data)
        offset += len(data)
    (ASSETS / "umbra.ico").write_bytes(directory + b"".join(images))


if __name__ == "__main__":
    main()
