[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\installer\Remove-PreviousInstallation.ps1'
# Parse the real PS 5.1-compatible script, then use its orchestration functions
# with isolated registry/process fixtures. No installed program is touched.
$tokens = $null; $errors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
. $source
$validateUninstaller = ${function:Get-KssolvUninstaller}
$waitForRemoval = ${function:Wait-KssolvRemoval}
foreach ($name in @('KSSOLV Toolbox', 'KSSOLV_Toolbox', 'KSSOLV Toolbox 0.4.1', 'KSSOLV_Toolbox_V0.4.1')) {
    if (!(Test-KssolvProductName 'other-key' $name)) { throw "Missed product: $name" }
}
foreach ($name in @('MATLAB Runtime', 'MATLAB', 'Other KSSOLV Toolbox', 'KSSOLV Toolbox Data', 'KSSOLV Toolbox Updater')) {
    if (Test-KssolvProductName 'other-key' $name) { throw "Matched unrelated product: $name" }
}
Write-Output 'PASS exact product identification excludes Runtime and unrelated names'
foreach ($command in @('cmd.exe /c erase *', '"C:\app\unins000.exe" & other.exe', 'C:\app\uninstall.exe')) {
    $rejected = $false
    try { $null = & $validateUninstaller ([pscustomobject]@{ Command = $command; Name = 'fixture' }) }
    catch { $rejected = $true }
    if (!$rejected) { throw "Accepted unsafe command: $command" }
}
Write-Output 'PASS unsupported commands are never executed'
$root = Join-Path ([IO.Path]::GetTempPath()) ('kssolv-upgrade-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$log = Join-Path $root 'upgrade.log'
try {
    $repair = Join-Path $root 'damaged installation'
    $null = New-Item -ItemType Directory -Path $repair
    $repairExe = Join-Path $repair 'unins000.exe'
    $repairDat = [IO.Path]::ChangeExtension($repairExe, '.dat')
    $view = [Microsoft.Win32.RegistryView]::Registry32
    if ([Environment]::Is64BitOperatingSystem) { $view = [Microsoft.Win32.RegistryView]::Registry64 }
    $registration = [pscustomobject]@{
        Command = '"' + $repairExe + '"'; Directory = $repair
        Name = 'KSSOLV Toolbox'; KnownId = $true; View = $view
    }
    foreach ($missing in @('exe and data', 'exe', 'data')) {
        if ($missing -eq 'exe') { Set-Content -LiteralPath $repairDat -Value 'fixture' }
        if ($missing -eq 'data') {
            Remove-Item -LiteralPath $repairDat
            Set-Content -LiteralPath $repairExe -Value 'fixture'
        }
        if ($null -ne (& $validateUninstaller $registration $repair)) { throw "Missing $missing did not select repair." }
    }
    foreach ($problem in @('different destination', 'unknown product', 'different registry view', 'no repair request')) {
        $target = $repair
        $registration.KnownId = $true; $registration.View = $view
        switch ($problem) {
            'different destination' { $target = Join-Path $root 'new installation' }
            'unknown product' { $registration.KnownId = $false }
            'different registry view' { $registration.View = [Microsoft.Win32.RegistryView]::Default }
            'no repair request' { $target = '' }
        }
        $rejected = $false
        try { $null = & $validateUninstaller $registration $target } catch { $rejected = $true }
        if (!$rejected) { throw "Unexpected repair accepted: $problem" }
    }
    $registration.KnownId = $true; $registration.View = $view
    Set-Content -LiteralPath $repairDat -Value 'fixture'
    if ((& $validateUninstaller $registration $repair) -ne $repairExe) { throw 'Valid uninstaller did not retain the normal removal path.' }
    Write-Output 'PASS missing uninstall files allow repair only for the same product, directory and registry view'
    foreach ($destination in @($repair, (Join-Path $repair 'nested'), $root)) {
        if ($null -ne (& $validateUninstaller $registration '' $destination)) { throw 'An overlapping destination would run an external uninstaller.' }
    }
    if ((& $validateUninstaller $registration '' (Join-Path $root 'separate destination')) -ne $repairExe) {
        throw 'Separate installations stopped supporting optional cleanup.'
    }
    Write-Output 'PASS overlapping installation directories use native upgrades without external uninstall'

    $redirectTarget = Join-Path $root 'redirect target'
    $null = New-Item -ItemType Directory -Path $redirectTarget
    $junction = Join-Path $root 'redirected installation'
    $null = New-Item -ItemType Junction -Path $junction -Target $redirectTarget
    try {
        $redirected = [pscustomobject]@{
            Command = '"' + (Join-Path $junction 'unins000.exe') + '"'; Directory = $junction
            Name = 'KSSOLV Toolbox'; KnownId = $true; View = $view
        }
        $rejected = $false
        try { $null = & $validateUninstaller $redirected $junction } catch { $rejected = $true }
        if (!$rejected) { throw 'A redirected repair directory was accepted.' }
    } finally { [IO.Directory]::Delete($junction) }
    Write-Output 'PASS missing uninstall files do not bypass directory redirection checks'

    function Get-KssolvPreviousInstallations($InstallScope) { return $script:Entries }
    function Get-KssolvUninstaller($Installation) {
        if ($Installation.Broken) { throw 'invalid registration' }
        return $Installation.Executable
    }
    function Assert-KssolvNotRunning($Directories) { if ($script:Running) { throw 'application running' } }
    function Test-KssolvPendingRemoval($Directories) { return $script:PendingRemoval }
    function Test-KssolvRegistration($Installation) { return $script:StillRegistered }
    function Wait-KssolvRemoval($Installation, $Executable) { & $waitForRemoval $Installation $Executable 0 }
    function Invoke-KssolvUninstaller($Executable, $UninstallLog) {
        $script:Calls += $Executable
        if ($script:ExitCode -eq 0 -and !$script:KeepFiles) { Remove-Item -LiteralPath $Executable }
        return $script:ExitCode
    }
    function Reset-Fixture {
        $script:Entries = @(); $script:Calls = @(); $script:Running = $false
        $script:StillRegistered = $false; $script:KeepFiles = $false; $script:ExitCode = 0; $script:PendingRemoval = $false
    }
    function Add-Installation([string]$Name) {
        $exe = Join-Path $root $Name
        Set-Content -LiteralPath $exe -Value 'fixture'
        $script:Entries += [pscustomobject]@{ Executable = $exe; Broken = $false }
    }
    function Assert-Fails([string]$Expected) {
        $failed = $false
        try { $null = Remove-KssolvPreviousInstallations 'User' $log }
        catch { if ($_.Exception.Message -notlike "*$Expected*") { throw }; $failed = $true }
        if (!$failed) { throw "Expected failure: $Expected" }
    }
    Reset-Fixture
    if ((Remove-KssolvPreviousInstallations 'User' $log) -ne 0 -or $script:Calls.Count) { throw 'Fresh install failed.' }
    Write-Output 'PASS fresh install'

    Reset-Fixture; Add-Installation 'old-one.exe'; Add-Installation 'old-two.exe'
    $data = Join-Path $root 'project.ks'; Set-Content -LiteralPath $data -Value 'preserve'
    if ((Remove-KssolvPreviousInstallations 'User' $log) -ne 0 -or $script:Calls.Count -ne 2) { throw 'Multiple installations were not removed.' }
    if (!(Test-Path -LiteralPath $data)) { throw 'User data was removed.' }
    Write-Output 'PASS multiple versions and retained user data'

    Reset-Fixture; Add-Installation 'first.exe'; Add-Installation 'broken.exe'; $script:Entries[1].Broken = $true
    Assert-Fails 'invalid registration'
    if ($script:Calls.Count) { throw 'Uninstall started before all registrations were validated.' }
    Write-Output 'PASS validation before removal'

    Reset-Fixture; Add-Installation 'running.exe'; $script:Running = $true
    Assert-Fails 'application running'
    if ($script:Calls.Count) { throw 'Running application was removed.' }
    Write-Output 'PASS running application blocks removal'

    Reset-Fixture; Add-Installation 'failed.exe'; $script:ExitCode = 7
    Assert-Fails 'exit code 7'
    Write-Output 'PASS failed uninstaller blocks installation'

    Reset-Fixture; Add-Installation 'registered.exe'; $script:StillRegistered = $true
    Assert-Fails 'still registered'
    Write-Output 'PASS surviving registry entry blocks installation'

    Reset-Fixture; Add-Installation 'remaining.exe'; $script:KeepFiles = $true
    Assert-Fails 'did not finish'
    Write-Output 'PASS incomplete file removal blocks installation'

    Reset-Fixture; Add-Installation 'duplicate.exe'; $script:Entries += $script:Entries[0]
    if ((Remove-KssolvPreviousInstallations 'User' $log) -ne 0 -or $script:Calls.Count -ne 1) { throw 'Duplicate registration ran twice.' }
    Write-Output 'PASS duplicate registry views are deduplicated'

    Reset-Fixture; Add-Installation 'pending.exe'; Add-Installation 'not-yet-removed.exe'; $script:PendingRemoval = $true
    if ((Remove-KssolvPreviousInstallations 'User' $log) -ne 3010 -or $script:Calls.Count -ne 1) { throw 'Pending reboot did not stop installation.' }
    Write-Output 'PASS pending reboot pauses installation before new files are installed'

    Reset-Fixture
    $script:Entries = @([pscustomobject]@{ Executable = $null; Directory = $repair; Broken = $false })
    $sentinel = Join-Path $repair 'project.ks'; Set-Content -LiteralPath $sentinel -Value 'preserve during repair'
    if ((Remove-KssolvPreviousInstallations 'User' $log) -ne 0 -or $script:Calls.Count) { throw 'Repair attempted an external uninstall.' }
    if (!(Test-Path -LiteralPath $sentinel) -or !(Test-Path -LiteralPath $repairExe)) { throw 'Repair removed existing files.' }
    if (!(Select-String -LiteralPath $log -SimpleMatch 'Installing directly over the existing KSSOLV files' -Quiet)) { throw 'Repair decision was not logged.' }
    $script:Running = $true; Assert-Fails 'application running'; $script:Running = $false
    $script:PendingRemoval = $true
    if ((Remove-KssolvPreviousInstallations 'User' $log) -ne 3010 -or $script:Calls.Count) { throw 'Repair ignored pending deletion.' }
    Write-Output 'PASS repair preserves application and user files and respects running processes and pending reboot'
} finally {
    $resolvedRoot = (Resolve-Path -LiteralPath $root).ProviderPath
    if (!$resolvedRoot.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolvedRoot) -notlike 'kssolv-upgrade-test-*') { throw 'Unexpected fixture cleanup path.' }
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}
