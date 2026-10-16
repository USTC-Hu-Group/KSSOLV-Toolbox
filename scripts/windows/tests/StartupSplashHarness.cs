using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

class SplashHarness
{
    [System.Runtime.InteropServices.DllImport("shcore.dll")]
    static extern int GetProcessDpiAwareness(IntPtr process, out int awareness);
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    const string MotionProbe = @"
      (function () {
        var p = window.__startupMotionProbe = {done:false}, bar = document.getElementById('progress').firstChild;
        var art = document.getElementById('crystal'), intervals = [], first = null, last, previous, updates = 0, samples = 0;
        function rect() { var r = art.getBoundingClientRect(); return [r.left,r.top,r.right,r.bottom].join(','); }
        var artStart = rect();
        function sample(time) {
          var transform = bar.style.transform;
          if (first === null) { first = time; } else { intervals.push(time-last); if (transform !== previous) { updates += 1; } }
          samples += 1; last = time; previous = transform;
          if (time-first < 1500) { window.requestAnimationFrame(sample); return; }
          var sorted = intervals.slice().sort(function(a,b){return a-b;});
          p.result = {samples:samples, updates:updates, elapsedMs:time-first,
            callbackFps:intervals.length*1000/(time-first), updateFps:updates*1000/(time-first),
            p95IntervalMs:sorted[Math.ceil(sorted.length*0.95)-1], maxIntervalMs:sorted[sorted.length-1],
            artStatic:artStart===rect() && getComputedStyle(art).transform==='none',
            transform:getComputedStyle(bar).transform};
          p.done = true;
        }
        window.requestAnimationFrame(sample);
      }());";

