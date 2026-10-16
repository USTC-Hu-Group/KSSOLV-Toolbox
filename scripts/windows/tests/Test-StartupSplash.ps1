# Exercise the actual local HTML host and its process/nonce handoff without MATLAB.
param([double]$MinimumAnimationFps = 0)
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$versionMatch = [regex]::Match([IO.File]::ReadAllText("$repository\KSSOLV_Toolbox.m"), '(?m)^\s*Version\s+string\s*=\s*[''"](?<version>\d+(?:\.\d+){1,3})[''"]')
if (!$versionMatch.Success) { throw 'Missing project version.' }
$projectVersion = $versionMatch.Groups['version'].Value
$root = Join-Path $repository ('.buildtool\startup-host-tests\' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$root\startup" -Force | Out-Null
Copy-Item -LiteralPath "$repository\scripts\startup\index.html" -Destination "$root\startup\index.html"
Copy-Item -LiteralPath "$repository\+kssolv\+ui\resources\icons\companyLOGO.png" -Destination "$root\startup\company-logo.png"
Copy-Item -LiteralPath "$repository\scripts\startup\quantum-materials.png" -Destination "$root\startup\quantum-materials.png"
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$fakeSource = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Web.Script.Serialization;
class FakeStartup {
  static JavaScriptSerializer json = new JavaScriptSerializer();
  static void Publish(string file, object data) {
    File.WriteAllText(file+".tmp",json.Serialize(data));
    if(File.Exists(file)) File.Delete(file); File.Move(file+".tmp",file);
  }
  static int Main(string[] args) {
    if(args.Length>0 && args[0]=="--child") { Thread.Sleep(60000); return 0; }
    string mode=File.ReadAllText("mode.txt");
    File.WriteAllText("runtime.pid",Process.GetCurrentProcess().Id.ToString());
    Thread.Sleep(150); // The host attaches its job before any descendants exist.
    if(mode=="no-ready") return 0;
    var child=Process.Start(new ProcessStartInfo(Process.GetCurrentProcess().MainModule.FileName,"--child"){UseShellExecute=false});
    File.WriteAllText("child.pid",child.Id.ToString());
    string signal=Environment.GetEnvironmentVariable("KSSOLV_STARTUP_SIGNAL");
    string nonce=Environment.GetEnvironmentVariable("KSSOLV_STARTUP_NONCE");
    if(mode=="cancel" || mode=="cancel-preview") {Thread.Sleep(60000);return 0;}
    if(mode.StartsWith("escape")) {Thread.Sleep(4000);mode="ready";}
    if(mode=="presentation-long") {Thread.Sleep(32000);mode="ready";}
    if(mode.StartsWith("layout")) {
      Thread.Sleep(3000); // Allow layout inspection and frame sampling.
      mode="ready";
    }
    Publish(signal,new {protocol=1,status=mode=="early-visible"?"visible":mode=="failed"?"failed":"shell-ready",nonce=mode=="bad-nonce"?"stale":nonce,error="deliberate failure"});
    if(mode!="ready" && !mode.StartsWith("preview-")) {Thread.Sleep(60000);return 0;}
    for(int i=0;!File.Exists(signal+".reveal") && i<150;i++) Thread.Sleep(100);
    if(!File.Exists(signal+".reveal")) return 8;
    var ack=json.Deserialize<System.Collections.Generic.Dictionary<string,object>>(File.ReadAllText(signal+".reveal"));
    if(Convert.ToString(ack["nonce"])!=nonce)return 9;
    File.WriteAllText("acknowledged.txt",nonce);
    Publish(signal,new {protocol=1,status="visible",nonce=nonce});
    Thread.Sleep(60000); return 0;
  }
}
'@
$harnessSource = [IO.File]::ReadAllText("$PSScriptRoot\StartupSplashHarness.cs")
[IO.File]::WriteAllText("$root\FakeStartup.cs", $fakeSource)
[IO.File]::WriteAllText("$root\SplashHarness.cs", $harnessSource)
& $csc /nologo /target:winexe /reference:System.Web.Extensions.dll "/out:$root\FakeStartup.exe" "$root\FakeStartup.cs"
if ($LASTEXITCODE -ne 0) { throw 'Fake startup compilation failed.' }
. "$PSScriptRoot\..\launcher\StartupDependencies.ps1"
$webViewReferences = Initialize-StartupHostDependencies $root
New-Item -ItemType Directory -Path "$root\previews" -Force | Out-Null
Copy-Item -Path "$root\startup\*" -Destination "$root\previews"
& $csc /nologo /target:exe /platform:x64 /main:StartupPreviewBuilder /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll @webViewReferences "/win32manifest:$PSScriptRoot\..\launcher\KssolvLauncher.manifest" "/out:$root\StartupPreviewBuilder.exe" "$PSScriptRoot\..\launcher\StartupPreviewBuilder.cs" "$PSScriptRoot\..\launcher\StartupCard.cs"
if ($LASTEXITCODE -ne 0) { throw 'Preview builder compilation failed.' }
& "$root\StartupPreviewBuilder.exe" "$root\previews" $projectVersion
if ($LASTEXITCODE -ne 0) { throw 'Preview generation failed.' }
& $csc /nologo /target:winexe /platform:x64 /main:SplashHarness /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll @webViewReferences "/win32manifest:$PSScriptRoot\..\launcher\KssolvLauncher.manifest" "/out:$root\SplashHarness.exe" "$root\SplashHarness.cs" "$PSScriptRoot\..\launcher\KssolvLauncher.cs" "$PSScriptRoot\..\launcher\SplashWindow.cs" "$PSScriptRoot\..\launcher\StartupCard.cs"
if ($LASTEXITCODE -ne 0) { throw 'HTML host harness compilation failed.' }
$localeProcess = Start-Process -FilePath "$root\SplashHarness.exe" -ArgumentList 'locale',"$root\locale-fixtures" -WorkingDirectory $root -PassThru
if (!$localeProcess.WaitForExit(15000) -or $localeProcess.ExitCode -ne 0) { throw 'Locale configuration tests failed.' }
$cases = @()
foreach ($mode in 'ready', 'layout-en', 'layout-zh', 'layout-version', 'no-ready', 'failed', 'bad-nonce', 'early-visible', 'cancel', 'legacy-ready', 'layout-legacy', 'cancel-legacy', 'preview-en', 'preview-zh', 'cancel-preview', 'layout-preview', 'layout-preview-version', 'escape-preview', 'escape-webview', 'escape-legacy', 'presentation-long') {
    if ($mode.Contains('preview')) {
        Copy-Item -Path "$root\previews\initial-*" -Destination "$root\startup"
    } else {
        Get-ChildItem -LiteralPath "$root\startup" -Filter 'initial-*' | Remove-Item
    }
    [IO.File]::WriteAllText("$root\mode.txt", $(if ($mode -eq 'legacy-ready') { 'ready' } elseif ($mode -eq 'cancel-legacy') { 'cancel' } else { $mode }))
    foreach ($name in 'child.pid','runtime.pid','acknowledged.txt') {
        if (Test-Path -LiteralPath "$root\$name") { Remove-Item -LiteralPath "$root\$name" }
    }
    $result = "$root\$mode.json"
    $displayVersion = if ($mode.EndsWith('-version')) { '99.12.34' } else { $projectVersion }
    $minimumFps = if ($mode.Contains('legacy')) { '0' } else { $MinimumAnimationFps.ToString([Globalization.CultureInfo]::InvariantCulture) }
    $process = Start-Process -FilePath "$root\SplashHarness.exe" -ArgumentList $mode,"`"$result`"",$displayVersion,$minimumFps -WorkingDirectory $root -WindowStyle Normal -PassThru
    $caseTimeout = if ($mode -eq 'presentation-long') { 45000 } else { 25000 }
    if (!$process.WaitForExit($caseTimeout)) { Stop-Process -Id $process.Id -Force; throw "HTML host did not finish: $mode" }
    $data = Get-Content -LiteralPath $result -Raw | ConvertFrom-Json
    $expectedSuccess = $mode -eq 'ready' -or $mode -eq 'legacy-ready' -or $mode.StartsWith('preview-') -or $mode.StartsWith('layout') -or $mode.StartsWith('escape') -or $mode -eq 'presentation-long'
    if ($data.success -ne $expectedSuccess -or (($process.ExitCode -eq 0) -ne $data.success)) {
        Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force
        throw "Incorrect startup result: $mode $($data | ConvertTo-Json -Compress)"
    }
    Start-Sleep -Milliseconds 150
    foreach ($pidFile in 'runtime.pid','child.pid') {
        if (Test-Path -LiteralPath "$root\$pidFile") {
            $ownedId = [int](Get-Content -LiteralPath "$root\$pidFile")
            $owned = Get-Process -Id $ownedId -ErrorAction SilentlyContinue
            if ($expectedSuccess) {
                if (!$owned -or !(Test-Path -LiteralPath "$root\acknowledged.txt")) { throw 'Successful handoff killed Runtime or skipped the acknowledgement.' }
                Stop-Process -Id $ownedId -Force
            } elseif ($owned) { Stop-Process -Id $ownedId -Force; throw "Failed startup left a descendant alive: $mode" }
        }
    }
    if ($expectedSuccess) {
        $allLines = Get-Content -LiteralPath "$result.log"
        $lines = @($allLines | Where-Object { $_ -notmatch ' html-ready | presentation ' })
        $presentationLine = @($allLines | Where-Object { $_ -match ' presentation ' })
        if ($presentationLine.Count -ne 1) { throw 'Missing presentation paint evidence.' }
        $presentation = ($presentationLine[0] -split ' presentation ',2)[1] | ConvertFrom-Json
        $stages = @($presentation.history | ForEach-Object { [int]$_.stage })
        if (!$presentation.handoffPainted -or $presentation.messages.Count -ne 25 -or $stages[-2] -ne 24 -or $stages[-1] -ne 25) { throw 'Final states 24 and 25 were not painted before handoff.' }
        for ($index=1;$index -lt $stages.Count;$index++) { if ($stages[$index] -le $stages[$index-1]) { throw 'Presentation looped or moved backwards.' } }
        $durationSum = ($presentation.durationsMs | Measure-Object -Sum).Sum
        if ($presentation.durationsMs.Count -ne 23 -or $durationSum -lt 23980 -or $durationSum -gt 27020) { throw 'Randomized presentation budget is outside its bounds.' }
        if ($mode -eq 'presentation-long' -and ($stages -join ',') -ne ((1..25) -join ',')) { throw 'A full-length presentation skipped a state.' }
        if ($mode -eq 'ready' -and $stages.Count -gt 3) { throw 'Fast startup waited for the estimated presentation.' }
        if (($lines.Count -ne 5) -or !($lines[0].Contains('card-painted')) -or !($lines[3].Contains('window-visible')) -or !($lines[4].Contains('card-closed'))) { throw 'Unexpected HTML/startup event ordering.' }
        if ($mode -eq 'layout-preview-version' -and !($lines[0].Contains('renderer=webview2'))) { throw 'A stale preview version was displayed.' }
    }
    $cases += [pscustomobject]@{mode=$mode;success=$data.success;error=$data.error}
}
$cases | ConvertTo-Json | Set-Content -LiteralPath "$root\results.json" -Encoding UTF8
$cases | Format-Table
Write-Output "STARTUP_HTML_HOST_TESTS_SUCCESS $root\results.json"
