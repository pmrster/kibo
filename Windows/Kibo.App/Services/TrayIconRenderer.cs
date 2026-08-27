using System.Drawing;
using System.Drawing.Imaging;
// This file is GDI. Pin the two names that also exist in System.Windows.Media.
using Color = System.Drawing.Color;
using PixelFormat = System.Drawing.Imaging.PixelFormat;
using Kibo.App.Controls;
using static Kibo.App.Services.NativeMethods;

namespace Kibo.App.Services;

/// <summary>
/// Draws Kibo's silhouette as a tray icon at the size the current DPI asks for, tinted for the
/// taskbar's theme. The port of <c>MenuBarIcon.swift</c>: the same 16×16 sprite, eyes as holes so
/// it does not read as a blob, at a whole-number pixel size.
/// </summary>
internal static class TrayIconRenderer
{
    /// <summary>The caller owns the returned <see cref="Icon"/> and its HICON; destroy the old one first.</summary>
    public static Icon Render(bool lightTaskbar, uint dpi)
    {
        var size = Math.Max(16, GetSystemMetricsForDpi(SM_CXSMICON, dpi));
        var pixel = Math.Max(1, size / 16);
        var drawn = pixel * 16;
        var offset = (size - drawn) / 2;
        var colour = lightTaskbar ? Color.Black : Color.White;

        using var bitmap = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(bitmap))
        using (var brush = new SolidBrush(colour))
        {
            graphics.Clear(Color.Transparent);
            var rows = KiboSprite.RowsFor(KiboSprite.Eyes.Open);
            for (var y = 0; y < rows.Count; y++)
            {
                var row = rows[y];
                var x = 0;
                while (x < row.Length)
                {
                    if (row[x] != 'Y') { x++; continue; }
                    var start = x;
                    while (x < row.Length && row[x] == 'Y') x++;
                    graphics.FillRectangle(brush, offset + start * pixel, offset + y * pixel, (x - start) * pixel, pixel);
                }
            }
        }

        var hicon = bitmap.GetHicon();
        try
        {
            // Clone off the HICON so we can destroy the native handle and not leak it.
            using var owned = Icon.FromHandle(hicon);
            return (Icon)owned.Clone();
        }
        finally
        {
            DestroyIcon(hicon);
        }
    }
}
