# Install the actual compiled payload into a fresh build-cache directory and run
# the production Runtime/prewarm callbacks. This fixture creates no shortcuts or
# product registration and never invokes a previous installation's uninstaller.
param([switch]$InstallRuntime)
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$installer = Join-Path $repository 'scripts\windows\installer'
$cache = Join-Path $repository '.buildtool\standalone'
$stage = Join-Path $cache 'windows-stage'
$application = Join-Path $cache 'build\KSSOLV_Toolbox.exe'
$metadata = Get-Content -LiteralPath (Join-Path $cache 'build\runtime-metadata.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$compiler = $env:KSSOLV_ISCC
if (!$compiler) { $compiler = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe' }
$runtime = (Get-ItemProperty -LiteralPath ('HKLM:\SOFTWARE\MathWorks\MATLAB Runtime\' + $metadata.RuntimeVersion)).MATLABROOT
if (!(Test-Path -LiteralPath (Join-Path $runtime 'bin\win64\MATLABWindow.exe'))) { throw 'Install the matching MATLAB Runtime before running this integration test.' }
$payload = Get-ChildItem -LiteralPath $stage -Directory -Filter 'runtime-*' |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'RuntimeSetup.exe') } |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if (!$payload) { throw 'Run package_installer.ps1 before this integration test.' }
$payloadInfo = Get-Content -LiteralPath (Join-Path $payload.FullName 'payload.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$root = Join-Path $repository ('.buildtool\installer-payload-tests\' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$app = Join-Path $root 'app'
$source = Get-Content -LiteralPath (Join-Path $installer 'KSSOLV.iss') -Raw -Encoding UTF8
$source = [regex]::Replace($source, '(?m)^AppId=.*$', 'AppId=KSSOLVIsolatedPayloadFixture')
$source = [regex]::Replace($source, '(?m)^AppName=.*$', 'AppName=KSSOLV Isolated Payload Fixture')
if (!$InstallRuntime) { $source = [regex]::Replace($source, '(?m)^PrivilegesRequired=.*$', 'PrivilegesRequired=lowest') }
$source = [regex]::Replace($source, '(?m)^Uninstallable=.*$', "Uninstallable=no`r`nUsePreviousAppDir=no")
$source = [regex]::Replace($source, '(?s)\[Icons\].*?(?=\[Code\])', '')
$source = $source.Replace('#include "Upgrade.iss"', 'procedure TryRemovePreviousInstallations; begin end;')
$script = Join-Path $root 'payload-test.iss'
Set-Content -LiteralPath $script -Value $source -Encoding UTF8
foreach ($file in @('Design.iss', 'Diagnostics.iss', 'Remove-PreviousInstallation.ps1', 'matlabruntime_license_agreement.pdf')) {
    Copy-Item -LiteralPath (Join-Path $installer $file) -Destination $root
}
$hash = (Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash.ToLowerInvariant()
$defines = @("/DAppVersion=$($metadata.ApplicationVersion)", "/DRuntimeRelease=$($metadata.RuntimeRelease)",
    "/DRuntimeVersion=$($metadata.RuntimeVersion)", "/DBuildHash=$hash", "/DRuntimeDelivery=$($payloadInfo.RuntimeDelivery)",
    "/DRepository=$repository", "/DStage=$stage", "/DReleaseDirectory=$root", "/DApplication=$application",
    "/DRuntimeInstaller=$($payload.FullName)\RuntimeSetup.exe", "/DRuntimePayload=$($payload.FullName)",
    "/DRuntimeIsZip=$($payloadInfo.RuntimeIsZip)", '/DRuntimeEntryPoint=RuntimeSetup.exe', '/Fpayload-test', '/Qp')
$ErrorActionPreference = 'Continue'
& $compiler @defines $script *> (Join-Path $root 'compile.log')
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath (Join-Path $root 'compile.log'); throw 'Payload test compilation failed.' }
$setupLog = Join-Path $root 'setup.log'
$arguments = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ACCEPTRUNTIMELICENSE=yes /LANG=en /DIR="' + $app + '" /LOG="' + $setupLog + '"'
if ($InstallRuntime) { $arguments += ' /REUSERUNTIME=no /RUNTIMEFOLDER="' + (Split-Path -Parent $runtime) + '"' }
Write-Output "INSTALLER_PAYLOAD_TEST_ROOT $root"
$process = Start-Process -FilePath (Join-Path $root 'payload-test.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru
$watch = [Diagnostics.Stopwatch]::StartNew()
$observations = 0
$jvmFound = $false
while (!$process.WaitForExit(1000)) {
    # Match only this fixture's installed application, not any existing session.
    foreach ($child in Get-Process -Name KSSOLV_Toolbox -ErrorAction SilentlyContinue) {
        if ($child.Path -eq (Join-Path $app 'application\KSSOLV_Toolbox.exe')) {
            $observations++
            if (@($child.Modules | Where-Object ModuleName -eq 'jvm.dll').Count) { $jvmFound = $true }
        }
    }
    if ($watch.Elapsed.TotalMinutes -gt 20) { throw "Payload test timed out; inspect $setupLog" }
}
$logText = [IO.File]::ReadAllText($setupLog)
if ($process.ExitCode -ne 0 -or !$logText.Contains('KSSOLV_INSTALL_PREWARM_OK') -or
    $logText.Contains('KSSOLV_INSTALL_DIAGNOSTIC') -or $jvmFound) {
    Get-Content -LiteralPath $setupLog -Tail 30
    throw "Real payload installation failed (exit=$($process.ExitCode), JVM=$jvmFound): $root"
}
$status = Get-ChildItem -LiteralPath (Join-Path $app 'installation-state') -Filter 'prewarm-*.json' |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$result = Get-Content -LiteralPath $status.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
if ($result.status -ne 'success' -or $result.buildHash -ne $hash -or !$observations) { throw 'Missing verified real application readiness.' }
$report = [ordered]@{
    InstallerExitCode = $process.ExitCode; ApplicationVersion = $metadata.ApplicationVersion;
    ApplicationSHA256 = $hash; RuntimeRoot = $result.runtimeRoot;
    RuntimeBootstrapExecuted = [bool]$InstallRuntime; PrewarmStatus = $result.status;
    PrewarmSeconds = $result.elapsedSeconds; ApplicationProcessObservations = $observations;
    JVMObserved = $jvmFound; TestRoot = $root
}
$report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'result.json') -Encoding UTF8
$report | ConvertTo-Json
