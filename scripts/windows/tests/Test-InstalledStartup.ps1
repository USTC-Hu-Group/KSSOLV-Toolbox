[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationRoot,
    [ValidateRange(1,10)][int]$Runs = 3,
    [ValidateSet('current','zh_CN','en_US')][string]$Locale = 'current',
    [switch]$Capture,
    [switch]$ManualCancel
)
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$ApplicationRoot = [IO.Path]::GetFullPath($ApplicationRoot)
if (!(Test-Path -LiteralPath "$ApplicationRoot\KssolvLauncher.exe")) { throw 'The final installed launcher is required.' }
$root = Join-Path $repository ('.buildtool\installed-startup-tests\' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
. "$PSScriptRoot\..\launcher\StartupDependencies.ps1"
$references = Initialize-StartupHostDependencies $root
$sources = @("$PSScriptRoot\..\launcher\KssolvLauncher.cs", "$PSScriptRoot\..\launcher\SplashWindow.cs", "$PSScriptRoot\..\launcher\StartupCard.cs")
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:exe /platform:x64 /main:InstalledStartupAcceptance /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll @references "/out:$root\Acceptance.exe" "$PSScriptRoot\InstalledStartupAcceptance.cs" @sources
if ($LASTEXITCODE -ne 0) { throw 'Installed startup observer compilation failed.' }
$captureExe = Join-Path $ApplicationRoot ('.StartupCapture-' + [Guid]::NewGuid().ToString('N') + '.exe')
$localeFile = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'KSSOLV Toolbox\startup.json'
$hadLocale = Test-Path -LiteralPath $localeFile
$originalLocale = if ($hadLocale) { [IO.File]::ReadAllBytes($localeFile) } else { $null }
$originalTime = if ($hadLocale) { [IO.File]::GetLastWriteTimeUtc($localeFile) } else { $null }
$config = @{}
foreach ($line in [IO.File]::ReadAllLines("$ApplicationRoot\launcher.ini")) {
    $separator = $line.IndexOf('=')
    if ($separator -gt 0) { $config[$line.Substring(0,$separator)] = $line.Substring($separator+1) }
}
$log = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "KSSOLV Toolbox\RuntimeCache\$($config.RuntimeRelease)\$($config.BuildHash.Substring(0,16))\startup.log"
$results = @()
try {
    if ($Locale -ne 'current') {
        New-Item -ItemType Directory -Path (Split-Path $localeFile) -Force | Out-Null
        [IO.File]::WriteAllText($localeFile,(@{version=1;locale=$Locale}|ConvertTo-Json -Compress),(New-Object Text.UTF8Encoding($false)))
    }
    if ($Capture) {
        & $csc /nologo /target:winexe /platform:x64 /main:StartupCaptureHarness /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll @references "/win32manifest:$PSScriptRoot\..\launcher\KssolvLauncher.manifest" "/out:$captureExe" "$PSScriptRoot\StartupCaptureHarness.cs" @sources
        if ($LASTEXITCODE -ne 0) { throw 'Native renderer capture harness compilation failed.' }
    }
    for ($run=1; $run -le $Runs; $run++) {
        $result = Join-Path $root "run-$run.json"
        $mode = if ($ManualCancel) { 'cancel' } else { 'success' }
        $executable = if ($Capture -and $run -eq 1) { $captureExe } else { "$ApplicationRoot\KssolvLauncher.exe" }
        Write-Output "INSTALLED_STARTUP_RUN $run $mode $executable OUTPUT=$root"
        if ($Capture -and $run -eq 1) {
            & "$root\Acceptance.exe" $executable $result $log $mode "`"$root\startup-$Locale.png`""
        } else {
            & "$root\Acceptance.exe" $executable $result $log $mode
        }
        if ($LASTEXITCODE -ne 0) { throw "Installed startup acceptance failed: $result" }
        $data = Get-Content -LiteralPath $result -Raw | ConvertFrom-Json
        if ($Locale -ne 'current' -and $data.locale -ne $Locale) { throw 'Card did not use the saved Locale configuration.' }
        $results += $data
    }
    $results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$root\results.json" -Encoding UTF8
    $results | Select-Object mode,locale,cardAppearedSeconds,cardDurationSeconds,closeAfterVisibleMs,fullInterfaceLoaded,fullLoadAfterHandoffSeconds,appearanceReasonable,lifetimeReasonable,allBackendProcessesStopped | Export-Csv -LiteralPath "$root\timings.csv" -NoTypeInformation -Encoding UTF8
    Write-Output "INSTALLED_STARTUP_TESTS_SUCCESS $root"
} finally {
    if (Test-Path -LiteralPath $captureExe) { Remove-Item -LiteralPath $captureExe }
    if ($Locale -ne 'current') {
        if ($hadLocale) { [IO.File]::WriteAllBytes($localeFile,$originalLocale); [IO.File]::SetLastWriteTimeUtc($localeFile,$originalTime) }
        elseif (Test-Path -LiteralPath $localeFile) { Remove-Item -LiteralPath $localeFile }
    }
}
