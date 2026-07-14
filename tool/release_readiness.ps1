[CmdletBinding()]
param(
    [string]$Root,
    [switch]$Strict,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function New-Finding {
    param(
        [string]$Code,
        [ValidateSet('pass', 'warning', 'blocker')]
        [string]$Status,
        [string]$Message
    )

    [pscustomobject]@{
        code = $Code
        status = $Status
        message = $Message
    }
}

function Read-RequiredFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
}

function Test-FinalReleaseDocument {
    param(
        [string]$Path,
        [string[]]$RequiredMetadata
    )

    $text = Read-RequiredFile $Path
    if ($null -eq $text) {
        return $false
    }
    if ($text -notmatch '(?m)^release_status:\s*final\s*$') {
        return $false
    }
    foreach ($key in $RequiredMetadata) {
        $match = [regex]::Match($text, "(?m)^$([regex]::Escape($key)):\s*(.+?)\s*$")
        if (-not $match.Success -or $match.Groups[1].Value -match '^(TBD|미정|)$') {
            return $false
        }
    }
    return $true
}

function Read-KeyValueFile {
    param([string]$Path)

    $values = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) {
            continue
        }
        $separator = $trimmed.IndexOf('=')
        if ($separator -le 0) {
            continue
        }
        $values[$trimmed.Substring(0, $separator).Trim()] = $trimmed.Substring($separator + 1).Trim()
    }
    return $values
}

