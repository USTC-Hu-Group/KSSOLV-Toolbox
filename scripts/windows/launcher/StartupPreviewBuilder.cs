using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// Build-time rasterization of the shared HTML. No duplicated layout, brand text,
// artwork or version constants are maintained by the native first-paint path.
internal static class StartupPreviewBuilder
{
    [STAThread] static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        try {
            string folder = Path.GetFullPath(args[0]), version = args[1];
            foreach (bool chinese in new[] { false, true }) {
                Exception failure = null;
                bool captured = false;
                using (var card = new ModernStartupCard())
                using (var form = new Form { FormBorderStyle=FormBorderStyle.None, ShowInTaskbar=false, StartPosition=FormStartPosition.Manual, Location=new Point(-4000,-4000), AutoScaleMode=AutoScaleMode.None })
                using (var timeout = new Timer { Interval=15000 }) {
                    using(var graphics=form.CreateGraphics())
                        form.ClientSize=new Size((int)(StartupCard.CanvasWidth*graphics.DpiX/96), (int)(StartupCard.CanvasHeight*graphics.DpiY/96));
                    card.View.Dock=DockStyle.Fill; form.Controls.Add(card.View);
                    Action<Exception> fail = error => { failure=error; form.Close(); };
                    card.Failed=fail;
                    card.Cancel=() => fail(new OperationCanceledException("Preview capture was cancelled."));
                    timeout.Tick+=delegate { fail(new TimeoutException("Startup preview renderer timed out.")); };
                    card.Ready=async delegate {
                        try {
                            // Native first paint supplies a live close button at this position.
                            await card.EvaluateAsync("document.getElementById('cancel').style.visibility='hidden'; document.getElementById('progress').firstChild.style.transform='translate3d(0,0,0)'; window.matchMedia = function(){return {matches:true};};");
                            var view=(WebView2)card.View;
                            using(var file=File.Create(Path.Combine(folder,chinese?"initial-zh.png":"initial-en.png")))
                                await view.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png,file);
                            captured=true; form.Close();
                        } catch(Exception error) { fail(error); }
                    };
                    form.Shown+=async delegate {
                        timeout.Start();
                        try { await card.LoadAsync(Path.Combine(folder,"index.html"),chinese,version); }
                        catch(Exception error) { fail(error); }
                    };
                    Application.Run(form);
                }
                if(failure!=null)throw failure;
                if(!captured)throw new Exception("Startup preview was not captured.");
            }
            File.WriteAllText(Path.Combine(folder,"initial-version.txt"),version);
            Console.WriteLine("STARTUP_PREVIEWS_SUCCESS " + folder);
            return 0;
        } catch(Exception error) { Console.Error.WriteLine(error); return 1; }
    }
}
