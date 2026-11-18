from importlib.metadata import distribution
from pathlib import Path

packaging = Path(SPECPATH).resolve()
root = packaging.parent

resources = []
for folder, pattern in (("qml", "*.qml"), ("components", "*.qml"), ("themes", "*.qml"),
                        ("themes", "qmldir"), ("assets", "umbra.ico"), ("assets", "umbra.png")):
    for path in (root / "app" / "ui" / folder).glob(pattern):
        resources.append((str(path), f"app/ui/{folder}"))

resources.append((str(packaging / "THIRD_PARTY_NOTICES.txt"), "licenses"))
resources.extend((str(path), "licenses") for path in (packaging / "licenses").glob("*.txt"))
for name in ("cryptography", "argon2-cffi", "argon2-cffi-bindings", "cffi", "pycparser", "pyinstaller"):
    metadata = distribution(name)
    for file in metadata.files or ():
        if any(part.lower() in ("licenses", "license") for part in file.parts[:-1]) or (
            ".dist-info" in str(file) and file.name.upper().startswith(("LICENSE", "COPYING"))
        ):
            source = metadata.locate_file(file)
            target = Path("licenses") / name / Path(*file.parts[1:-1])
            resources.append((str(source), str(target)))

analysis = Analysis(
    [str(packaging / "entrypoint.py")], pathex=[str(root)],
    binaries=[], datas=resources, hiddenimports=[],
    excludes=["app.core.samples"], noarchive=False
)

# QtCore uses the ICU API built into Windows 11. A same-named ICU DLL
# from another SDK on the build machine can shadow the system DLL.
system_icu = {"icu.dll", "icuuc.dll", "icuin.dll"}
unused_qt = {"qt6quicktimeline.dll", "qt6quicktimelineblendtrees.dll", "qt6quicktest.dll", "qt6test.dll"}
unused_qml = (
    "pyside6/qml/qttest/", "pyside6/qml/qtquick/timeline/",
    "pyside6/qml/qtquick/virtualkeyboard/", "pyside6/qml/qt/labs/assetdownloader/",
)


def needed(item):
    destination = item[0].replace(chr(92), "/").lower()
    name = destination.rsplit("/", 1)[-1]
    return (name not in system_icu | unused_qt
            and not (name.startswith("icudt") and name.endswith(".dll"))
            and not destination.startswith(unused_qml))


analysis.binaries = [item for item in analysis.binaries if needed(item)]
analysis.datas = [item for item in analysis.datas if needed(item)]
pyz = PYZ(analysis.pure)
exe = EXE(
    pyz, analysis.scripts, [],
    exclude_binaries=True, name="UmbraVault", console=False, upx=False,
    icon=str(root / "app" / "ui" / "assets" / "umbra.ico"),
    version=str(packaging / "version_info.txt"),
)
bundle = COLLECT(exe, analysis.binaries, analysis.datas, strip=False, upx=False, name="UmbraVault")
