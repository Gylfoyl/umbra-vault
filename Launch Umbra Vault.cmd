@echo off
setlocal
pushd "%~dp0" || exit /b 1

if not exist ".venv\Scripts\pythonw.exe" (
    echo Umbra Vault: create the Python environment using README.md.
    pause
    popd
    exit /b 1
)

start "" "%CD%\.venv\Scripts\pythonw.exe" -m app.main
if errorlevel 1 (
    echo Umbra Vault could not start. See README.md.
    pause
    popd
    exit /b 1
)

popd
