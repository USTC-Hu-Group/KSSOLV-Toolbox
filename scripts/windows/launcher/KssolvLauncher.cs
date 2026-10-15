// Windows only. Shared by installation prewarm and all application shortcuts.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal static class KssolvLauncher
{
    private static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    private static string statusFile;
    private static bool chinese;
    private static string prewarmLogFile;

    [STAThread]
    private static int Main(string[] args)
    {
        bool prewarm = args.Contains("--prewarm");
        chinese = Option(args, "--language", System.Globalization.CultureInfo.CurrentUICulture.Name.StartsWith("zh") ? "zh" : "en") == "zh";
        statusFile = prewarm ? Option(args, "--result", null) : null;
        try
        {
            string appRoot = AppDomain.CurrentDomain.BaseDirectory;
            var config = ReadConfig(Path.Combine(appRoot, "launcher.ini"));
            string language;
            if (!prewarm && config.TryGetValue("Language", out language)) chinese = language == "zh";
            string exe = Path.Combine(appRoot, "application", "KSSOLV_Toolbox.exe");
            string runtime = Path.GetFullPath(config["RuntimeRoot"]);
            string release = config["RuntimeRelease"];
            string buildHash = config["BuildHash"];
            string sid = WindowsIdentity.GetCurrent().User.Value;
            if (WindowsIdentity.GetCurrent().IsSystem || Process.GetCurrentProcess().SessionId == 0)
                throw new InvalidOperationException("Prewarm/launch requires an interactive Windows user session.");
            if (!File.Exists(exe) || Hash(exe) != buildHash)
                throw new InvalidOperationException("Application payload is missing or differs from this installer build.");
            if (!File.Exists(Path.Combine(runtime, "runtime", "win64", "mclmcrrt" + config["RuntimeVersion"].Replace(".", "_") + ".dll")))
                throw new InvalidOperationException("Matching MATLAB Runtime is missing: " + runtime);

            // Cache is private to the actual launching user, release and application build.
            string cache = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "KSSOLV Toolbox", "RuntimeCache", release, buildHash.Substring(0, 16));
            Directory.CreateDirectory(cache);
            string marker = Path.Combine(cache, "prewarm-success.json");
            string nonce = Guid.NewGuid().ToString("N");
            string readyFile = Path.Combine(cache, "ready-" + nonce + ".json");
            string logFile = Path.Combine(cache, "prewarm.log");
            if (prewarm) prewarmLogFile = logFile;

            using (var mutex = new Mutex(false, "Local\\KSSOLV-Prewarm-" + sid + "-" + buildHash.Substring(0, 16)))
            {
                bool owns = false;
                if (prewarm)
                {
                    try { owns = mutex.WaitOne(0); } catch (AbandonedMutexException) { owns = true; }
                    if (!owns) throw new InvalidOperationException("A prewarm for this user and build is already running.");
                }
                try
                {
                    var start = new ProcessStartInfo(exe) { UseShellExecute = false, WorkingDirectory = appRoot };
                    start.Arguments = prewarm ? "--prewarm" : string.Join(" ", args.Select(Quote).ToArray());
                    // Never change the system/user PATH. Installed Runtime always wins over MATLAB.
                    string prefix = string.Join(";", new[] { "runtime", "bin", "sys\\os" }
                        .Select(p => Path.Combine(runtime, p, "win64")).ToArray());
                    start.EnvironmentVariables["PATH"] = prefix + ";" + Environment.GetEnvironmentVariable("PATH");
                    start.EnvironmentVariables["MCR_CACHE_ROOT"] = cache;
                    start.EnvironmentVariables["MCR_CACHE_SIZE"] = "4096M";
                    start.EnvironmentVariables["KSSOLV_HOST_IN_BROWSER"] = "0";
                    // Clear inherited installer-only signaling for regular launches.
                    start.EnvironmentVariables.Remove("KSSOLV_PREWARM_RESULT");
                    start.EnvironmentVariables.Remove("KSSOLV_PREWARM_NONCE");
                    if (prewarm)
                    {
                        start.EnvironmentVariables["KSSOLV_PREWARM_RESULT"] = readyFile;
                        start.EnvironmentVariables["KSSOLV_PREWARM_NONCE"] = nonce;
                        WriteLog(logFile, "Start " + DateTime.UtcNow.ToString("o") + " user=" + sid + " runtime=" + runtime);
                    }
                    var watch = Stopwatch.StartNew();
                    using (var child = Process.Start(start))
                    using (var job = prewarm ? new ProcessJob(child) : null)
                    {
                        if (!prewarm) return 0;
                        WriteStatus(new { status = "warming", cacheRoot = cache, userSid = sid, runtimeRoot = runtime });
                        if (!child.WaitForExit(900000))
                            throw new TimeoutException("Runtime prewarm exceeded 15 minutes. See " + logFile);
                        if (child.ExitCode != 0)
                            throw new InvalidOperationException("Application prewarm exited with code " + child.ExitCode + ". See " + logFile);
                        if (!File.Exists(readyFile))
                            throw new InvalidOperationException("Application exited without reporting full UI readiness.");
                        var ready = Json.Deserialize<Dictionary<string, object>>(File.ReadAllText(readyFile));
                        if (Convert.ToString(ready["status"]) != "ready" || Convert.ToString(ready["nonce"]) != nonce)
                            throw new InvalidOperationException("Invalid prewarm readiness signal.");
                        var result = new { status = "success", version = config["Version"], buildHash = buildHash,
                            runtimeRoot = runtime, runtimeRelease = release, userSid = sid, cacheRoot = cache,
                            elapsedSeconds = watch.Elapsed.TotalSeconds, completedUtc = DateTime.UtcNow.ToString("o") };
                        AtomicJson(marker, result);
                        WriteLog(logFile, "Success " + Json.Serialize(result));
                        WriteStatus(result); // Published only after readiness AND successful process exit.
                    }
                }
                finally { if (owns) mutex.ReleaseMutex(); if (prewarm && File.Exists(readyFile)) File.Delete(readyFile); }
            }
            return 0;
        }
        catch (Exception exception)
        {
            try { if (prewarmLogFile != null) WriteLog(prewarmLogFile, "Failed " + exception); } catch { }
            try { WriteStatus(new { status = "failed", error = exception.Message }); } catch { }
            if (!prewarm)
                MessageBox.Show((chinese ? "无法启动 KSSOLV Toolbox。\n" : "Unable to start KSSOLV Toolbox.\n") + exception.Message,
                    "KSSOLV Toolbox", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string Option(string[] args, string name, string fallback)
    { int i = Array.IndexOf(args, name); return i >= 0 && i + 1 < args.Length ? args[i + 1] : fallback; }

    private static Dictionary<string, string> ReadConfig(string file)
    {
        var result = new Dictionary<string, string>();
        foreach (string line in File.ReadAllLines(file))
        { int i = line.IndexOf('='); if (i > 0) result[line.Substring(0, i)] = line.Substring(i + 1); }
        return result;
    }
    private static string Hash(string path)
    { using (var hash = SHA256.Create()) using (var file = File.OpenRead(path))
        return BitConverter.ToString(hash.ComputeHash(file)).Replace("-", "").ToLowerInvariant(); }

    // CommandLineToArgvW-compatible quoting, including quotes and trailing backslashes.
    internal static string Quote(string value)
    {
        var output = new StringBuilder("\""); int slashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') output.Append('\\', slashes * 2 + 1); else output.Append('\\', slashes);
            output.Append(c); slashes = 0;
        }
        output.Append('\\', slashes * 2); return output.Append('"').ToString();
    }
    private static void WriteStatus(object data) { if (statusFile != null) AtomicJson(statusFile, data); }
    private static void AtomicJson(string path, object data)
    {
        string temp = path + ".tmp";
        File.WriteAllText(temp, Json.Serialize(data), new UTF8Encoding(false));
        if (File.Exists(path)) File.Delete(path);
        File.Move(temp, path);
    }
    private static void WriteLog(string file, string text)
    { File.AppendAllText(file, text + Environment.NewLine, new UTF8Encoding(false)); }

    // Closing the job kills all Runtime descendants on failure/timeout, including MATLABWindow.
    private sealed class ProcessJob : IDisposable
    {
        private IntPtr handle;
        [StructLayout(LayoutKind.Sequential)] private struct BasicLimit
        { public long ProcessTime, JobTime; public uint Flags; public UIntPtr MinWorkingSet, MaxWorkingSet;
          public uint ActiveProcessLimit; public UIntPtr Affinity; public uint Priority, Scheduling; }
        [StructLayout(LayoutKind.Sequential)] private struct IoCounters
        { public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
        [StructLayout(LayoutKind.Sequential)] private struct ExtendedLimit
        { public BasicLimit Basic; public IoCounters Io; public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory; }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr CreateJobObject(IntPtr security, string name);
        [DllImport("kernel32.dll")] private static extern bool SetInformationJobObject(IntPtr job, int cls, ref ExtendedLimit info, uint length);
        [DllImport("kernel32.dll")] private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
        public ProcessJob(Process process)
        {
            handle = CreateJobObject(IntPtr.Zero, null);
            var limit = new ExtendedLimit(); limit.Basic.Flags = 0x2000;
            if (handle == IntPtr.Zero || !SetInformationJobObject(handle, 9, ref limit, (uint)Marshal.SizeOf(limit)) ||
                !AssignProcessToJobObject(handle, process.Handle))
            { Dispose(); if (!process.HasExited) process.Kill(); throw new InvalidOperationException("Unable to supervise Runtime process lifetime."); }
        }
        public void Dispose() { if (handle != IntPtr.Zero) { CloseHandle(handle); handle = IntPtr.Zero; } }
    }
}
