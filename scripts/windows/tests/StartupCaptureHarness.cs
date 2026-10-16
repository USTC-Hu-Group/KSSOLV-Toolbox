using System;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// Test-only wrapper around the unchanged launcher entry point. Captures pixels
// directly from its real WebView2 renderer while the real compiled Toolbox loads.
class StartupCaptureHarness
{
    const string CaptureMetadata = @"
      (function(){
        var status=document.getElementById('status'), row=document.querySelector('.bottom-row');
        function baseline(selector){
          var host=document.querySelector(selector), marker=document.createElement('span');
          marker.style.cssText='display:inline-block;width:0;height:0;padding:0;margin:0;vertical-align:baseline';
          host.appendChild(marker); var value=marker.getBoundingClientRect().top; host.removeChild(marker); return value;
        }
        return JSON.stringify({locale:document.documentElement.lang,stage:status.getAttribute('data-stage'),status:status.innerText,
          version:document.getElementById('version-value').innerText,
          width:innerWidth,height:innerHeight,ratio:devicePixelRatio,closeOutline:getComputedStyle(document.getElementById('cancel')).outlineStyle,
          copyrightBaseline:baseline('.footer'),captionBaseline:baseline('.art-caption'),bottomInset:innerHeight-row.getBoundingClientRect().bottom});
      }());";
    [STAThread] static int Main(string[] args)
    {
        bool capturing=false, captured=false;
        Exception failure=null;
        using(var timer=new Timer{Interval=100})
        {
            timer.Tick+=async delegate {
                if(capturing || captured || Application.OpenForms.Count==0)return;
                var window=Application.OpenForms[0] as SplashWindow;
                if(window==null || window.Card==null || !window.Card.IsLoaded)return;
                capturing=true;
                try {
                    var json=new System.Web.Script.Serialization.JavaScriptSerializer();
                    string stage=json.Deserialize<string>(await window.Card.EvaluateAsync("document.getElementById('status').getAttribute('data-stage')"));
                    if(string.IsNullOrEmpty(stage) || int.Parse(stage)<2)return;
                    var view=window.Card.View as WebView2;
                    if(view==null)throw new Exception("HD capture requires WebView2.");
                    using(var file=File.Create(args[0]))await view.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png,file);
                    string metadata=await window.Card.EvaluateAsync(CaptureMetadata);
                    File.WriteAllText(args[0]+".json",json.Deserialize<string>(metadata));
                    captured=true; timer.Stop();
                }catch(Exception error){failure=error;timer.Stop();}finally{capturing=false;}
            };
            timer.Start();
            int result=(int)typeof(KssolvLauncher).GetMethod("Main",BindingFlags.NonPublic|BindingFlags.Static).Invoke(null,new object[]{new string[0]});
            if(failure!=null)throw failure;
            if(!captured)throw new Exception("The real startup did not reach the capture stage.");
            return result;
        }
    }
}
