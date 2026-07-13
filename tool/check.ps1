[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
$dart = Join-Path $root '.tools\flutter\bin\dart.bat'

if (-not (Test-Path -LiteralPath $flutter)) {
    throw 'Flutter SDK is missing. Run tool\bootstrap.ps1 first.'
}

Push-Location $root
try {
    & $dart run melos run format
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $dart run melos run analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $dart run melos run test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Push-Location 'packages\tuner_dsp'
    try {
        & $dart run 'tool\synthetic_accuracy_report.dart'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $dart run 'tool\guitar_accuracy_report.dart'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        & $dart run 'tool\public_corpus_report.dart'
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        Pop-Location
    }
}
finally {
    Pop-Location
}
