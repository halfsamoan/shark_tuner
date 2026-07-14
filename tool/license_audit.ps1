[CmdletBinding()]
param(
    [string]$Root,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-LicenseFiles {
    param([string]$PackageRoot)

    return @(Get-ChildItem -LiteralPath $PackageRoot -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^(LICENSE|LICENCE|COPYING)(\..*)?$'
    })
}

function Test-ForbiddenLicenseText {
    param([string]$Text)

    $patterns = @(
        '(?im)^\s*GNU\s+(AFFERO\s+|LESSER\s+|LIBRARY\s+)?GENERAL\s+PUBLIC\s+LICENSE\s*$',
        '(?i)SPDX-License-Identifier\s*:\s*(AGPL|GPL|LGPL)-',
        '(?i)\b(AGPL|GPL|LGPL)-[123](?:\.0)?(?:-only|-or-later)?\b'
    )
    foreach ($pattern in $patterns) {
        if ($Text -match $pattern) {
            return $true
        }
    }
    return $false
}

function Get-ExternalPackageLicenses {
    param(
        [string]$WorkspaceRoot,
        [string]$PackageConfigPath
    )

    if (-not (Test-Path -LiteralPath $PackageConfigPath -PathType Leaf)) {
        throw "Package configuration is missing: $PackageConfigPath. Run tool\bootstrap.ps1 first."
    }

    $config = Get-Content -LiteralPath $PackageConfigPath -Raw | ConvertFrom-Json
    $workspacePrefix = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\') + '\'
    $flutterPrefix = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot '.tools\flutter')).TrimEnd('\') + '\'
    $results = [Collections.Generic.List[object]]::new()

    foreach ($package in $config.packages) {
        $uri = [Uri]$package.rootUri
        if (-not $uri.IsAbsoluteUri) {
            $packageRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $PackageConfigPath) $package.rootUri))
        }
        elseif ($uri.IsFile) {
            $packageRoot = [IO.Path]::GetFullPath($uri.LocalPath)
        }
        else {
            $results.Add([pscustomobject]@{
                package = $package.name
                status = 'blocker'
                source = $package.rootUri
                licenseFiles = @()
                licenseSha256 = @()
                message = 'Non-file package source cannot be audited.'
            })
            continue
        }
        if ($packageRoot.StartsWith($workspacePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if ($packageRoot.StartsWith($flutterPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $licenseFiles = @(Get-LicenseFiles $packageRoot)
        if ($licenseFiles.Count -eq 0) {
            $results.Add([pscustomobject]@{
                package = $package.name
                status = 'blocker'
                source = $packageRoot
                licenseFiles = @()
                licenseSha256 = @()
                message = 'No top-level LICENSE, LICENCE, or COPYING file was found.'
            })
            continue
        }

        $forbidden = $false
        $hashes = [Collections.Generic.List[string]]::new()
        foreach ($licenseFile in $licenseFiles) {
            $text = [IO.File]::ReadAllText($licenseFile.FullName)
            if (Test-ForbiddenLicenseText $text) {
                $forbidden = $true
            }
            $hashes.Add((Get-FileHash -LiteralPath $licenseFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant())
        }

        $results.Add([pscustomobject]@{
            package = $package.name
            status = if ($forbidden) { 'blocker' } else { 'pass' }
            source = $packageRoot
            licenseFiles = @($licenseFiles.Name)
            licenseSha256 = @($hashes)
            message = if ($forbidden) { 'GPL-family license marker detected.' } else { 'License files present; no GPL-family marker detected.' }
        })
    }

    return $results
}

function Invoke-SelfTest {
    $mit = @'
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy.
'@
    $gpl = @'
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
'@
    if (Test-ForbiddenLicenseText $mit) {
        throw 'Self-test classified MIT text as forbidden.'
    }
    if (-not (Test-ForbiddenLicenseText $gpl)) {
        throw 'Self-test did not detect a GPL heading.'
    }
    if (-not (Test-ForbiddenLicenseText 'SPDX-License-Identifier: AGPL-3.0-only')) {
        throw 'Self-test did not detect an SPDX AGPL identifier.'
    }
    Write-Output 'license audit self-test passed'
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = (Resolve-Path -LiteralPath $Root).Path
$packageConfigPath = Join-Path $Root '.dart_tool\package_config.json'
$packages = @(Get-ExternalPackageLicenses $Root $packageConfigPath)
$blockers = @($packages | Where-Object status -eq 'blocker')

$report = [ordered]@{
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    policy = 'GPL, AGPL, LGPL, and missing license files are forbidden for resolved external packages.'
    scope = 'Resolved external Dart packages; workspace packages and the pinned Flutter SDK are excluded.'
    status = if ($blockers.Count -eq 0) { 'pass' } else { 'blocked' }
    auditedPackageCount = $packages.Count
    blockerCount = $blockers.Count
    packages = $packages
}

$reportDirectory = Join-Path $Root 'reports\release'
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$reportPath = Join-Path $reportDirectory 'dependency-licenses.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8

if ($blockers.Count -gt 0) {
    $blockers | Format-Table package, message, source -AutoSize
    Write-Error "Dependency license audit failed with $($blockers.Count) blocker(s). Report: $reportPath"
    exit 1
}

Write-Output "Dependency license audit passed ($($packages.Count) external packages)."
Write-Output "Report: $reportPath"
