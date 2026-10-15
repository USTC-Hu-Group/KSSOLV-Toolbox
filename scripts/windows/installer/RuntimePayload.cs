// Reuse MathWorks' generated bootstrap and Runtime payload without running MATLAB.
using System;
using System.ComponentModel;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Xml;

public static class InstallerResources
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr LoadLibraryEx(string file, IntPtr reserved, uint flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr FindResource(IntPtr module, string name, IntPtr type);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint SizeofResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LoadResource(IntPtr module, IntPtr resource);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LockResource(IntPtr resource);
    [DllImport("kernel32.dll")]
    private static extern bool FreeLibrary(IntPtr module);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr BeginUpdateResource(string file, bool deleteExisting);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool UpdateResource(IntPtr update, IntPtr type, string name, ushort language, byte[] data, uint size);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool EndUpdateResource(IntPtr update, bool discard);

    public static bool Has(string file, string name)
    {
        IntPtr module = LoadLibraryEx(file, IntPtr.Zero, 0x22);
        if (module == IntPtr.Zero) throw new Win32Exception();
        try { return FindResource(module, name, new IntPtr(10)) != IntPtr.Zero; }
        finally { FreeLibrary(module); }
    }

    public static byte[] Read(string file, string name)
    {
        // DATAFILE | IMAGE_RESOURCE: load resource data without executing the file.
        IntPtr module = LoadLibraryEx(file, IntPtr.Zero, 0x22);
        if (module == IntPtr.Zero) throw new Win32Exception();
        try
        {
            IntPtr resource = FindResource(module, name, new IntPtr(10));
            if (resource == IntPtr.Zero) return null;
            uint size = SizeofResource(module, resource);
            IntPtr pointer = LockResource(LoadResource(module, resource));
            if (pointer == IntPtr.Zero || size > int.MaxValue) throw new InvalidDataException("Invalid installer resource: " + name);
            var data = new byte[(int)size];
            Marshal.Copy(pointer, data, 0, data.Length);
            return data;
        }
        finally { FreeLibrary(module); }
    }

    public static void Write(string file, string name, byte[] data)
    {
        IntPtr update = BeginUpdateResource(file, false);
        if (update == IntPtr.Zero) throw new Win32Exception();
        try
        {
            if (!UpdateResource(update, new IntPtr(10), name, 0, data, data == null ? 0 : (uint)data.Length))
                throw new Win32Exception();
            if (!EndUpdateResource(update, false)) throw new Win32Exception();
            update = IntPtr.Zero;
        }
        finally { if (update != IntPtr.Zero) EndUpdateResource(update, true); }
    }
}

internal static class RuntimePayload
{
    private const string BundleResource = "MW_COMPILER_EZDEPLOY_INSTALL_BUNDLE";
    private const string AgentResource = "MW_COMPILER_EZDEPLOY_INSTALL_AGENT";
    private const string UrlResource = "MW_COMPILER_EZDEPLOY_INSTALLAGENT_URL";
    private const string ManifestName = "ApplicationInstallerManifest.xml";

