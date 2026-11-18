param(
    [string]$Python,
    [string]$InnoCompiler,
    [switch]$BundleOnly
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
if (-not $Python) { $Python = Join-Path $project '.venv\Scripts\python.exe' }
$Python = (Resolve-Path -LiteralPath $Python).Path
if (-not $BundleOnly) {
    if (-not $InnoCompiler) {
        $InnoCompiler = @(
            (Join-Path $project 'build\tools\Inno Setup\ISCC.exe')
            (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $InnoCompiler) { throw 'Pass -InnoCompiler with the path to Inno Setup ISCC.exe.' }
    $InnoCompiler = (Resolve-Path -LiteralPath $InnoCompiler).Path
}

Push-Location -LiteralPath $project
try {
    & $Python -c 'import platform, struct; assert platform.system() == "Windows" and struct.calcsize("P") == 8 and platform.machine().lower() in ("amd64", "x86_64"), "Windows x64 CPython required"'
    if ($LASTEXITCODE) { throw 'Windows x64 CPython required.' }

    & $Python -m unittest discover -s tests -v
    if ($LASTEXITCODE) { throw 'Tests failed. No new release will be built.' }

    & $Python packaging\make_icon.py
    if ($LASTEXITCODE) { throw 'Icon generation failed.' }

    & $Python -m PyInstaller --noconfirm --clean --workpath build\pyinstaller --distpath dist packaging\UmbraVault.spec
    if ($LASTEXITCODE) { throw 'PyInstaller build failed.' }
    if ($BundleOnly) { return }

    & $InnoCompiler packaging\UmbraVault.iss
    if ($LASTEXITCODE) { throw 'Inno Setup build failed.' }

    $version = & $Python -c 'from app.metadata import VERSION; print(VERSION)'
    if ($LASTEXITCODE -or -not $version) { throw 'Application version unavailable.' }
    $setupName = "UmbraVault-Setup-$version.exe"
    $installer = Join-Path $project "release\$setupName"
    $digest = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    "$digest  $setupName" | Set-Content -LiteralPath 'release\SHA256SUMS.txt' -Encoding ascii
    Write-Output $installer
} finally {
    Pop-Location
}
