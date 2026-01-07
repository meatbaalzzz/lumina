$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Lumina.Native.ps1")

function Set-LuminaWallpaper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    [LuminaWallpaper]::Set($Path)
}

function Set-LuminaWallpaperFade {
    param(
        [string]$FromPath,
        [Parameter(Mandatory = $true)]
        [string]$ToPath,
        [int]$DurationMs = 700,
        [int]$Fps = 120,
        [Parameter(Mandatory = $true)]
        [string]$FinalPath
    )

    [LuminaFade]::FadeWallpaper($FromPath, $ToPath, $DurationMs, $Fps, $FinalPath)
}
