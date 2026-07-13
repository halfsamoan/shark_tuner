[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$flutterRoot = Join-Path $root '.tools\flutter'
$flutter = Join-Path $flutterRoot 'bin\flutter.bat'
$dart = Join-Path $flutterRoot 'bin\dart.bat'

if (-not (Test-Path -LiteralPath $flutter)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $flutterRoot) | Out-Null
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git $flutterRoot
}

& $flutter config --no-analytics
Push-Location $root
try {
    & $dart pub get
    & $dart run melos bootstrap
    & $flutter doctor -v
}
finally {
    Pop-Location
}
