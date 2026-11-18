"""Validate and rasterize local icons before they reach QML."""

import hashlib
import re
import stat
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

from PySide6.QtCore import QByteArray, QBuffer, QIODevice, QRectF, Qt
from PySide6.QtGui import QImage, QImageReader, QPainter
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtSvg import QSvgRenderer, QtSvg

from app.ui.icon_catalog import ICONS, svg_for

MAX_BYTES = 512 * 1024
ICON_SIZE = 128
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
PNG_CHUNKS = {b"IHDR", b"PLTE", b"IDAT", b"IEND", b"tRNS"}
SVG_NS = "http://www.w3.org/2000/svg"
SVG_TAGS = {"svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon"}
SVG_GEOMETRY = {
    "viewBox", "width", "height", "d", "points", "x", "y", "cx", "cy", "r", "rx", "ry",
    "x1", "x2", "y1", "y2", "transform", "opacity", "fill-opacity", "stroke-opacity",
    "stroke-width", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset",
}
SVG_ENUMS = {
    "stroke-linecap": {"butt", "round", "square"},
    "stroke-linejoin": {"miter", "round", "bevel"},
    "fill-rule": {"nonzero", "evenodd"},
}
SVG_COLOR = re.compile(r"(?:#[0-9a-fA-F]{3,8}|[a-zA-Z]{1,24}|rgba?\([0-9.,% +\-]+\))\Z")
SVG_GEOMETRY_VALUE = re.compile(r"[a-zA-Z0-9.,%+\-()\s]{1,32768}\Z")
SVG_NUMBER = re.compile(r"[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?")
CUSTOM_ID = re.compile(r"custom-[0-9a-f]{64}\Z")


def _local_bytes(url):
    if not url.isLocalFile() or url.host():
        raise ValueError("Выберите локальный PNG или SVG.")
    path = Path(url.toLocalFile())
    extension = path.suffix.lower()
    if extension not in (".png", ".svg") or not path.is_absolute() or path.as_posix().startswith("//"):
        raise ValueError("Поддерживаются только PNG и SVG.")
    try:
        if not stat.S_ISREG(path.stat().st_mode) or path.is_symlink():
            raise ValueError("Выберите обычный локальный файл.")
        with path.open("rb") as source:
            data = source.read(MAX_BYTES + 1)
    except OSError:
        raise ValueError("Не удалось прочитать файл.") from None
    if not data or len(data) > MAX_BYTES:
        raise ValueError("Размер файла должен быть от 1 байта до 512 КиБ.")
    return extension, data


def _png(data, max_side):
    if not data.startswith(PNG_SIGNATURE) or not 33 <= len(data) <= MAX_BYTES:
        return QImage()
    length, tag, width, height = struct.unpack_from(">I4sII", data, len(PNG_SIGNATURE))
    if tag != b"IHDR" or length != 13 or not 1 <= min(width, height) <= max(width, height) <= max_side:
        return QImage()

    # Drop metadata chunks before decoding, including compressed text and color profiles.
    offset = len(PNG_SIGNATURE)
    chunks = [PNG_SIGNATURE]
    while offset + 12 <= len(data):
        length, tag = struct.unpack_from(">I4s", data, offset)
        end = offset + length + 12
        if end > len(data):
            return QImage()
        if tag in PNG_CHUNKS:
            chunks.append(data[offset:end])
        elif tag[0] & 32 == 0:
            return QImage()
        offset = end
        if tag == b"IEND":
            break
    else:
        return QImage()

    buffer = QBuffer()
    buffer.setData(b"".join(chunks))
    buffer.open(QIODevice.OpenModeFlag.ReadOnly)
    reader = QImageReader(buffer, QByteArray(b"png"))
    size = reader.size()
    if not size.isValid() or min(size.width(), size.height()) < 1 or max(size.width(), size.height()) > max_side:
        return QImage()
    return reader.read()


