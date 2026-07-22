param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-SharkTuneBitmap {
    param(
        [int]$Size,
        [string]$Background,
        [string]$Foreground,
        [bool]$TransparentBackground = $false,
        [bool]$RoundBackground = $false
    )

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    if ($TransparentBackground) {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    } else {
        $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($Background))
    }

    if ($RoundBackground) {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $backgroundBrush = [System.Drawing.SolidBrush]::new(
            [System.Drawing.ColorTranslator]::FromHtml($Background)
        )
        $graphics.FillEllipse($backgroundBrush, 0, 0, $Size, $Size)
        $backgroundBrush.Dispose()
    }

    $scale = $Size / 1024.0
    $graphics.ScaleTransform($scale, $scale)
    $brush = [System.Drawing.SolidBrush]::new(
        [System.Drawing.ColorTranslator]::FromHtml($Foreground)
    )

    $fin = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $fin.StartFigure()
    $fin.AddBezier(204, 653, 337, 635, 411, 504, 463, 276)
    $fin.AddBezier(463, 276, 467, 257, 490, 250, 505, 262)
    $fin.AddBezier(505, 262, 625, 354, 690, 481, 724, 625)
    $fin.AddBezier(724, 625, 625, 611, 551, 638, 488, 680)
    $fin.AddBezier(488, 680, 400, 738, 302, 721, 204, 653)
    $fin.CloseFigure()

    $wave = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $wave.StartFigure()
    $wave.AddBezier(112, 697, 220, 628, 313, 630, 411, 696)
    $wave.AddBezier(411, 696, 506, 760, 598, 760, 696, 696)
    $wave.AddBezier(696, 696, 784, 637, 860, 636, 912, 666)
    $wave.AddLine(912, 666, 912, 760)
    $wave.AddBezier(912, 760, 845, 716, 783, 720, 715, 766)
    $wave.AddBezier(715, 766, 594, 848, 475, 848, 354, 766)
    $wave.AddBezier(354, 766, 278, 715, 209, 716, 112, 780)
    $wave.CloseFigure()

    $graphics.FillPath($brush, $fin)
    $graphics.FillPath($brush, $wave)
    $wave.Dispose()
    $fin.Dispose()
    $brush.Dispose()
    $graphics.Dispose()
    return $bitmap
}

function Save-SharkTuneBitmap {
    param(
        [string]$Path,
        [int]$Size,
        [bool]$TransparentBackground = $false,
        [bool]$RoundBackground = $false,
        [string]$Foreground = '#2FD6C6'
    )

    $bitmap = New-SharkTuneBitmap `
        -Size $Size `
        -Background '#06222A' `
        -Foreground $Foreground `
        -TransparentBackground $TransparentBackground `
        -RoundBackground $RoundBackground
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

$branding = Join-Path $WorkspaceRoot 'app\branding'
Save-SharkTuneBitmap `
    -Path (Join-Path $branding 'sharktune-mark-1024.png') `
    -Size 1024 `
    -TransparentBackground $true `
    -Foreground '#FFFFFF'
Save-SharkTuneBitmap `
    -Path (Join-Path $branding 'sharktune-app-icon-1024.png') `
    -Size 1024

$androidRoot = Join-Path $WorkspaceRoot 'app\android\app\src\main\res'
$androidSizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}
foreach ($entry in $androidSizes.GetEnumerator()) {
    $directory = Join-Path $androidRoot $entry.Key
    Save-SharkTuneBitmap `
        -Path (Join-Path $directory 'ic_launcher.png') `
        -Size $entry.Value
    Save-SharkTuneBitmap `
        -Path (Join-Path $directory 'ic_launcher_round.png') `
        -Size $entry.Value `
        -RoundBackground $true
}

$iosRoot = Join-Path $WorkspaceRoot 'app\ios\Runner\Assets.xcassets\AppIcon.appiconset'
Get-ChildItem -LiteralPath $iosRoot -Filter '*.png' | ForEach-Object {
    if ($_.BaseName -match 'Icon-App-(?<points>[0-9.]+)x[0-9.]+@(?<scale>[0-9]+)x') {
        $size = [int]([double]$Matches.points * [int]$Matches.scale)
        Save-SharkTuneBitmap -Path $_.FullName -Size $size
    }
}
