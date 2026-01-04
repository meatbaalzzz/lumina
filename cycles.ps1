$currentDir = $PSScriptRoot
if (-not $currentDir) { $currentDir = Get-Location }

$wpDir = Join-Path $currentDir "wallpapers"
$blurDir = Join-Path $currentDir "blur"
$intervaloSegundos = 10

$code = @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
        [DllImport("user32.dll")]
        public static extern IntPtr GetShellWindow();
        [StructLayout(LayoutKind.Sequential)]
        public struct RECT { public int Left, Top, Right, Bottom; }
    }
"@
Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

function Set-Wallpaper($path) {
    $codeWP = @"
        using System.Runtime.InteropServices;
        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@
    Add-Type -TypeDefinition $codeWP -ErrorAction SilentlyContinue
    [Wallpaper]::SystemParametersInfo(0x0014, 0, $path, 0x01)
}

$index = 0

while($true) {
    $wallpapers = Get-ChildItem -Path $wpDir -Filter "*.png" |
                  Where-Object { $_.BaseName -match '^\d+$' } |
                  Sort-Object { [int]$_.BaseName }

    if ($wallpapers.Count -gt 0) {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $handle = [Win32]::GetForegroundWindow()
        $shellHandle = [Win32]::GetShellWindow()

        $hayVentanas = ($handle -ne $IntPtr::Zero -and $handle -ne $shellHandle)

        $rect = New-Object Win32+RECT
        [Win32]::GetWindowRect($handle, [ref]$rect)
        $isFullScreen = ($rect.Left -le 0 -and $rect.Top -le 0 -and $rect.Right -ge $screen.Width -and $rect.Bottom -ge $screen.Height)

        if (-not $isFullScreen) {
            $currentImg = $wallpapers[$index]
            $blurPath = Join-Path $blurDir $currentImg.Name

            if ($hayVentanas -and (Test-Path $blurPath)) {
                $targetPath = $blurPath
            } else {
                $targetPath = $currentImg.FullName
            }

            Set-Wallpaper -path $targetPath
            $index = ($index + 1) % $wallpapers.Count
        }
    }
    Start-Sleep -Seconds $intervaloSegundos
}