def _validated_svg(data):
    message = "SVG должен содержать только простые статические фигуры без внешних ресурсов."
    try:
        source = data.decode("utf-8-sig")
        source = re.sub(r"^\s*<\?xml\s+[^<>?]*\?>", "", source, count=1)
        if "<!" in source or "<?" in source:
            raise ValueError(message)
        root = ET.fromstring(source)
    except (UnicodeError, ET.ParseError):
        raise ValueError("Не удалось прочитать SVG в UTF-8.") from None
    if root.tag not in ("svg", f"{{{SVG_NS}}}svg"):
        raise ValueError(message)

    stack = [(root, 0)]
    count = 0
    while stack:
        element, depth = stack.pop()
        count += 1
        if count > 256 or depth > 16:
            raise ValueError("SVG слишком сложный.")
        tag = element.tag.removeprefix(f"{{{SVG_NS}}}")
        if tag not in SVG_TAGS or (tag == "svg" and depth != 0):
            raise ValueError(message)
        for name, value in element.attrib.items():
            if name in SVG_GEOMETRY and SVG_GEOMETRY_VALUE.fullmatch(value):
                if all(abs(float(number)) <= 100_000 for number in SVG_NUMBER.findall(value)):
                    continue
            elif name in SVG_ENUMS and value in SVG_ENUMS[name]:
                continue
            elif name in ("fill", "stroke", "color") and SVG_COLOR.fullmatch(value):
                continue
            raise ValueError(message)
        if (element.text or "").strip() or (element.tail or "").strip():
            raise ValueError(message)
        stack.extend((child, depth + 1) for child in element)
    return ET.tostring(root, encoding="utf-8")


def _render_svg(data, size):
    renderer = QSvgRenderer()
    no_animation = getattr(QtSvg.Option, "DisableAnimations", QtSvg.Option.NoOption)
    renderer.setOptions(QtSvg.Option.Tiny12FeaturesOnly | no_animation)
    if not renderer.load(QByteArray(data)) or renderer.viewBoxF().isEmpty():
        return QImage()
    view = renderer.viewBoxF()
    scale = size / max(view.width(), view.height())
    width, height = view.width() * scale, view.height() * scale
    if min(width, height) < 1:
        return QImage()
    image = QImage(size, size, QImage.Format.Format_ARGB32_Premultiplied)
    image.fill(0)
    painter = QPainter(image)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    renderer.render(painter, QRectF((size - width) / 2, (size - height) / 2, width, height))
    painter.end()
    return image


def custom_id(data):
    return "custom-" + hashlib.sha256(data).hexdigest()


def stored_icon_is_valid(icon_id, data):
    return bool(CUSTOM_ID.fullmatch(icon_id)) and not _png(data, ICON_SIZE).isNull() and custom_id(data) == icon_id


def import_icon(url):
    extension, data = _local_bytes(url)
    if extension == ".png":
        image = _png(data, 1024)
        if not image.isNull():
            image = image.scaled(
                ICON_SIZE, ICON_SIZE,
                Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation,
            )
    else:
        image = _render_svg(_validated_svg(data), ICON_SIZE)
    if image.isNull():
        raise ValueError("Не удалось открыть изображение. Для PNG предел — 1024 × 1024.")
    # Draw into a fresh image to drop ancillary metadata from the input file.
    clean = QImage(image.size(), QImage.Format.Format_ARGB32_Premultiplied)
    clean.fill(0)
    painter = QPainter(clean)
    painter.drawImage(0, 0, image)
    painter.end()
    buffer = QBuffer()
    buffer.open(QIODevice.OpenModeFlag.WriteOnly)
    if not clean.save(buffer, "PNG"):
        raise ValueError("Не удалось подготовить иконку.")
    data = bytes(buffer.data())
    return custom_id(data), data


class EntryIconProvider(QQuickImageProvider):
    def __init__(self, custom_data):
        super().__init__(QQuickImageProvider.ImageType.Image)
        self._custom_data = custom_data

    def requestImage(self, identifier, size, requested_size):
        key, _, ink = identifier.partition("/")
        side = min(ICON_SIZE, max(16, requested_size.width(), requested_size.height()))
        if CUSTOM_ID.fullmatch(key):
            image = _png(self._custom_data.get(key, b""), ICON_SIZE)
        elif key in ICONS and re.fullmatch(r"[0-9a-fA-F]{6}", ink):
            image = _render_svg(svg_for(key, "#" + ink), side)
        else:
            image = QImage()
        if size is not None:
            size.setWidth(image.width())
            size.setHeight(image.height())
        return image
