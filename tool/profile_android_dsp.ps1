[CmdletBinding()]
param(
    [int]$Samples = 12,
    [double]$MaximumMeanCpuPercent = 20,
    [string]$Package = 'app.toauner.toauner_app',
    [string]$OutputPath,
    [switch]$Enforce
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Samples -lt 3) {
    throw 'Samples must be at least 3 so the first partial interval can be discarded.'
}

$root = Split-Path -Parent $PSScriptRoot
$adbCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    (Get-Command adb -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
$adb = $adbCandidates | Select-Object -First 1
if (-not $adb) {
    throw 'adb was not found. Install Android platform-tools or add adb to PATH.'
}

$deviceLines = & $adb devices -l | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice(?:\s|$)' }
if (@($deviceLines).Count -ne 1) {
    throw "Expected exactly one authorized Android device, found $(@($deviceLines).Count)."
}
$serial = (($deviceLines | Select-Object -First 1) -split '\s+')[0]
$pidText = (& $adb -s $serial shell pidof $Package).Trim()
if (-not $pidText) {
    throw "Package $Package is not running. Open the precision tuner screen first."
}
$processId = ($pidText -split '\s+')[0]

$topOutput = & $adb -s $serial shell top -H -b -d 1 -n $Samples -p $processId -o 'PID,TID,%CPU,TIME+,CMDLINE'
if ($LASTEXITCODE -ne 0) {
    throw 'Android top failed.'
}

$rows = foreach ($line in $topOutput) {
    if ($line -match '^\s*(?<pid>\d+)\s+(?<tid>\d+)\s+(?<cpu>\d+(?:\.\d+)?)\s+\S+\s+(?<name>\S+)') {
        [pscustomobject]@{
            pid = [int]$Matches.pid
            tid = [int]$Matches.tid
            cpuPercent = [double]$Matches.cpu
            name = $Matches.name
        }
    }
}

if (@($rows).Count -eq 0) {
    throw 'No DartWorker rows were found. Keep the tuner listening while profiling.'
}

$workers = foreach ($group in ($rows | Group-Object tid)) {
    $threadPath = "/proc/$processId/task/$($group.Name)/comm"
    $threadNameValue = & $adb -s $serial shell "if [ -r '$threadPath' ]; then cat '$threadPath'; fi"
    if (-not $threadNameValue) {
        continue
    }
    $threadName = $threadNameValue.Trim()
    if ($threadName -ne 'DartWorker') {
        continue
    }
    $ordered = @($group.Group)
    $usable = if (@($ordered).Count -gt 1) { @($ordered | Select-Object -Skip 1) } else { @() }
    if (@($usable).Count -eq 0) {
        continue
    }
    $values = @($usable | ForEach-Object { $_.cpuPercent })
    $mean = ($values | Measure-Object -Average).Average
    [pscustomobject]@{
        tid = [int]$group.Name
        threadName = $threadName
        samplesPercentOfOneCore = $values
        meanPercentOfOneCore = [math]::Round($mean, 3)
    }
}

$candidate = $workers | Sort-Object meanPercentOfOneCore -Descending | Select-Object -First 1
if (-not $candidate) {
    throw 'DartWorker samples were present but no complete one-second intervals remained.'
}

$deviceModel = (& $adb -s $serial shell getprop ro.product.model).Trim()
$androidRelease = (& $adb -s $serial shell getprop ro.build.version.release).Trim()
$result = [ordered]@{
    measuredAt = (Get-Date).ToString('o')
    gitCommit = (git -C $root rev-parse HEAD).Trim()
    serial = $serial
    deviceModel = $deviceModel
    androidRelease = $androidRelease
    package = $Package
    processId = [int]$processId
    requestedIntervals = $Samples
    discardedFirstIntervalPerThread = $true
    workers = @($workers)
    dspCandidateTid = $candidate.tid
    dspCandidateMeanPercentOfOneCore = $candidate.meanPercentOfOneCore
    maximumMeanCpuPercent = $MaximumMeanCpuPercent
    passesMeanCpuGate = $candidate.meanPercentOfOneCore -le $MaximumMeanCpuPercent
    identificationCaveat = 'Highest active DartWorker is a candidate until its CPU time is confirmed to stop after leaving the tuner screen.'
}

if (-not $OutputPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $root "reports\android-dsp-profile-$stamp.json"
}
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8
$result | ConvertTo-Json -Depth 8

if ($Enforce -and -not $result.passesMeanCpuGate) {
    exit 1
}