function Get-ReleaseFindings {
    param([string]$WorkspaceRoot)

    $findings = [Collections.Generic.List[object]]::new()
    $gradlePath = Join-Path $WorkspaceRoot 'app\android\app\build.gradle.kts'
    $manifestPath = Join-Path $WorkspaceRoot 'app\android\app\src\main\AndroidManifest.xml'
    $iosProjectPath = Join-Path $WorkspaceRoot 'app\ios\Runner.xcodeproj\project.pbxproj'
    $iosInfoPath = Join-Path $WorkspaceRoot 'app\ios\Runner\Info.plist'
    $pubspecPath = Join-Path $WorkspaceRoot 'app\pubspec.yaml'

    $gradle = Read-RequiredFile $gradlePath
    $manifest = Read-RequiredFile $manifestPath
    $iosProject = Read-RequiredFile $iosProjectPath
    $iosInfo = Read-RequiredFile $iosInfoPath
    $pubspec = Read-RequiredFile $pubspecPath

    if ($null -eq $gradle) {
        $findings.Add((New-Finding 'android_config_missing' 'blocker' 'Android Gradle configuration is missing.'))
    }
    else {
        $applicationId = [regex]::Match($gradle, 'applicationId\s*=\s*"([^"]+)"').Groups[1].Value
        if ($applicationId -match '^(com\.)?example\.' -or $applicationId -notmatch '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$') {
            $findings.Add((New-Finding 'android_application_id' 'blocker' "Android applicationId is not release-safe: '$applicationId'."))
        }
        else {
            $findings.Add((New-Finding 'android_application_id' 'pass' "Android applicationId is '$applicationId'."))
        }

        if ($gradle -match 'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)') {
            $findings.Add((New-Finding 'android_release_signing' 'blocker' 'Android release still uses the debug signing key.'))
        }
        elseif ($gradle -notmatch 'create\("release"\)' -or $gradle -notmatch 'signingConfig\s*=\s*signingConfigs\.getByName\("release"\)') {
            $findings.Add((New-Finding 'android_release_signing' 'blocker' 'Android release signing configuration is missing.'))
        }
        else {
            $propertiesPath = Join-Path $WorkspaceRoot 'app\android\key.properties'
            if (-not (Test-Path -LiteralPath $propertiesPath -PathType Leaf)) {
                $findings.Add((New-Finding 'android_release_signing' 'blocker' 'Android upload signing is configured, but private key.properties is missing.'))
            }
            else {
                $properties = Read-KeyValueFile $propertiesPath
                $required = @('storePassword', 'keyPassword', 'keyAlias', 'storeFile')
                $invalid = @($required | Where-Object {
                    -not $properties.ContainsKey($_) -or
                    [string]::IsNullOrWhiteSpace($properties[$_]) -or
                    $properties[$_] -match '^REPLACE_'
                })
                if ($invalid.Count -gt 0) {
                    $findings.Add((New-Finding 'android_release_signing' 'blocker' "Android key.properties has missing or placeholder fields: $($invalid -join ', ')."))
                }
                else {
                    $storePath = $properties['storeFile']
                    if (-not [IO.Path]::IsPathRooted($storePath)) {
                        $storePath = Join-Path (Join-Path $WorkspaceRoot 'app\android') $storePath
                    }
                    if (-not (Test-Path -LiteralPath $storePath -PathType Leaf)) {
                        $findings.Add((New-Finding 'android_release_signing' 'blocker' 'Android key.properties points to a missing upload keystore.'))
                    }
                    else {
                        $findings.Add((New-Finding 'android_release_signing' 'pass' 'Android release uses a private upload signing configuration.'))
                    }
                }
            }
        }
    }

    if ($null -eq $manifest) {
        $findings.Add((New-Finding 'android_permissions' 'blocker' 'Android main manifest is missing.'))
    }
    else {
        if ($manifest -notmatch 'android\.permission\.RECORD_AUDIO') {
            $findings.Add((New-Finding 'android_record_audio' 'blocker' 'Android main manifest does not declare RECORD_AUDIO.'))
        }
        else {
            $findings.Add((New-Finding 'android_record_audio' 'pass' 'Android main manifest declares RECORD_AUDIO.'))
        }
        if ($manifest -match 'android\.permission\.INTERNET') {
            $findings.Add((New-Finding 'android_release_internet' 'blocker' 'Android main manifest unexpectedly declares INTERNET.'))
        }
        else {
            $findings.Add((New-Finding 'android_release_internet' 'pass' 'Android main manifest has no release INTERNET permission.'))
        }
    }

    if ($null -eq $iosProject -or $iosProject -match 'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*(com\.)?example\.') {
        $findings.Add((New-Finding 'ios_bundle_identifier' 'blocker' 'iOS bundle identifier is missing or still uses an example namespace.'))
    }
    else {
        $findings.Add((New-Finding 'ios_bundle_identifier' 'pass' 'iOS bundle identifier is not an example namespace.'))
    }

    if ($null -eq $iosInfo -or $iosInfo -notmatch '<key>NSMicrophoneUsageDescription</key>\s*<string>[^<]+</string>') {
        $findings.Add((New-Finding 'ios_microphone_description' 'blocker' 'iOS microphone usage description is missing or empty.'))
    }
    else {
        $findings.Add((New-Finding 'ios_microphone_description' 'pass' 'iOS microphone usage description is present.'))
    }

    $version = if ($null -eq $pubspec) { '' } else { [regex]::Match($pubspec, '(?m)^version:\s*([^\s]+)').Groups[1].Value }
    if ($version -notmatch '^\d+\.\d+\.\d+\+\d+$') {
        $findings.Add((New-Finding 'app_version' 'blocker' "App version is missing or invalid: '$version'."))
    }
    else {
        $findings.Add((New-Finding 'app_version' 'pass' "App version is '$version'."))
    }

    foreach ($policy in @(
        @{
            Code = 'privacy_policy'
            Path = 'docs\privacy-policy.md'
            Label = 'Privacy policy'
            Metadata = @('developer_name', 'privacy_contact', 'public_url', 'effective_date')
        },
        @{
            Code = 'play_data_safety'
            Path = 'docs\play-data-safety.md'
            Label = 'Play Data Safety worksheet'
            Metadata = @('reviewed_build', 'reviewed_by', 'reviewed_date')
        }
    )) {
        $path = Join-Path $WorkspaceRoot $policy.Path
        if (-not (Test-FinalReleaseDocument $path $policy.Metadata)) {
            $findings.Add((New-Finding $policy.Code 'blocker' "$($policy.Label) is missing or not finalized at $($policy.Path)."))
        }
        else {
            $findings.Add((New-Finding $policy.Code 'pass' "$($policy.Label) is finalized."))
        }
    }

    $licenseAuditPath = Join-Path $WorkspaceRoot 'tool\license_audit.ps1'
    if (Test-Path -LiteralPath $licenseAuditPath -PathType Leaf) {
        $findings.Add((New-Finding 'dependency_license_gate' 'pass' 'Dependency license scanning is enforced by tool/check.ps1.'))
    }
    else {
        $findings.Add((New-Finding 'dependency_license_gate' 'blocker' 'Dependency license scanning is not implemented.'))
    }
    return $findings
}

