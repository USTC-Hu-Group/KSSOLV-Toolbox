# Reproduce Setup's protected temporary ACL with a real non-elevated process.
# The copied helper has empty installation discovery; no real app is removed.
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
try {
    $user = $identity.User
    $admin = ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} finally { $identity.Dispose() }
if ($admin) { throw 'Run this permissions regression from a non-elevated PowerShell.' }

$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\installer\Remove-PreviousInstallation.ps1'))
. $source
$root = Join-Path ([IO.Path]::GetTempPath()) ('kssolv-upgrade-log-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$protected = Join-Path $root 'protected-setup-temp'
$null = New-Item -ItemType Directory -Path $protected
$helper = Join-Path $protected 'Remove-PreviousInstallation.ps1'
$text = Get-Content -LiteralPath $source -Raw
$marker = '# Dot-sourcing exposes'
if (!$text.Contains($marker)) { throw 'Cannot locate the helper entry point.' }
$text.Replace($marker, "function Get-KssolvPreviousInstallations { return @() }`r`n$marker") |
    Set-Content -LiteralPath $helper -Encoding UTF8
$logDirectory = Join-Path $protected 'upgrade-user-1'
$powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    $prepareLog = Join-Path $protected 'kssolv-upgrade-prepare.log'
    $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $helper +
        '" -PrepareUserLogDirectory "' + $logDirectory + '" -LogPath "' + $prepareLog + '"'
    $process = Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0 -or
        !(Select-String -LiteralPath $prepareLog -SimpleMatch 'Original-user upgrade diagnostics ready' -Quiet)) {
        throw 'The Setup preparation invocation failed.'
    }
    Write-Output 'PASS Setup prepares original-user diagnostics through the actual helper entry point'
    $rejected = $false
    try { Initialize-KssolvUserUpgradeLog $logDirectory $helper }
    catch { $rejected = $true }
    if (!$rejected) { throw 'An existing log directory was accepted.' }

    # Match Inno's elevated temporary ACL: administrators/SYSTEM full control,
    # the current user's non-elevated token only read and execute.
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($user)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @('S-1-5-32-544', 'S-1-5-18', $user.Value)) {
        $rights = [Security.AccessControl.FileSystemRights]::FullControl
        if ($sid -eq $user.Value) { $rights = [Security.AccessControl.FileSystemRights]::ReadAndExecute }
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            [Security.Principal.SecurityIdentifier]::new($sid), $rights,
            [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow)
        $null = $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $protected -AclObject $acl
    function Invoke-Fixture([string]$Log, [string]$Name) {
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $helper + '" -Scope User -LogPath "' + $Log + '"'
        $process = Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait `
            -RedirectStandardOutput (Join-Path $root "$Name.stdout") -RedirectStandardError (Join-Path $root "$Name.stderr")
        return $process.ExitCode
    }
    $oldLog = Join-Path $protected 'kssolv-upgrade-User.log'
    if ((Invoke-Fixture $oldLog 'old') -eq 0 -or (Test-Path -LiteralPath $oldLog)) {
        throw 'The old protected-root log path did not reproduce the failure.'
    }
    Write-Output 'PASS old original-user invocation fails before it can create a log'

    $log = Join-Path $logDirectory 'kssolv-upgrade-User.log'
    if ((Invoke-Fixture $log 'fixed') -ne 0 -or
        !(Select-String -LiteralPath $log -SimpleMatch 'Completed with exit code 0' -Quiet)) {
        throw 'The fixed original-user helper did not complete successfully.'
    }
    Set-Content -LiteralPath ($log + '.uninstall-0.log') -Value 'uninstaller log fixture'
    Write-Output 'PASS original-user helper and uninstaller can write their diagnostic logs'

    $before = [IO.File]::ReadAllText($helper)
    $blocked = $false
    try { [IO.File]::WriteAllText($helper, 'unexpected write') }
    catch [UnauthorizedAccessException] { $blocked = $true }
    if (!$blocked -or [IO.File]::ReadAllText($helper) -ne $before) { throw 'Helper code became writable.' }
    if ([IO.File]::ReadAllText($source) -notmatch 'Get-KssolvPreviousInstallations') { throw 'Source helper changed.' }
    Write-Output 'PASS helper code and protected temporary parent remain read-only'
} finally {
    # Restore the owning user's write access before removing only this fixture.
    $cleanupAcl = [Security.AccessControl.DirectorySecurity]::new()
    $cleanupAcl.SetAccessRuleProtection($true, $false)
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($user,
        [Security.AccessControl.FileSystemRights]::FullControl,
        [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
        [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Allow)
    $null = $cleanupAcl.AddAccessRule($rule)
    [IO.Directory]::SetAccessControl($protected, $cleanupAcl)
    $resolvedRoot = (Resolve-Path -LiteralPath $root).ProviderPath
    if (!$resolvedRoot.StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolvedRoot) -notlike 'kssolv-upgrade-log-test-*') { throw 'Unexpected fixture cleanup path.' }
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}