    const string Inspect = @"
      (function () {
        var byId=function(id){return document.getElementById(id);}, status=byId('status'), owner=byId('copyright-owner');
        var n=owner.getBoundingClientRect(), f=document.querySelector('.footer').getBoundingClientRect();
        var brand=document.querySelector('.brand'), images=brand.getElementsByTagName('img');
        var cancel=byId('cancel'); cancel.focus();
        var focusStyle=getComputedStyle(cancel), focusClear=focusStyle.outlineStyle==='none' && focusStyle.boxShadow==='none';
        cancel.blur();
        var presentation=window.getStartupPresentation(), messages=presentation.messages, clone=status.cloneNode(false), fits=true;
        clone.removeAttribute('id');clone.style.position='absolute';clone.style.left='-2000px';clone.style.width=status.clientWidth+'px';document.body.appendChild(clone);
        for(var i=0;i<messages.length;i++){clone.innerText=messages[i];if(clone.scrollWidth>clone.clientWidth)fits=false;}
        document.body.removeChild(clone);
        return JSON.stringify({status:status.innerText, phase:byId('phase').innerText,
          stage:status.getAttribute('data-stage'), messageMatches:status.innerText===messages[presentation.stage-1], allMessagesFit:fits && messages.length===25,
          focusClear:focusClear, statusFits:status.scrollHeight<=status.clientHeight,
          singleLine:status.clientHeight===20 && status.scrollWidth<=status.clientWidth && status.innerText.indexOf('\n')<0,
          details:!!byId('details-toggle'),
          version:byId('version-value').innerText, owner:owner.innerText, years:byId('copyright-years').innerText,
          copyrightFits:n.left>=f.left && n.right<=f.right+1 && n.bottom<=f.bottom+1,
          noClock:!byId('elapsed'), width:document.documentElement.clientWidth, height:document.documentElement.clientHeight,
          ratio:window.devicePixelRatio||1, phaseFont:getComputedStyle(byId('phase')).fontSize, statusFont:getComputedStyle(status).fontSize,
          brand:images.length===3 && !brand.innerText.replace(/\s/g,'') && images[0].src===images[1].src && images[1].src===images[2].src && images[0].naturalWidth===584,
          indeterminate:byId('progress').getAttribute('role')==='progressbar' && !byId('progress').getAttribute('aria-valuenow'),
          reduced:!!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) ||
            (!(window.kssolvStartup && window.kssolvStartup.renderer==='webview2') && window.external.GetReducedMotion())});
      }());";

    static async Task<Dictionary<string, object>> Read(StartupCard card, string expression)
    { return Json.Deserialize<Dictionary<string, object>>(Json.Deserialize<string>(await card.EvaluateAsync(expression))); }
    static bool Yes(Dictionary<string, object> data, string key) { return Convert.ToBoolean(data[key]); }
    static string Value(Dictionary<string, object> data, string key) { return Convert.ToString(data[key]); }

    [STAThread] static int Main(string[] args)
    {
        try
        {
            if (args[0]=="locale") return LocaleCases(args[1]);
            bool verified = false, probeStarted = false, inspecting = false;
            Exception inspectError = null;
            var start = new ProcessStartInfo(Path.Combine(Environment.CurrentDirectory, "FakeStartup.exe")) { UseShellExecute = false };
            using (var inspect = new Timer())
            using (var cancel = new Timer())
            {
                if (args[0].StartsWith("layout"))
                {
                    inspect.Interval = 100;
                    inspect.Tick += async delegate {
                        if (inspecting || Application.OpenForms.Count == 0) return;
                        var window = Application.OpenForms[0] as SplashWindow;
                        if (window == null || window.Card == null || !window.Card.IsLoaded) return;
                        inspecting = true;
                        try
                        {
                            if (!probeStarted) {
                                // Navigation can finish before the card's first
                                // animation frame, particularly in MSHTML.
                                if (!Json.Deserialize<bool>(await window.Card.EvaluateAsync("!!document.getElementById('progress').firstChild.style.transform"))) return;
                                await window.Card.EvaluateAsync(MotionProbe); probeStarted = true; return;
                            }
                            if (!Json.Deserialize<bool>(await window.Card.EvaluateAsync("window.__startupMotionProbe.done"))) return;
                            var data = await Read(window.Card, Inspect);
                            var animation = await Read(window.Card, "JSON.stringify(window.__startupMotionProbe.result)");
                            animation["renderer"] = window.Card.Renderer;
                            File.WriteAllText(args[1] + ".animation", Json.Serialize(animation));
                            int awareness; GetProcessDpiAwareness(IntPtr.Zero, out awareness);
                            data["awareness"] = awareness;
                            data["physicalWidth"] = window.ClientSize.Width; data["physicalHeight"] = window.ClientSize.Height;
                            File.WriteAllText(args[1] + ".layout", Json.Serialize(data));
                            bool chinese = args[0] == "layout-zh";
                            bool substate = !Yes(data,"details") && Value(data,"phase").Contains(chinese ? "\u6b63\u5728\u542f\u52a8 KSSOLV Toolbox" : "Starting KSSOLV Toolbox");
                            bool localized = Yes(data,"messageMatches") && Yes(data,"allMessagesFit");
                            bool copyright = Value(data,"owner") == (chinese ? "\u5408\u80a5\u701a\u6d77\u91cf\u5b50\u79d1\u6280\u6709\u9650\u516c\u53f8" : "Hefei Hanhai Quantum Technology Co., Ltd.") && Value(data,"years").EndsWith(DateTime.Now.Year.ToString());
                            bool layout = Math.Abs(Convert.ToInt32(data["width"])-800)<=2 && Math.Abs(Convert.ToInt32(data["height"])-494)<=2 && awareness==1 && Math.Abs(Convert.ToDouble(data["width"])/Convert.ToDouble(data["height"])-(1+Math.Sqrt(5))/2)<0.002;
                            bool motion = Yes(animation,"artStatic") && (Yes(data,"reduced") || (Convert.ToInt32(animation["updates"])>=Convert.ToInt32(animation["samples"])-2 && Value(animation,"transform")!="none" && Convert.ToDouble(animation["updateFps"])>=double.Parse(args[3], System.Globalization.CultureInfo.InvariantCulture)));
                            verified = substate && localized && copyright && layout && motion && Yes(data,"focusClear") && Yes(data,"singleLine") && Yes(data,"statusFits") && Yes(data,"copyrightFits") && Yes(data,"brand") && Yes(data,"indeterminate") && Yes(data,"noClock") && Value(data,"version")==args[2];
                            inspect.Stop();
                        }
                        catch (Exception error) { inspectError=error; inspect.Stop(); }
                        finally { inspecting=false; }
                    };
                    inspect.Start();
                }
                if (args[0].StartsWith("escape")) {
                    bool sent=false;
                    inspect.Interval=500;
                    inspect.Tick+=async delegate {
                        if(inspecting || Application.OpenForms.Count==0)return;
                        var window=Application.OpenForms[0] as SplashWindow;
                        if(window==null)return;
                        inspecting=true;
                        try {
                            if(sent) { if(window.Visible && !window.IsDisposed) { verified=true; inspect.Stop(); File.WriteAllText(args[1]+".escape","Escape ignored; startup continued."); } return; }
                            if(args[0]=="escape-preview") {
                                typeof(Form).GetMethod("OnKeyDown",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(window,new object[]{new KeyEventArgs(Keys.Escape)});
                            } else {
                                if(window.Card==null || !window.Card.IsLoaded)return;
                                await window.Card.EvaluateAsync("(function(){var e;if(document.createEvent){e=document.createEvent('Event');e.initEvent('keydown',true,true);e.keyCode=27;document.dispatchEvent(e);}else{e=document.createEventObject();e.keyCode=27;document.fireEvent('onkeydown',e);}return true;}())");
                            }
                            sent=true;
                        } catch(Exception error) { inspectError=error; inspect.Stop(); }
                        finally { inspecting=false; }
                    };
                    inspect.Start();
                }
                if (args[0].StartsWith("cancel")) {
                    cancel.Interval=args[0]=="cancel-preview"?500:1500;
                    cancel.Tick+=async delegate {
                        if(Application.OpenForms.Count==0) return;
                        var window=Application.OpenForms[0] as SplashWindow;
                        if(window==null) return;
                        if(args[0]=="cancel-preview") {
                            if(window.Card!=null && window.Card.IsLoaded)throw new Exception("Native cancellation must be tested before HTML is loaded.");
                            var picture=window.Controls[0] as PictureBox;
                            if(picture==null)throw new Exception("The native startup preview is missing.");
                            cancel.Stop();
                            foreach(Control control in picture.Controls)if(control is PreviewCloseButton){var close=(PreviewCloseButton)control;if(close.TabStop || close.DisplaysFocusCue)throw new Exception("Native close button displays the startup focus highlight.");close.PerformClick();return;}
                            throw new Exception("Native close button is missing.");
                        }
                        if(window.Card==null || !window.Card.IsLoaded) return;
                        cancel.Stop();
                        try { await window.Card.EvaluateAsync("document.getElementById('cancel').click(); true"); }
                        catch (Exception) { if(!window.IsDisposed && !window.Disposing) throw; }
                    };
                    cancel.Start();
                }
                SplashWindow.Run(start,Path.Combine(Environment.CurrentDirectory,"startup","index.html"),args[1]+".signal",Guid.NewGuid().ToString("N"),args[0]=="layout-zh" || args[0]=="preview-zh",args[1]+".log",args[2],args[0].Contains("legacy"));
            }
            if (inspectError!=null) throw inspectError;
            if (args[0].StartsWith("escape") && !verified) throw new Exception("Escape interrupted startup or was not exercised.");
            if (args[0].StartsWith("layout") && !verified) throw new Exception("Substate, original logo, static art, frame cadence, localization, copyright or DPI layout failed; inspect .layout/.animation.");
            File.WriteAllText(args[1],Json.Serialize(new {success=true})); return 0;
        }
        catch (Exception error) { File.WriteAllText(args[1],Json.Serialize(new {success=false,error=error.ToString()})); return 1; }
    }

    private static int LocaleCases(string root)
    {
        Directory.CreateDirectory(root);
        string file=Path.Combine(root,"startup.json");
        var rows=new List<object>();
        foreach (var entry in new[] {
            new[]{"{\"version\":1,\"locale\":\"zh_CN\"}","en_US","en-US","zh_CN"},
            new[]{"{\"version\":1,\"locale\":\"en_US\"}","zh_CN","zh-CN","en_US"},
            new[]{"{\"version\":1,\"locale\":\"unsupported\"}","zh_CN","zh-CN","en_US"},
            new[]{"broken","en_US","zh-CN","en_US"},
            new[]{"null","","zh-CN","zh_CN"},
            new[]{"{\"version\":\"bad\",\"locale\":\"zh_CN\"}","","en-US","en_US"},
            new[]{"{\"version\":2,\"locale\":\"zh_CN\"}","","en-US","en_US"}
        }) {
            File.WriteAllText(file,entry[0]);
            string actual=StartupLocale.Resolve(file,entry[1],entry[2]);
            if(actual!=entry[3]) throw new Exception("Locale precedence/fallback failed.");
            rows.Add(new {actual=actual,expected=entry[3]});
        }
        File.WriteAllText(Path.Combine(root,"results.json"),Json.Serialize(rows));
        return 0;
    }
}