function Invoke-SelfTest {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('toauner-release-readiness-' + [guid]::NewGuid().ToString('N'))
    try {
        $paths = @(
            'app\android\app\src\main',
            'app\ios\Runner.xcodeproj',
            'app\ios\Runner',
            'docs'
        )
        foreach ($path in $paths) {
            New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot $path) | Out-Null
        }
        [IO.File]::WriteAllText((Join-Path $tempRoot 'app\android\app\build.gradle.kts'), 'applicationId = "com.example.demo"`nsigningConfig = signingConfigs.getByName("debug")')
        [IO.File]::WriteAllText((Join-Path $tempRoot 'app\android\app\src\main\AndroidManifest.xml'), '<manifest><uses-permission android:name="android.permission.INTERNET" /></manifest>')
        [IO.File]::WriteAllText((Join-Path $tempRoot 'app\ios\Runner.xcodeproj\project.pbxproj'), 'PRODUCT_BUNDLE_IDENTIFIER = com.example.demo;')
        [IO.File]::WriteAllText((Join-Path $tempRoot 'app\ios\Runner\Info.plist'), '<plist><dict></dict></plist>')
        [IO.File]::WriteAllText((Join-Path $tempRoot 'app\pubspec.yaml'), 'version: development')

        $codes = @(Get-ReleaseFindings $tempRoot | Where-Object status -eq 'blocker' | ForEach-Object code)
        $expected = @(
            'android_application_id', 'android_release_signing', 'android_record_audio',
            'android_release_internet', 'ios_bundle_identifier', 'ios_microphone_description',
            'app_version', 'privacy_policy', 'play_data_safety', 'dependency_license_gate'
        )
        foreach ($code in $expected) {
            if ($codes -notcontains $code) {
                throw "Self-test did not detect expected blocker '$code'."
            }
        }

        [IO.File]::WriteAllText(
            (Join-Path $tempRoot 'app\android\app\build.gradle.kts'),
            'applicationId = "app.toauner.test"`nsigningConfigs { create("release") }`nsigningConfig = signingConfigs.getByName("release")'
        )
        [IO.File]::WriteAllText((Join-Path $tempRoot 'app\android\upload.jks'), 'self-test')
        [IO.File]::WriteAllText(
            (Join-Path $tempRoot 'app\android\key.properties'),
            "storePassword=test`nkeyPassword=test`nkeyAlias=upload`nstoreFile=upload.jks"
        )
        $positiveSigning = Get-ReleaseFindings $tempRoot | Where-Object code -eq 'android_release_signing'
        if ($positiveSigning.status -ne 'pass') {
            throw 'Self-test did not accept a private release signing configuration.'
        }
        Write-Output "release readiness self-test passed ($($expected.Count) blockers detected)"
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            $resolved = (Resolve-Path -LiteralPath $tempRoot).Path
            $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
            if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to remove non-temp self-test path: $resolved"
            }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = (Resolve-Path -LiteralPath $Root).Path
$results = @(Get-ReleaseFindings $Root)
$summary = [ordered]@{
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    status = if (@($results | Where-Object status -eq 'blocker').Count -gt 0) { 'blocked' } else { 'ready' }
    blockerCount = @($results | Where-Object status -eq 'blocker').Count
    warningCount = @($results | Where-Object status -eq 'warning').Count
    findings = $results
}

$reportDirectory = Join-Path $Root 'reports\release'
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$reportPath = Join-Path $reportDirectory 'release-readiness.json'
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$results | Format-Table status, code, message -AutoSize
Write-Output "Release readiness: $($summary.status) ($($summary.blockerCount) blockers, $($summary.warningCount) warnings)"
Write-Output "Report: $reportPath"

if ($Strict -and $summary.blockerCount -gt 0) {
    exit 1
}
