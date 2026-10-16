# Meaningful protocol tests, without launching MATLAB or changing Runtime registration.
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$testRoot = Join-Path $repository ('.buildtool\windows-launcher-tests\' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$testRoot\application", "$testRoot\runtime\runtime\win64" -Force | Out-Null
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$fakeSource = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Web.Script.Serialization;
class FakeApplication {
    static int Main(string[] args) {
        if (args.Length > 0 && args[0] == "--child") { Thread.Sleep(60000); return 0; }
        Thread.Sleep(350); // Allow the launcher to attach its lifetime job.
        string mode = File.ReadAllText("mode.txt");
        if (mode == "exit-error") return 7;
        if (mode == "no-ready") return 0;
        if (mode == "descendant") {
            var child = Process.Start(new ProcessStartInfo(Process.GetCurrentProcess().MainModule.FileName, "--child") { UseShellExecute=false });
            File.WriteAllText("child.pid", child.Id.ToString());
        }
        string nonce = Environment.GetEnvironmentVariable("KSSOLV_PREWARM_NONCE");
        File.WriteAllText(Environment.GetEnvironmentVariable("KSSOLV_PREWARM_RESULT"),
            new JavaScriptSerializer().Serialize(new {status="ready", nonce=mode == "bad-nonce" ? "stale" : nonce}));
        return 0;
    }
}
'@
[IO.File]::WriteAllText("$testRoot\FakeApplication.cs", $fakeSource)
& $csc /nologo /target:winexe /reference:System.Web.Extensions.dll "/out:$testRoot\application\KSSOLV_Toolbox.exe" "$testRoot\FakeApplication.cs"
if ($LASTEXITCODE -ne 0) { throw 'Fake app compilation failed.' }
. "$PSScriptRoot\..\launcher\StartupDependencies.ps1"
$webViewReferences = Initialize-StartupHostDependencies $testRoot
& $csc /nologo /target:winexe /platform:x64 /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll @webViewReferences "/win32manifest:$PSScriptRoot\..\launcher\KssolvLauncher.manifest" "/out:$testRoot\KssolvLauncher.exe" "$PSScriptRoot\..\launcher\KssolvLauncher.cs" "$PSScriptRoot\..\launcher\SplashWindow.cs" "$PSScriptRoot\..\launcher\StartupCard.cs"
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
New-Item -ItemType File -Path "$testRoot\runtime\runtime\win64\mclmcrrt26_2.dll" | Out-Null
$hash = (Get-FileHash "$testRoot\application\KSSOLV_Toolbox.exe").Hash.ToLowerInvariant()
@("RuntimeRoot=$testRoot\runtime", 'RuntimeRelease=R2026b', 'RuntimeVersion=26.2', 'Version=test', "BuildHash=$hash") |
    Set-Content -LiteralPath "$testRoot\launcher.ini" -Encoding UTF8
$pathBefore = $env:PATH
$cacheBefore = $env:MCR_CACHE_ROOT
$cases = @()
foreach ($mode in 'ready', 'exit-error', 'no-ready', 'bad-nonce', 'descendant') {
    [IO.File]::WriteAllText("$testRoot\mode.txt", $mode)
    $status = "$testRoot\$mode.json"
    $process = Start-Process -FilePath "$testRoot\KssolvLauncher.exe" -ArgumentList '--prewarm', '--result', "`"$status`"" -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru -Wait
    $data = Get-Content -Raw -LiteralPath $status | ConvertFrom-Json
    $expectedSuccess = $mode -in 'ready', 'descendant'
    if (($process.ExitCode -eq 0) -ne $expectedSuccess -or ($data.status -eq 'success') -ne $expectedSuccess) {
        throw "Incorrect readiness/exit result for $mode`: $($data | ConvertTo-Json -Compress)"
    }
    if ($expectedSuccess) {
        if ($data.buildHash -ne $hash -or $data.userSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) { throw 'Wrong marker identity.' }
        if (!(Test-Path -LiteralPath (Join-Path $data.cacheRoot 'prewarm-success.json'))) { throw 'Missing persisted marker.' }
    }
    if ($mode -eq 'descendant') {
        $childId = [int](Get-Content -LiteralPath "$testRoot\child.pid")
        Start-Sleep -Milliseconds 300
        if (Get-Process -Id $childId -ErrorAction SilentlyContinue) { throw 'Runtime descendant survived job closure.' }
    }
    $cases += [pscustomobject]@{case=$mode; exitCode=$process.ExitCode; status=$data.status}
}
if ($env:PATH -ne $pathBefore -or $env:MCR_CACHE_ROOT -ne $cacheBefore) { throw 'Launcher changed parent environment.' }
$cases | ConvertTo-Json | Set-Content -LiteralPath "$testRoot\results.json" -Encoding UTF8
$cases | Format-Table
Write-Output "WINDOWS_LAUNCHER_TESTS_SUCCESS $testRoot\results.json"
