using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Web.Script.Serialization;

// Observes the installed launcher, with an outer lifetime job for test cleanup.
class InstalledStartupAcceptance
{
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct ProcessEntry { public uint Size, Usage, Id; public IntPtr Heap; public uint Module, Threads, Parent; public int Priority; public uint Flags; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string Name; }
    [DllImport("kernel32.dll")] static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint id);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern bool Process32First(IntPtr snapshot, ref ProcessEntry entry);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern bool Process32Next(IntPtr snapshot, ref ProcessEntry entry);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    static bool Alive(int id) { try { using(var p=Process.GetProcessById(id))return !p.HasExited; } catch(ArgumentException){return false;} }
    static void Descendants(int root, HashSet<int> owned)
    {
        var links=new List<KeyValuePair<int,int>>();
        IntPtr snapshot=CreateToolhelp32Snapshot(2,0);
        if(snapshot==new IntPtr(-1))return;
        try { var entry=new ProcessEntry{Size=(uint)Marshal.SizeOf(typeof(ProcessEntry))};
            if(Process32First(snapshot,ref entry))do { links.Add(new KeyValuePair<int,int>((int)entry.Id,(int)entry.Parent)); }while(Process32Next(snapshot,ref entry));
        }finally{CloseHandle(snapshot);}
        owned.Add(root);
        bool changed;
        do {changed=false;foreach(var link in links)if(owned.Contains(link.Value)&&owned.Add(link.Key))changed=true;}while(changed);
    }
    static DateTime Time(string line) { return DateTime.Parse(line.Substring(0,line.IndexOf(' ')),null,System.Globalization.DateTimeStyles.RoundtripKind).ToUniversalTime(); }
    static string[] ReadLog(string file) {
        using(var input=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
        using(var reader=new StreamReader(input))return reader.ReadToEnd().Split(new[]{Environment.NewLine},StringSplitOptions.RemoveEmptyEntries);
    }
    static int Main(string[] args)
    {
        try
        {
            string executable=args[0], result=args[1], log=args[2], mode=args[3];
            bool cancel=mode=="cancel";
            var started=DateTime.UtcNow; var watch=Stopwatch.StartNew();
            int backend=0; var owned=new HashSet<int>(); string[] lines=new string[0];
            using(var process=Process.Start(new ProcessStartInfo(executable,args.Length>4?args[4]:""){UseShellExecute=false,WorkingDirectory=Path.GetDirectoryName(executable)}))
            using(var job=new KssolvLauncher.ProcessJob(process))
            {
                while(!process.WaitForExit(100))
                {
                    if(watch.Elapsed.TotalSeconds>180)throw new TimeoutException("Installed launch did not finish within 180 seconds.");
                    if(File.Exists(log)) {
                        string[] all=ReadLog(log);
                        int index=Array.FindLastIndex(all,line=>line.Contains(" launch-requested ") && Time(line)>=started.AddMilliseconds(-50));
                        if(index>=0)lines=all.Skip(index).ToArray();
                        string runtime=lines.FirstOrDefault(line=>line.Contains(" runtime-started pid="));
                        if(runtime!=null) {backend=int.Parse(runtime.Substring(runtime.IndexOf("pid=")+4));Descendants(backend,owned);}
                    }
                }
                if(File.Exists(log)) {
                    string[] all=ReadLog(log);
                    int index=Array.FindLastIndex(all,line=>line.Contains(" launch-requested ") && Time(line)>=started.AddMilliseconds(-50));
                    if(index>=0)lines=all.Skip(index).ToArray();
                }
                string paint=lines.FirstOrDefault(line=>line.Contains(" card-painted"));
                string visible=lines.FirstOrDefault(line=>line.Contains(" window-visible"));
                string closed=lines.FirstOrDefault(line=>line.Contains(" card-closed"));
                if(process.ExitCode!=0 || paint==null || closed==null || backend==0)throw new Exception("Installed launch failed or lacks lifecycle evidence.");
                DateTime? loadedAt=null;
                Dictionary<string,object> presentation=null;
                if(cancel) {
                    var cleanup=Stopwatch.StartNew();
                    while(owned.Any(Alive)&&cleanup.Elapsed.TotalSeconds<5)Thread.Sleep(50);
                    if(owned.Any(Alive)||!lines.Any(line=>line.Contains(" cancelled "))||visible!=null)throw new Exception("Cancel left a backend process alive or revealed Toolbox.");
                } else {
                    if(visible==null || !Alive(backend) || !lines.Any(line=>line.Contains(" shell-ready")))throw new Exception("Successful launch did not retain the visible Toolbox shell.");
                    string presentationLine=lines.FirstOrDefault(line=>line.Contains(" presentation "));
                    if(presentationLine==null)throw new Exception("Missing final presentation paint evidence.");
                    var serializer=new JavaScriptSerializer();
                    presentation=serializer.Deserialize<Dictionary<string,object>>(presentationLine.Substring(presentationLine.IndexOf(" presentation ")+14));
                    var history=serializer.ConvertToType<Dictionary<string,object>[]>(presentation["history"]);
                    if(!Convert.ToBoolean(presentation["handoffPainted"]) || history.Length<3 || Convert.ToInt32(history[history.Length-2]["stage"])!=24 || Convert.ToInt32(history[history.Length-1]["stage"])!=25)throw new Exception("Final states 24 and 25 were not painted before handoff.");
                    for(int i=1;i<history.Length;i++)if(Convert.ToInt32(history[i]["stage"])<=Convert.ToInt32(history[i-1]["stage"]))throw new Exception("Presentation looped or moved backwards.");
                    Console.WriteLine("HANDOFF_OBSERVED backend="+backend+"; observing continued loading for 25 seconds.");
                    // The early shell is allowed to be busy. Keep observing it
                    // while the rest of the real application finishes loading.
                    string request=lines.First(line=>line.Contains(" launch-requested "));
                    string launchNonce=request.Substring(request.IndexOf("nonce=")+6).Split(' ')[0];
                    string completion=Path.Combine(Path.GetDirectoryName(log),"startup-loaded.json");
                    var settle=Stopwatch.StartNew();
                    while(settle.Elapsed.TotalSeconds<25 || loadedAt==null) {
                        if(settle.Elapsed.TotalSeconds>90)throw new Exception("The visible Toolbox did not finish loading its interface.");
                        if(!Alive(backend))throw new Exception("Toolbox exited while loading after the early handoff.");
                        if(loadedAt==null && File.Exists(completion)) {
                            try {
                                using(var input=new FileStream(completion,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete))
                                using(var reader=new StreamReader(input)) {
                                    var state=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(reader.ReadToEnd());
                                    if(Convert.ToString(state["nonce"])==launchNonce && Convert.ToString(state["status"])=="loaded")
                                        loadedAt=DateTime.Parse(Convert.ToString(state["completedUtc"]),null,System.Globalization.DateTimeStyles.RoundtripKind).ToUniversalTime();
                                }
                            }catch(IOException){}catch(UnauthorizedAccessException){}
                        }
                        Descendants(backend,owned); Thread.Sleep(100);
                    }
                }
                var data=new {success=true,mode=mode,exitCode=process.ExitCode,backendPid=backend,descendantsChecked=owned.Count,
                    presentation=presentation,
                    backendRetained=!cancel&&Alive(backend),allBackendProcessesStopped=cancel&&!owned.Any(Alive),
                    locale=lines[0].Substring(lines[0].IndexOf("locale=")+7),
                    cardAppearedSeconds=(Time(paint)-started).TotalSeconds,
                    cardDurationSeconds=(Time(closed)-Time(paint)).TotalSeconds,
                    closeAfterVisibleMs=visible==null?(double?)null:(Time(closed)-Time(visible)).TotalMilliseconds,
                    appearanceReasonable=(Time(paint)-started).TotalSeconds<=1,
                    backendObservedAfterHandoffSeconds=cancel?0:25,
                    fullInterfaceLoaded=loadedAt!=null,
                    fullLoadAfterHandoffSeconds=loadedAt==null?(double?)null:(loadedAt.Value-Time(closed)).TotalSeconds,
                    lifetimeReasonable=cancel || (Time(closed)>=Time(visible)&&(Time(closed)-Time(visible)).TotalMilliseconds<=250),
                    events=lines};
                string json=new JavaScriptSerializer().Serialize(data);
                File.WriteAllText(result,json); Console.WriteLine(json);
                return 0; // The outer job closes only this test's retained Runtime/CEF processes.
            }
        }
        catch(Exception error){File.WriteAllText(args[1],new JavaScriptSerializer().Serialize(new{success=false,error=error.ToString()}));Console.Error.WriteLine(error);return 1;}
    }
}
