using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// Rendering is independent of the Runtime lifetime/nonce protocol in SplashWindow.
internal abstract class StartupCard : IDisposable
{
    internal const int CanvasWidth = 800, CanvasHeight = 494;
    internal bool IsLoaded;
    internal Action Ready, Cancel;
    internal Action<Exception> Failed;
    internal abstract Control View { get; }
    internal abstract string Renderer { get; }
    internal abstract Task LoadAsync(string page, bool chinese, string version);
    // Like ExecuteScriptAsync, results are JSON-encoded, including string results.
    internal abstract Task<string> EvaluateAsync(string script);
    public abstract void Dispose();

    internal static StartupCard Create(bool legacy)
    {
        if (!legacy)
        {
            try { CoreWebView2Environment.GetAvailableBrowserVersionString(); return new ModernStartupCard(); }
            catch (WebView2RuntimeNotFoundException) { }
        }
        // Older/offline Windows installations still start without downloading a browser.
        return new LegacyStartupCard();
    }
}

internal sealed class ModernStartupCard : StartupCard
{
    private readonly WebView2 browser = new WebView2();
    internal override Control View { get { return browser; } }
    internal override string Renderer { get { return "webview2"; } }
    internal override async Task LoadAsync(string page, bool chinese, string version)
    {
        string profile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "KSSOLV Toolbox", "StartupWebView2");
        var environment = await CoreWebView2Environment.CreateAsync(null, profile);
        await browser.EnsureCoreWebView2Async(environment);
        var core = browser.CoreWebView2;
        core.Settings.AreDefaultContextMenusEnabled = false;
        core.Settings.AreDevToolsEnabled = false;
        core.Settings.AreBrowserAcceleratorKeysEnabled = false;
        core.Settings.AreDefaultScriptDialogsEnabled = false;
        core.Settings.IsStatusBarEnabled = false;
        core.Settings.IsZoomControlEnabled = false;
        core.Settings.IsPinchZoomEnabled = false;
        string uri = new Uri(page).AbsoluteUri;
        core.NavigationStarting += delegate(object sender, CoreWebView2NavigationStartingEventArgs e) {
            e.Cancel = !string.Equals(e.Uri, uri, StringComparison.OrdinalIgnoreCase);
        };
        core.NewWindowRequested += delegate(object sender, CoreWebView2NewWindowRequestedEventArgs e) { e.Handled = true; };
        core.DownloadStarting += delegate(object sender, CoreWebView2DownloadStartingEventArgs e) { e.Cancel = true; };
        core.WebMessageReceived += delegate(object sender, CoreWebView2WebMessageReceivedEventArgs e) {
            if (!string.Equals(e.Source, uri, StringComparison.OrdinalIgnoreCase)) return;
            string message = e.TryGetWebMessageAsString();
            if (message == "cardReady" && Ready != null) Ready();
            else if (message == "cancel" && Cancel != null) Cancel();
        };
        core.ProcessFailed += delegate { if (Failed != null) Failed(new InvalidOperationException("The startup card renderer stopped.")); };
        core.NavigationCompleted += delegate(object sender, CoreWebView2NavigationCompletedEventArgs e) {
            IsLoaded = e.IsSuccess;
            if (!e.IsSuccess && Failed != null) Failed(new InvalidOperationException("The local startup card could not be loaded: " + e.WebErrorStatus));
        };
        string metadata = new JavaScriptSerializer().Serialize(new { language = chinese ? "zh" : "en", version = version, renderer = Renderer });
        await core.AddScriptToExecuteOnDocumentCreatedAsync("window.kssolvStartup=" + metadata + ";");
        core.Navigate(uri);
    }
    internal override Task<string> EvaluateAsync(string script) { return browser.ExecuteScriptAsync(script); }
    public override void Dispose() { browser.Dispose(); }
}

