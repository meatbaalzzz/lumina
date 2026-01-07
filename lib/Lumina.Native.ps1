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
        // COLOR CLAVE: Ponemos el fondo transparente/negro para evitar el "flashbang" blanco
        this.BackColor = Color.Black; 
        this.Opacity = 0; 
    }

    protected override CreateParams CreateParams {
        get {
            var cp = base.CreateParams;
            // WS_EX_TOOLWINDOW (80) + WS_EX_NOACTIVATE (08000000) + WS_EX_LAYERED (80000)
            cp.ExStyle |= 0x80 | 0x08000000 | 0x80000;
            return cp;
        }
    }

    protected override void OnPaint(PaintEventArgs e) {
        if (ImageNext != null) {
            e.Graphics.DrawImage(ImageNext, 0, 0);
        }
    }
}

public static class LuminaFade {
    private static LuminaOverlay _overlay;

    public static void FadeWallpaper(string from, string to, int ms, int fps, string final) {
        if (_overlay == null) {
            _overlay = new LuminaOverlay();
        }

        _overlay.ImageNext = LuminaCache.GetScaled(to);
        _overlay.Opacity = 0;
        _overlay.Show();

        Stopwatch sw = Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < ms) {
            float progress = (float)sw.ElapsedMilliseconds / ms;
            _overlay.Opacity = progress;
            _overlay.Refresh();
            Application.DoEvents();
            System.Threading.Thread.Sleep(Math.Max(1, 1000/fps));
        }

        _overlay.Opacity = 1.0;
        _overlay.Refresh();

        LuminaWallpaper.Set(final);
        
        System.Threading.Thread.Sleep(250);

        sw.Restart();
        int fadeOutMs = 300; // Un desvanecimiento rápido para revelar los iconos/barra
        while (sw.ElapsedMilliseconds < fadeOutMs) {
            _overlay.Opacity = 1.0 - ((double)sw.ElapsedMilliseconds / fadeOutMs);
            Application.DoEvents();
            System.Threading.Thread.Sleep(10);
        }

        _overlay.Hide();
        _overlay.Opacity = 0;
    }
}
"@

    Add-Type -TypeDefinition $code -ReferencedAssemblies @("System.Drawing", "System.Windows.Forms") -ErrorAction Stop
}