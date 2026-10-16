// Native window and Runtime lifetime protocol; HTML rendering lives in StartupCard.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public sealed class SplashWindow : Form
{
    private const int CanvasWidth = StartupCard.CanvasWidth, CanvasHeight = StartupCard.CanvasHeight;
    internal StartupCard Card;
    private PictureBox preview;
    private Button previewClose;
    private bool previewPainted;
    private readonly Timer poll = new Timer { Interval = 50 };
    private readonly JavaScriptSerializer json = new JavaScriptSerializer();
    private readonly Stopwatch watch = Stopwatch.StartNew();
    private readonly ProcessStartInfo start;
    private readonly string signal, nonce, html, log, version;
    private readonly bool chinese;
    private Process child;
    private KssolvLauncher.ProcessJob job;
    private bool starting, acknowledged, succeeded, finishing, polling;
    private Exception failure;

    internal static void Run(ProcessStartInfo start, string html, string signal,
        string nonce, bool chinese, string log, string version, bool legacy = false)
    {
        if (!File.Exists(html) || !File.Exists(Path.Combine(Path.GetDirectoryName(html), "company-logo.png")) ||
            !File.Exists(Path.Combine(Path.GetDirectoryName(html), "quantum-materials.png")))
            throw new FileNotFoundException("The startup card resources are missing. Reinstall KSSOLV Toolbox.");
        if (string.IsNullOrWhiteSpace(version)) throw new InvalidDataException("The application version is missing from launcher configuration.");
        Application.EnableVisualStyles();
        using (var window = new SplashWindow(start, html, signal, nonce, chinese, log, version, legacy))
        {
            Application.Run(window);
            if (!window.succeeded)
                throw window.failure ?? new OperationCanceledException("Application startup was cancelled.");
        }
    }

    private SplashWindow(ProcessStartInfo processStart, string page, string signalFile,
        string signalNonce, bool useChinese, string logFile, string appVersion, bool legacy)
    {
        start = processStart; html = Path.GetFullPath(page); signal = signalFile;
        nonce = signalNonce; chinese = useChinese; log = logFile; version = appVersion;
        Text = "KSSOLV Toolbox";
        SuspendLayout();
        // This form contains one docked HTML view; size it once in physical pixels.
        AutoScaleMode = AutoScaleMode.None;
        ClientSize = new Size(CanvasWidth, CanvasHeight);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None;
        BackColor = Color.White;
        string previewFile = Path.Combine(Path.GetDirectoryName(html), chinese ? "initial-zh.png" : "initial-en.png");
        string previewVersion = Path.Combine(Path.GetDirectoryName(html), "initial-version.txt");
        if (File.Exists(previewFile) && File.Exists(previewVersion) && File.ReadAllText(previewVersion).Trim() == version)
        {
            using (var source = Image.FromFile(previewFile))
                preview = new PictureBox { Dock = DockStyle.Fill, Image = new Bitmap(source), SizeMode = PictureBoxSizeMode.StretchImage };
            Controls.Add(preview);
            previewClose = new PreviewCloseButton { Text = "×", AccessibleName = chinese ? "取消启动" : "Cancel startup", FlatStyle = FlatStyle.Flat,
                ForeColor = Color.White, BackColor = Color.Transparent, Font = new Font("Segoe UI", 16), Parent = preview };
            previewClose.FlatAppearance.BorderSize = 0;
            previewClose.FlatAppearance.MouseOverBackColor = Color.FromArgb(35, 59, 80);
            previewClose.Click += delegate { Finish(new OperationCanceledException("Application startup was cancelled.")); };
            preview.Paint += delegate {
                if (previewPainted || finishing) return;
                previewPainted = true;
                WriteLog("card-painted renderer=preview");
                BeginInvoke((Action)(() => { if (!finishing) { StartRuntime(); LoadCard(legacy); } }));
            };
        }
        else InitializeCard(legacy);
        Shown += async delegate {
            poll.Start();
            try { if (preview == null) await Card.LoadAsync(html, chinese, version); }
            catch (Exception error) { if (!finishing) Finish(error); }
        };
        poll.Tick += Poll;
        FormClosing += delegate { if (!finishing) Finish(new OperationCanceledException("Application startup was cancelled.")); };
        ResumeLayout(false);
    }

    private void InitializeCard(bool legacy)
    {
        Card = StartupCard.Create(legacy);
        Card.View.Dock = DockStyle.Fill;
        Card.Ready = delegate {
            if (preview == null) StartRuntime();
            else {
                WriteLog("html-ready renderer=" + Card.Renderer);
                Card.View.BringToFront();
                preview.Image.Dispose(); preview.Dispose(); preview = null;
            }
        };
        Card.Cancel = () => Finish(new OperationCanceledException("Application startup was cancelled."));
        Card.Failed = Finish;
        Controls.Add(Card.View);
        if (preview != null) preview.BringToFront();
    }

    private async void LoadCard(bool legacy)
    {
        try { InitializeCard(legacy); await Card.LoadAsync(html, chinese, version); }
        catch (Exception error) { if (!finishing) Finish(error); }
    }

    protected override void OnLoad(EventArgs e)
    {
        using (var graphics = CreateGraphics())
            ClientSize = new Size((int)Math.Round(CanvasWidth * graphics.DpiX / 96.0),
                (int)Math.Round(CanvasHeight * graphics.DpiY / 96.0));
        CenterToScreen();
        if (previewClose != null)
        {
            float scale = ClientSize.Width / (float)CanvasWidth;
            previewClose.Bounds = new Rectangle((int)(756 * scale), 0, (int)(44 * scale), (int)(36 * scale));
        }
        base.OnLoad(e);
    }

    private void StartRuntime()
    {
        if (starting || finishing) return;
        starting = true;
        try
        {
            if (!previewPainted) WriteLog("card-painted renderer=" + Card.Renderer);
            start.EnvironmentVariables["KSSOLV_STARTUP_SIGNAL"] = signal;
            start.EnvironmentVariables["KSSOLV_STARTUP_NONCE"] = nonce;
            child = Process.Start(start);
            job = new KssolvLauncher.ProcessJob(child);
            WriteLog("runtime-started pid=" + child.Id);
            watch.Restart();
        }
        catch (Exception error) { Finish(error); }
    }

    private async void Poll(object sender, EventArgs e)
    {
        if (polling || finishing) return;
        polling = true;
        try
        {
            if (child == null)
            {
                if (watch.Elapsed.TotalSeconds > 15)
                    throw new TimeoutException("The local HTML startup card could not be rendered.");
                return;
            }
            if (child.HasExited)
                throw new InvalidOperationException("Application exited before its interface was ready (exit " + child.ExitCode + ").");
            if (watch.Elapsed.TotalSeconds > 900)
                throw new TimeoutException("Application startup exceeded 15 minutes. See " + log);
            if (File.Exists(signal))
            {
                Dictionary<string, object> data;
                try
                {
                    // Allow atomic replacement while the backend publishes handoff signals.
                    using (var stream = new FileStream(signal, FileMode.Open, FileAccess.Read,
                        FileShare.ReadWrite | FileShare.Delete))
                    using (var reader = new StreamReader(stream, Encoding.UTF8, true))
                        data = json.Deserialize<Dictionary<string, object>>(reader.ReadToEnd());
                }
                catch (IOException) { return; } // MATLAB atomically replaces this file.
                // Windows can briefly deny access while the publisher replaces
                // the destination; retry on the next poll just like a sharing violation.
                catch (UnauthorizedAccessException) { return; }
                object value;
                if (!data.TryGetValue("nonce", out value) || Convert.ToString(value) != nonce ||
                    !data.TryGetValue("protocol", out value) || Convert.ToInt32(value) != 1)
                    throw new InvalidDataException("Invalid application startup signal.");
                string state = data.TryGetValue("status", out value) ? Convert.ToString(value) : "";
                if (state == "failed")
                    throw new InvalidOperationException(data.TryGetValue("error", out value) ? Convert.ToString(value) : "Application startup failed.");
                if (state == "shell-ready" && !acknowledged)
                {
                    // Paint the final two presentation states before releasing
                    // the native shell. No fixed dwell or timer-plan replay.
                    if (Card == null || !Card.IsLoaded || !json.Deserialize<bool>(
                        await Card.EvaluateAsync("window.prepareStartupHandoff()"))) return;
                    if (finishing) return;
                    string presentation = json.Deserialize<string>(await Card.EvaluateAsync("JSON.stringify(window.getStartupPresentation())"));
                    if (finishing) return;
                    WriteLog("presentation " + presentation);
                    WriteLog("shell-ready");
                    string temp = signal + ".reveal.tmp";
                    File.WriteAllText(temp, json.Serialize(new { nonce = nonce }), new UTF8Encoding(false));
                    File.Move(temp, signal + ".reveal");
                    acknowledged = true;
                }
                else if (state == "visible")
                {
                    if (!acknowledged || child.HasExited)
                        throw new InvalidDataException("The application did not complete the startup handshake.");
                    WriteLog("window-visible");
                    job.Release(); // The Toolbox continues after its startup host exits.
                    succeeded = true;
                    Finish(null);
                    return;
                }
                else if (state != "shell-ready") throw new InvalidDataException("Unknown application startup state: " + state);
            }
        }
        catch (Exception error) { Finish(error); }
        finally { polling = false; }
    }

    private void WriteLog(string stage)
    {
        using(var stream=new FileStream(log,FileMode.Append,FileAccess.Write,FileShare.ReadWrite|FileShare.Delete))
        using(var writer=new StreamWriter(stream,new UTF8Encoding(false)))
            writer.WriteLine(DateTime.UtcNow.ToString("o") + " " + stage);
    }

    private void Finish(Exception error)
    {
        if (finishing) return;
        finishing = true;
        failure = error;
        poll.Stop();
        if (error != null) { try { WriteLog((error is OperationCanceledException ? "cancelled " : "failed ") + error.Message); } catch { } }
        try {
            if (job != null) { job.Dispose(); job = null; }
            Hide();
        } finally {
            // Diagnostics must never leave an invisible startup host running.
            try { WriteLog("card-closed"); } catch { }
            Close();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            poll.Dispose();
            if (job != null) job.Dispose();
            if (child != null) child.Dispose();
            if (Card != null) Card.Dispose();
            if (preview != null) { preview.Image.Dispose(); preview.Dispose(); }
        }
        base.Dispose(disposing);
    }
}

internal sealed class PreviewCloseButton : Button
{
    internal PreviewCloseButton() { TabStop = false; }
    internal bool DisplaysFocusCue { get { return ShowFocusCues; } }
    protected override bool ShowFocusCues { get { return false; } }
}
