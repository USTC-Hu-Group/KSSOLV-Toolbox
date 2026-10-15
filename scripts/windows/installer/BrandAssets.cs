// Produce Windows bitmap assets and icons from the official logo and selected artwork.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
internal static class BrandAssets
{
    private static void Main(string[] args)
    {
        if (args.Length != 3) throw new ArgumentException("Expected output directory, company logo and artwork.");
        Directory.CreateDirectory(args[0]);
        using (var logo = new Bitmap(args[1]))
        using (var art = new Bitmap(args[2]))
        {
            SaveBitmap(logo, Path.Combine(args[0], "brand-logo.bmp"), 384, 384);
            SaveBitmap(art, Path.Combine(args[0], "installer-art.bmp"), 600, 800);
            // Crop the existing H symbol; omit the wordmark at small icon sizes.
            using (var symbol = logo.Clone(new Rectangle(160, 48, 264, 264), PixelFormat.Format32bppArgb))
                SaveIcon(symbol, Path.Combine(args[0], "kssolv.ico"));
        }
    }
    private static void SaveBitmap(Image source, string path, int width, int height)
    {
        using (var bitmap = new Bitmap(width, height, PixelFormat.Format24bppRgb))
        using (var g = Graphics.FromImage(bitmap))
        {
            g.Clear(Color.FromArgb(243, 246, 250));
            DrawFit(g, source, width, height);
            bitmap.Save(path, ImageFormat.Bmp);
        }
    }
    private static void DrawFit(Graphics g, Image source, int width, int height)
    {
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        double scale = Math.Min((double)width / source.Width, (double)height / source.Height);
        float w = (float)(source.Width * scale), h = (float)(source.Height * scale);
        g.DrawImage(source, (width - w) / 2, (height - h) / 2, w, h);
    }
    private static void SaveIcon(Image symbol, string path)
    {
        using (var output = new BinaryWriter(File.Create(path)))
        {
            int[] sizes = {16, 24, 32, 48, 64, 128, 256};
            var data = new byte[sizes.Length][];
            for (int i = 0; i < sizes.Length; i++)
            using (var bitmap = new Bitmap(sizes[i], sizes[i], PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(bitmap))
            using (var stream = new MemoryStream())
            {
                g.Clear(Color.Transparent);
                DrawFit(g, symbol, sizes[i], sizes[i]);
                bitmap.Save(stream, ImageFormat.Png); data[i] = stream.ToArray();
            }
            output.Write((ushort)0); output.Write((ushort)1); output.Write((ushort)sizes.Length);
            int offset = 6 + sizes.Length * 16;
            for (int i = 0; i < sizes.Length; i++)
            {
                output.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                output.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                output.Write((byte)0); output.Write((byte)0);
                output.Write((ushort)1); output.Write((ushort)32);
                output.Write(data[i].Length); output.Write(offset); offset += data[i].Length;
            }
            foreach (byte[] bytes in data) output.Write(bytes);
        }
    }
}
