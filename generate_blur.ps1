$currentDir = $PSScriptRoot
if (-not $currentDir) { $currentDir = Get-Location }

$wpDir = Join-Path $currentDir "wallpapers"
$blurDir = Join-Path $currentDir "blur"

if (-not (Test-Path $wpDir)) {
    Write-Host "[ERROR] No se encontro la carpeta 'wallpapers'. Creala y pon tus .png numerados." -ForegroundColor Red
    pause
    exit
}

if (-not (Test-Path $blurDir)) {
    New-Item -ItemType Directory -Path $blurDir | Out-Null
}

Add-Type -AssemblyName System.Drawing

function New-BlurredImage {
    param([string]$SourcePath, [string]$DestinationPath)
    try {
        $image = [System.Drawing.Image]::FromFile($SourcePath)
        $bmp = New-Object System.Drawing.Bitmap($image.Width, $image.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)

        $scale = 0.1
        $smallWidth = [int]($image.Width * $scale)
        $smallHeight = [int]($image.Height * $scale)

        $smallBmp = New-Object System.Drawing.Bitmap($smallWidth, $smallHeight)
        $gSmall = [System.Drawing.Graphics]::FromImage($smallBmp)
        $gSmall.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gSmall.DrawImage($image, 0, 0, $smallWidth, $smallHeight)

        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($smallBmp, 0, 0, $image.Width, $image.Height)

        $bmp.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)

        $graphics.Dispose(); $gSmall.Dispose(); $smallBmp.Dispose(); $bmp.Dispose(); $image.Dispose()
    } catch {
        Write-Host "Error procesando: $SourcePath" -ForegroundColor Red
    }
}

Remove-Item -Path "$blurDir\*" -Include *.png -Force -ErrorAction SilentlyContinue

$images = Get-ChildItem -Path $wpDir -Filter "*.png" |
          Where-Object { $_.BaseName -match '^\d+$' } |
          Sort-Object { [int]$_.BaseName }

Write-Host "Generando versiones desenfocadas en /blur..." -ForegroundColor Cyan
foreach ($img in $images) {
    Write-Host "Procesando: $($img.Name)"
    New-BlurredImage -SourcePath $img.FullName -DestinationPath (Join-Path $blurDir $img.Name)
}

Write-Host "`n[OK] Sincronizacion completada." -ForegroundColor Green
