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

public static class LuminaWallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public static void Set(string path) { SystemParametersInfo(0x0014, 0, path, 0x01 | 0x02); }
}

public static class WinAPI {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOACTIVATE = 0x0010;
}

public static class LuminaCache {
    private static readonly System.Collections.Generic.Dictionary<string, Image> _cache = new System.Collections.Generic.Dictionary<string, Image>();
    public static Image GetScaled(string path) {
        if (_cache.ContainsKey(path)) return _cache[path];
        var bounds = Screen.PrimaryScreen.Bounds;
        using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read))
        using (var src = Image.FromStream(stream)) {
            var bmp = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppPArgb);
            using (var g = Graphics.FromImage(bmp)) {
                float scale = Math.Max(bounds.Width / (float)src.Width, bounds.Height / (float)src.Height);
                int dw = (int)(src.Width * scale), dh = (int)(src.Height * scale);
                g.InterpolationMode = InterpolationMode.Low;
                g.DrawImage(src, (bounds.Width - dw) / 2, (bounds.Height - dh) / 2, dw, dh);
            }
            _cache[path] = bmp;
            return bmp;
        }
    }
}

public class LuminaOverlay : Form {
    public Image ImageNext;
    public LuminaOverlay() {
        this.FormBorderStyle = FormBorderStyle.None;
        this.StartPosition = FormStartPosition.Manual;
        this.Bounds = Screen.PrimaryScreen.Bounds;
        this.ShowInTaskbar = false;
        this.DoubleBuffered = true;
        this.BackColor = Color.Black;
        this.Opacity = 0;
    }

    protected override CreateParams CreateParams {
        get {
            var cp = base.CreateParams;
            // WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_LAYERED
            cp.ExStyle |= 0x80 | 0x08000000 | 0x80000;
            return cp;
        }
    }

    protected override void OnPaint(PaintEventArgs e) {
        if (ImageNext != null) e.Graphics.DrawImage(ImageNext, 0, 0);
    }
}

public static class LuminaFade {
    private static LuminaOverlay _overlay;

    public static void FadeWallpaper(string from, string to, int ms, int fps, string final) {
        if (_overlay == null) _overlay = new LuminaOverlay();

        _overlay.ImageNext = LuminaCache.GetScaled(to);
        _overlay.Opacity = 0;
        _overlay.Show();

        // POSICIONAMIENTO Z-ORDER: En lugar de SetParent, la mandamos al fondo del todo
        // Esto la pone detrás de la barra de tareas y ventanas, pero sigue siendo una ventana "libre"
        WinAPI.SetWindowPos(_overlay.Handle, WinAPI.HWND_BOTTOM, 0, 0, 0, 0, WinAPI.SWP_NOMOVE | WinAPI.SWP_NOSIZE | WinAPI.SWP_NOACTIVATE);

        // FADE IN (Aparece la nueva imagen sobre el fondo actual)
        Stopwatch sw = Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < ms) {
            _overlay.Opacity = (double)sw.ElapsedMilliseconds / ms;
            _overlay.Refresh();
            Application.DoEvents();
            System.Threading.Thread.Sleep(Math.Max(1, 1000/fps));
        }

        _overlay.Opacity = 1.0;
        LuminaWallpaper.Set(final);
        System.Threading.Thread.Sleep(200);

        // FADE OUT RÁPIDO
        sw.Restart();
        while (sw.ElapsedMilliseconds < 300) {
            _overlay.Opacity = 1.0 - ((double)sw.ElapsedMilliseconds / 300);
            Application.DoEvents();
            System.Threading.Thread.Sleep(10);
        }

        _overlay.Hide();
    }
}
"@

    Add-Type -TypeDefinition $code -ReferencedAssemblies @("System.Drawing", "System.Windows.Forms") -ErrorAction Stop
}