internal sealed class LegacyStartupCard : StartupCard
{
    private readonly WebBrowser browser = new WebBrowser();
    private readonly JavaScriptSerializer json = new JavaScriptSerializer();
    private bool chinese;
    private string version;
    internal override Control View { get { return browser; } }
    internal override string Renderer { get { return "mshtml"; } }
    internal override Task LoadAsync(string page, bool useChinese, string appVersion)
    {
        chinese = useChinese; version = appVersion;
        browser.IsWebBrowserContextMenuEnabled = false;
        browser.WebBrowserShortcutsEnabled = false;
        browser.AllowWebBrowserDrop = false;
        browser.ScriptErrorsSuppressed = true;
        browser.ObjectForScripting = new StartupCardBridge(chinese, version, ReducedMotion,
            () => browser.BeginInvoke((Action)(() => { if (Ready != null) Ready(); })),
            () => browser.BeginInvoke((Action)(() => { if (Cancel != null) Cancel(); })));
        browser.Navigating += delegate(object sender, WebBrowserNavigatingEventArgs e) {
            e.Cancel = !e.Url.IsFile || !string.Equals(Path.GetFullPath(e.Url.LocalPath), page, StringComparison.OrdinalIgnoreCase);
        };
        browser.NewWindow += delegate(object sender, System.ComponentModel.CancelEventArgs e) { e.Cancel = true; };
        browser.DocumentCompleted += delegate {
            try
            {
                using (var graphics = browser.CreateGraphics())
                {
                    var target = (OleCommandTarget)browser.Document.DomDocument;
                    int zoom = (int)Math.Round(graphics.DpiX / 96.0 * 100);
                    object output, input = zoom - 1;
                    Marshal.ThrowExceptionForHR(target.Exec(IntPtr.Zero, 63, 2, ref input, out output));
                    input = zoom;
                    Marshal.ThrowExceptionForHR(target.Exec(IntPtr.Zero, 63, 2, ref input, out output));
                    int width = browser.Document.GetElementsByTagName("html")[0].ClientRectangle.Width;
                    if (width <= 0) throw new InvalidOperationException("The startup card has no layout viewport.");
                    if (Math.Abs(width - 800) > 1)
                    {
                        input = (int)Math.Round(zoom * width / 800.0);
                        Marshal.ThrowExceptionForHR(target.Exec(IntPtr.Zero, 63, 2, ref input, out output));
                    }
                }
                IsLoaded = true;
            }
            catch (Exception error) { if (Failed != null) Failed(error); }
        };
        browser.Navigate(new Uri(page));
        return Task.FromResult(0);
    }
    internal override Task<string> EvaluateAsync(string script)
    { return Task.FromResult(json.Serialize(browser.Document.InvokeScript("eval", new object[] { script }))); }
    public override void Dispose() { browser.ObjectForScripting = null; browser.Dispose(); }

    [ComImport, Guid("B722BCCB-4E68-101B-A2BC-00AA00404770"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface OleCommandTarget
    {
        [PreserveSig] int QueryStatus(IntPtr group, uint count, IntPtr commands, IntPtr text);
        [PreserveSig] int Exec(IntPtr group, uint command, uint options, ref object input, out object output);
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SystemParametersInfo(uint action, uint parameter,
        [MarshalAs(UnmanagedType.Bool)] out bool value, uint flags);

    private static bool ReducedMotion() { bool enabled; return SystemParametersInfo(0x1042, 0, out enabled, 0) && !enabled; }
}

[ComVisible(true), ClassInterface(ClassInterfaceType.AutoDispatch)]
public sealed class StartupCardBridge
{
    private readonly bool chinese;
    private readonly string version;
    private readonly Func<bool> reduced;
    private readonly Action ready, cancel;
    internal StartupCardBridge(bool chinese, string version, Func<bool> reduced, Action ready, Action cancel)
    { this.chinese=chinese; this.version=version; this.reduced=reduced; this.ready=ready; this.cancel=cancel; }
    public string GetLanguage() { return chinese ? "zh" : "en"; }
    public string GetVersion() { return version; }
    public bool GetReducedMotion() { return reduced(); }
    public void CardReady() { ready(); }
    public void Cancel() { cancel(); }
}

internal static class StartupLocale
{
    internal static string FilePath
    { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "KSSOLV Toolbox", "startup.json"); } }
    internal static string Resolve(string file, string environmentLocale, string systemLocale)
    {
        try
        {
            using (var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (var reader = new StreamReader(stream))
            {
                var data = new JavaScriptSerializer().Deserialize<System.Collections.Generic.Dictionary<string,object>>(reader.ReadToEnd());
                object version, locale;
                if (data != null && data.TryGetValue("version", out version) && Convert.ToInt32(version)==1 && data.TryGetValue("locale", out locale))
                    return Normalize(Convert.ToString(locale));
            }
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        catch (ArgumentException) { }
        catch (InvalidOperationException) { }
        catch (FormatException) { }
        catch (OverflowException) { }
        if (!string.IsNullOrWhiteSpace(environmentLocale)) return Normalize(environmentLocale);
        return Normalize(systemLocale.Replace('-', '_'));
    }
    private static string Normalize(string value) { return value != null && value.Trim()=="zh_CN" ? "zh_CN" : "en_US"; }
}
