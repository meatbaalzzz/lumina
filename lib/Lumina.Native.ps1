$ErrorActionPreference = "Stop"

if (-not ("LuminaWallpaper" -as [type])) {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms

    $code = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Diagnostics;

public static class LuminaWallpaper
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);

    public static void Set(string path)
    {
        SystemParametersInfo(0x0014, 0, path, 0);
    }
}

public static class DesktopWindow
{
    private static IntPtr _cachedHost = IntPtr.Zero;
    private static bool _initialized = false;
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    public static IntPtr GetWorkerW()
    {
        if (_initialized && _cachedHost != IntPtr.Zero) return _cachedHost;

        IntPtr workerw = IntPtr.Zero;
        EnumWindows((hWnd, lParam) =>
        {
            IntPtr defView = FindWindowEx(hWnd, IntPtr.Zero, "SHELLDLL_DefView", null);
            if (defView != IntPtr.Zero)
            {
                workerw = FindWindowEx(IntPtr.Zero, hWnd, "WorkerW", null);
            }
            return true;
        }, IntPtr.Zero);

        // Si no existe WorkerW, usar Progman como fallback sin enviar 0x052C
        if (workerw == IntPtr.Zero)
        {
            workerw = FindWindow("Progman", null);
        }

        _cachedHost = workerw;
        _initialized = true;
        return _cachedHost;
    }

    public static bool AttachToDesktop(IntPtr child)
    {
        var host = GetWorkerW();
        if (host == IntPtr.Zero) return false;
        return SetParent(child, host) != IntPtr.Zero;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    private static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_NOOWNERZORDER = 0x0200;

    public static void ToBottom(IntPtr hWnd)
    {
        SetWindowPos(hWnd, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
    }

    public static void PlaceOverlayBelowIcons(IntPtr overlay)
    {
        IntPtr host = GetWorkerW();
        if (host == IntPtr.Zero) return;
        SetParent(overlay, host);
        // Coloca overlay arriba del fondo dentro del host
        SetWindowPos(overlay, IntPtr.Zero /* HWND_TOP */, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
        // Asegura que los íconos quedan por encima
        IntPtr defView = FindWindowEx(host, IntPtr.Zero, "SHELLDLL_DefView", null);
        if (defView != IntPtr.Zero)
        {
            SetWindowPos(defView, overlay, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
        }
    }
}

public class LuminaOverlay : Form
{
    private Image fromScaled;
    private Stopwatch sw;
    private int durationMs;
    private int fps;

    public LuminaOverlay(Image fromImg, int durationMs, int fps)
    {
        this.FormBorderStyle = FormBorderStyle.None;
        this.TopMost = false;
        this.ShowInTaskbar = false;
        this.StartPosition = FormStartPosition.Manual;
        var bounds = Screen.PrimaryScreen.Bounds;
        this.Bounds = bounds;
        this.DoubleBuffered = true;
        this.durationMs = durationMs;
        this.fps = Math.Max(30, Math.Min(240, fps));
        this.fromScaled = ScaleToBounds(fromImg, bounds.Width, bounds.Height);
        this.Opacity = 1.0;
        this.sw = new Stopwatch();
    }

    protected override CreateParams CreateParams
    {
        get
        {
            var cp = base.CreateParams;
            cp.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW
            cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
            return cp;
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.InterpolationMode = InterpolationMode.Low;
        g.SmoothingMode = SmoothingMode.None;
        g.PixelOffsetMode = PixelOffsetMode.None;
        g.CompositingQuality = CompositingQuality.HighSpeed;
        g.DrawImage(fromScaled, new Rectangle(0, 0, this.Width, this.Height));
        base.OnPaint(e);
    }

    private static Image ScaleToBounds(Image img, int width, int height)
    {
        float scale = Math.Max(width / (float)img.Width, height / (float)img.Height);
        int dw = (int)Math.Round(img.Width * scale);
        int dh = (int)Math.Round(img.Height * scale);
        int x = (int)Math.Round((width - dw) / 2f);
        int y = (int)Math.Round((height - dh) / 2f);
        var bmp = new Bitmap(width, height, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(bmp))
        {
            g.InterpolationMode = InterpolationMode.Low;
            g.SmoothingMode = SmoothingMode.None;
            g.PixelOffsetMode = PixelOffsetMode.None;
            g.CompositingQuality = CompositingQuality.HighSpeed;
            g.Clear(Color.Black);
            g.DrawImage(img, new Rectangle(x, y, dw, dh));
        }
        return bmp;
    }

    public static void FadeOverlay(string fromPath, string toPath, int durationMs, int fps, string finalPath)
    {
        if (!File.Exists(toPath))
        {
            LuminaWallpaper.Set(finalPath);
            return;
        }
        if (string.Equals(fromPath, toPath, StringComparison.OrdinalIgnoreCase))
        {
            LuminaWallpaper.Set(finalPath);
            return;
        }
        using (var fromImg = File.Exists(fromPath) ? Image.FromFile(fromPath) : Image.FromFile(toPath))
        {
            LuminaWallpaper.Set(finalPath);
            var overlay = new LuminaOverlay(fromImg, durationMs, fps);
            overlay.Show();
            DesktopWindow.PlaceOverlayBelowIcons(overlay.Handle);
            overlay.sw.Restart();
            int frameTargetMs = Math.Max(2, 1000 / Math.Max(30, Math.Min(240, fps)));
            while (overlay.Opacity > 0.0)
            {
                double t = overlay.sw.Elapsed.TotalMilliseconds;
                double a = 1.0 - Math.Min(1.0, t / durationMs);
                overlay.Opacity = a;
                overlay.Invalidate();
                Application.DoEvents();
                System.Threading.Thread.Sleep(frameTargetMs);
            }
            overlay.Hide();
            overlay.Close();
        }
        return;
    }
}
"@

    Add-Type -TypeDefinition $code -ReferencedAssemblies @("System.Drawing", "System.Windows.Forms") -ErrorAction Stop
}