    private static int Main(string[] args)
    {
        try
        {
            if (args.Length != 4) throw new ArgumentException("Expected base installer, application, output directory and delivery mode.");
            string input = Path.GetFullPath(args[0]), app = Path.GetFullPath(args[1]);
            string output = Path.GetFullPath(args[2]), requested = args[3].ToLowerInvariant();
            if (Directory.Exists(output)) throw new IOException("Output directory must be fresh: " + output);
            Directory.CreateDirectory(output);
            bool zip = string.Equals(Path.GetExtension(input), ".zip", StringComparison.OrdinalIgnoreCase);
            string bootstrap = Path.Combine(output, "RuntimeSetup.exe");
            string bundleFile = null;
            byte[] bundle;
            bool online, agent;
            if (zip)
            {
                ExtractSafe(input, output);
                string sourceExe = Path.Combine(output, Path.GetFileNameWithoutExtension(input) + ".exe");
                if (!File.Exists(sourceExe)) throw new InvalidDataException("Missing MathWorks ZIP bootstrap executable.");
                File.Move(sourceExe, bootstrap);
                bundleFile = Path.Combine(output, "data", "bundle.zip");
                bundle = File.ReadAllBytes(bundleFile);
                agent = File.Exists(Path.Combine(output, "data", "InstallAgent.zip"));
                online = false;
            }
            else
            {
                bundle = InstallerResources.Read(input, BundleResource);
                if (bundle == null) throw new InvalidDataException("Missing MathWorks installer bundle resource.");
                online = InstallerResources.Read(input, UrlResource) != null;
                // Only presence is needed. Do not copy a potentially large offline agent into managed memory.
                agent = InstallerResources.Has(input, AgentResource);
            }
            byte[] runtimeBundle;
            bool hasProducts;
            using (var stream = new MemoryStream(bundle, false))
            using (var archive = new ZipArchive(stream, ZipArchiveMode.Read))
            {
                ZipArchiveEntry manifestEntry = archive.GetEntry(ManifestName);
                ZipArchiveEntry executable = archive.GetEntry("application/" + Path.GetFileName(app));
                if (manifestEntry == null || executable == null) throw new InvalidDataException("Base installer is missing its manifest or application.");
                using (var installed = executable.Open())
                using (var built = File.OpenRead(app))
                using (var sha = SHA256.Create())
                {
                    string expected = BitConverter.ToString(sha.ComputeHash(built));
                    if (BitConverter.ToString(sha.ComputeHash(installed)) != expected)
                        throw new InvalidDataException("Base installer application does not match the current build. Run buildInstaller() again.");
                }
                var document = new XmlDocument { XmlResolver = null };
                using (var manifest = manifestEntry.Open())
                using (var reader = XmlReader.Create(manifest, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null }))
                    document.Load(reader);
                if (document.DocumentElement == null || document.DocumentElement.Name != "ApplicationInstallerManifest")
                    throw new InvalidDataException("Unrecognized MathWorks application manifest.");
                XmlNode products = document.DocumentElement.SelectSingleNode("MCRProducts");
                // MathWorks omits MCRProducts completely for RuntimeDelivery=none.
                hasProducts = products != null && products.SelectNodes("MCRProduct").Count != 0;
                var runtime = new XmlDocument { XmlResolver = null };
                runtime.AppendChild(runtime.CreateElement("ApplicationInstallerManifest"));
                if (products != null) runtime.DocumentElement.AppendChild(runtime.ImportNode(products, true));
                using (var target = new MemoryStream())
                {
                    using (var result = new ZipArchive(target, ZipArchiveMode.Create, true))
                    using (var entry = result.CreateEntry(ManifestName).Open())
                    using (var writer = XmlWriter.Create(entry, new XmlWriterSettings { Encoding = new UTF8Encoding(false), Indent = true }))
                        runtime.Save(writer);
                    runtimeBundle = target.ToArray();
                }
            }
            string delivery = !hasProducts ? "none" : online ? "web" : agent ? "installer" : "";
            if (delivery == "") throw new InvalidDataException("Missing Runtime payload in base installer.");
            if (requested == "none") delivery = "none";
            else if (requested != "auto" && requested != delivery)
                throw new InvalidDataException("Base installer delivery is " + delivery + "; requested " + requested + ". Rebuild the matching base installer first.");
            if (delivery != "none")
            {
                if (zip) File.WriteAllBytes(bundleFile, runtimeBundle);
                else
                {
                    File.Copy(input, bootstrap);
                    File.SetAttributes(bootstrap, FileAttributes.Normal);
                    InstallerResources.Write(bootstrap, BundleResource, runtimeBundle);
                }
            }
            File.WriteAllText(Path.Combine(output, "payload.json"),
                "{\"RuntimeDelivery\":\"" + delivery + "\",\"RuntimeIsZip\":" + (zip ? "1" : "0") + "}", new UTF8Encoding(false));
            Console.WriteLine("WINDOWS_RUNTIME_PAYLOAD_REUSED " + delivery + " " + input);
            return 0;
        }
        catch (Exception error) { Console.Error.WriteLine(error.Message); return 1; }
    }

    private static void ExtractSafe(string input, string output)
    {
        string root = output.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        using (var archive = ZipFile.OpenRead(input))
        {
            foreach (var entry in archive.Entries)
            {
                string target = Path.GetFullPath(Path.Combine(output, entry.FullName));
                if (entry.FullName.IndexOf(':') >= 0 || !target.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Unsafe path in base installer ZIP: " + entry.FullName);
                if (string.IsNullOrEmpty(entry.Name)) Directory.CreateDirectory(target);
                else
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    entry.ExtractToFile(target, false);
                }
            }
        }
    }
}
