param(
    [int]$Intervalo = 10, // Alterar este valor para cambiar el intervalo de tiempo entre cambios de wallpaper
    [ValidateSet("Seconds", "Minutes", "Hours")]
    [string]$Unidad = "Minutes",
    [int]$TransicionCicloMs = 2000,
    [int]$TransicionCicloFps = 120,
    [int]$PollingMs = 150
)

$ErrorActionPreference = "Stop"

$currentDir = $PSScriptRoot
if (-not $currentDir) { $currentDir = Get-Location }

$wpDir = Join-Path $currentDir "wallpapers"
$cacheDir = Join-Path $currentDir "cache"
$transitionTemp = Join-Path $cacheDir "transition.jpg"
$errorLogPath = Join-Path $cacheDir "lumina-error.log"

if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir | Out-Null
}

$libDir = Join-Path $currentDir "lib"
. (Join-Path $libDir "Lumina.Wallpaper.ps1")

if (-not (Test-Path $wpDir)) {
    New-Item -ItemType Directory -Path $wpDir | Out-Null
}
$intervalSeconds = switch ($Unidad) {
    "Seconds" { [double]$Intervalo }
    "Minutes" { [double]$Intervalo * 60 }
    "Hours" { [double]$Intervalo * 3600 }
}

function Get-LuminaWallpaperList {
    param([string]$WallpaperDir)
    return Get-ChildItem -Path $WallpaperDir -Filter "*.png" -File |
        Where-Object { $_.BaseName -match '^\d+$' } |
        Sort-Object { [int]$_.BaseName }
}

$wallpapers = @()
$index = 0
$nextCycleAt = (Get-Date).AddSeconds($intervalSeconds)
$lastTargetPath = $null
$lastRefreshAt = Get-Date
$lastIndex = $index

try {
    while ($true) {
        try {
            $now = Get-Date
            if (($now - $lastRefreshAt).TotalSeconds -ge 3) {
                $wallpapers = Get-LuminaWallpaperList -WallpaperDir $wpDir
                if ($wallpapers.Count -gt 0) {
                    $index = $index % $wallpapers.Count
                } else {
                    $index = 0
                }
                $lastRefreshAt = $now
            }

            if ($wallpapers.Count -eq 0) {
                Start-Sleep -Milliseconds ([Math]::Max(250, $PollingMs))
                continue
            }

            $cycleChanged = $false
            if ($now -ge $nextCycleAt) {
                $index = ($index + 1) % $wallpapers.Count
                $nextCycleAt = $now.AddSeconds($intervalSeconds)
                $cycleChanged = $true
            }

            $currentImg = $wallpapers[$index]
            $normalPath = $currentImg.FullName
            $targetPath = $normalPath

            $indexChanged = ($lastIndex -ne $index) -or $cycleChanged
            $lastIndex = $index

            if (-not $lastTargetPath) {
                Set-LuminaWallpaper -Path $targetPath
                $lastTargetPath = $targetPath
            } elseif ($targetPath -ne $lastTargetPath) {
                if ($indexChanged -and $TransicionCicloMs -gt 0 -and $TransicionCicloFps -gt 0) {
                    Set-LuminaWallpaperFade -FromPath $lastTargetPath -ToPath $targetPath -DurationMs $TransicionCicloMs -Fps $TransicionCicloFps -FinalPath $targetPath
                } else {
                    Set-LuminaWallpaper -Path $targetPath
                }
                $lastTargetPath = $targetPath
            }

            Start-Sleep -Milliseconds ([Math]::Max(50, $PollingMs))
        } catch {
            "[{0}] {1}" -f (Get-Date).ToString("s"), $_ | Out-File -FilePath $errorLogPath -Append -Encoding utf8
            Start-Sleep -Milliseconds 500
            continue
        }
    }
} catch {
    "[{0}] {1}" -f (Get-Date).ToString("s"), $_ | Out-File -FilePath $errorLogPath -Append -Encoding utf8
}
