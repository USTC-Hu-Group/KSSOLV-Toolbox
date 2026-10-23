[CmdletBinding()]
param(
    [ValidateSet('User', 'Machine')][string]$Scope = 'User',
    [string]$LogPath,
    [string]$PrepareUserLogDirectory
)
$ErrorActionPreference = 'Stop'

function Initialize-KssolvUserUpgradeLog([string]$Directory, [string]$Helper) {
    # Setup's protected temporary directory is read-only to the original user.
    # Grant write access only to a fresh log subdirectory, never to helper code.
    if (Test-Path -LiteralPath $Directory) { throw 'The user upgrade log directory must be new.' }
    $null = New-Item -ItemType Directory -Path $Directory -ErrorAction Stop
    $users = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
    $acl = Get-Acl -LiteralPath $Directory
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($users,
        [Security.AccessControl.FileSystemRights]::Modify,
        [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
        [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Allow)
    $null = $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $Directory -AclObject $acl
    # A different account may have supplied the UAC credentials. Let the original
    # user read the helper by its exact path without granting write access.
    $acl = Get-Acl -LiteralPath $Helper
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($users,
        [Security.AccessControl.FileSystemRights]::ReadAndExecute,
        [Security.AccessControl.AccessControlType]::Allow)
    $null = $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $Helper -AclObject $acl
}

function Test-KssolvProductName([string]$Key, [string]$Name) {
    return $Key -eq '{5200919D-0E3D-4525-AD64-977F32DEDD5D}_is1' -or
        $Name -match '^KSSOLV[ _]Toolbox(?:[ _]V?\d+(?:\.\d+){1,3})?$'
}

function Get-KssolvPreviousInstallations([string]$InstallScope) {
    $hive = [Microsoft.Win32.RegistryHive]::CurrentUser
    if ($InstallScope -eq 'Machine') { $hive = [Microsoft.Win32.RegistryHive]::LocalMachine }
    $views = @([Microsoft.Win32.RegistryView]::Registry32)
    if ([Environment]::Is64BitOperatingSystem) { $views += [Microsoft.Win32.RegistryView]::Registry64 }
    $uninstallKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    foreach ($view in $views) {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
        try {
            $root = $base.OpenSubKey($uninstallKey)
            if (!$root) { continue }
            try {
                foreach ($name in $root.GetSubKeyNames()) {
                    $key = $root.OpenSubKey($name)
                    if (!$key) { continue }
                    try {
                        $displayName = [string]$key.GetValue('DisplayName')
                        $knownId = $name -eq '{5200919D-0E3D-4525-AD64-977F32DEDD5D}_is1'
                        if (!(Test-KssolvProductName $name $displayName)) { continue }
                        [pscustomobject]@{
                            Hive = $hive; View = $view; Key = "$uninstallKey\$name"
                            Name = $displayName; KnownId = $knownId
                            Directory = [string]$key.GetValue('Inno Setup: App Path')
                            Command = [string]$key.GetValue('UninstallString')
                        }
                    } finally { $key.Dispose() }
                }
            } finally { $root.Dispose() }
        } finally { $base.Dispose() }
    }
}

function Get-KssolvUninstaller($Installation) {
    # Only the project's Inno uninstaller is known to be native and supports the
    # silent flags below. Never execute an arbitrary registry command or shell.
    $command = $Installation.Command.Trim()
    if ($command.StartsWith('"')) {
        $end = $command.IndexOf('"', 1)
        if ($end -lt 0 -or $command.Substring($end + 1).Trim()) { throw 'Invalid uninstaller command.' }
        $exe = $command.Substring(1, $end - 1)
    } else { $exe = $command }
    if ($exe -notmatch '^[A-Za-z]:\\' -or [IO.Path]::GetFileName($exe) -notmatch '^unins\d{3}\.exe$') {
        throw "Unsupported previous uninstaller for $($Installation.Name). Remove that version before installing."
    }
    $exe = [IO.Path]::GetFullPath($exe)
    $directory = [IO.Path]::GetDirectoryName($exe)
    if (!$Installation.Directory -or
        $directory.TrimEnd('\') -ine [IO.Path]::GetFullPath($Installation.Directory).TrimEnd('\') -or
        $directory -eq [IO.Path]::GetPathRoot($directory)) { throw 'Uninstaller directory does not match its registration.' }
    if (!(Test-Path -LiteralPath $exe -PathType Leaf) -or
        !(Test-Path -LiteralPath ([IO.Path]::ChangeExtension($exe, '.dat')) -PathType Leaf)) {
        throw "Previous uninstaller is missing: $exe"
    }
    if (!$Installation.KnownId -and
        !(Test-Path -LiteralPath (Join-Path $directory 'application\KSSOLV_Toolbox.exe') -PathType Leaf)) {
        throw 'Previous installation lacks the KSSOLV application identity.'
    }
    for ($item = Get-Item -LiteralPath $exe; $null -ne $item; $item = $item.Parent) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Previous installation contains a reparse point.' }
        if ($item -is [IO.FileInfo]) { $item = $item.Directory; if (!$item) { break } }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Previous installation contains a reparse point.' }
    }
    return $exe
}

function Test-KssolvRegistration($Installation) {
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Installation.Hive, $Installation.View)
    try {
        $key = $base.OpenSubKey($Installation.Key)
        if (!$key) { return $false }
        $key.Dispose()
        return $true
    } finally { $base.Dispose() }
}

function Invoke-KssolvUninstaller([string]$Executable, [string]$UninstallLog) {
    $parameters = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="' + $UninstallLog + '"'
    $process = Start-Process -FilePath $Executable -ArgumentList $parameters -WindowStyle Hidden -PassThru -Wait
    return $process.ExitCode
}

function Assert-KssolvNotRunning([string[]]$Directories) {
    foreach ($process in Get-CimInstance -ClassName Win32_Process) {
        if (!$process.ExecutablePath) { continue }
        foreach ($directory in $Directories) {
            if ($process.ExecutablePath.StartsWith($directory.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
                throw "Close KSSOLV Toolbox before installing (PID $($process.ProcessId))."
            }
        }
    }
}

function Wait-KssolvRemoval($Installation, [string]$Executable, [double]$TimeoutSeconds = 15) {
    # Inno's parent can exit just before its temporary clone deletes the original
    # uninstaller. Wait for both the registration and the executable to disappear.
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $registered = Test-KssolvRegistration $Installation
        $exists = Test-Path -LiteralPath $Executable
        if (!$registered -and !$exists) { return }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($registered) { throw "Previous installation is still registered: $Executable" }
    throw "Previous uninstaller did not finish removing its files: $Executable"
}

function Test-KssolvPendingRemoval([string[]]$Directories) {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager')
    if (!$key) { return $false }
    try { $paths = @($key.GetValue('PendingFileRenameOperations')) }
    finally { $key.Dispose() }
    foreach ($path in $paths) {
        if (!$path) { continue }
        if ($path.StartsWith('\??\')) { $path = $path.Substring(4) }
        foreach ($directory in $Directories) {
            if ($path.StartsWith($directory.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    }
    return $false
}

function Remove-KssolvPreviousInstallations([string]$InstallScope, [string]$UpgradeLog) {
    $installations = @(Get-KssolvPreviousInstallations $InstallScope)
    # Validate every match first, so a broken registration cannot cause a partial
    # removal followed by discovery of an unsupported legacy installer.
    $validated = @($installations | ForEach-Object {
        [pscustomobject]@{ Installation = $_; Executable = Get-KssolvUninstaller $_ }
    })
    if (!$validated.Count) { return 0 }
    if ($InstallScope -eq 'Machine') {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        try { $admin = ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
        finally { $identity.Dispose() }
        if (!$admin) { throw 'Run Setup as administrator to remove the previous all-users installation.' }
    }
    $directories = @($validated | ForEach-Object { [IO.Path]::GetDirectoryName($_.Executable) })
    Assert-KssolvNotRunning $directories
    $removed = @{}
    foreach ($entry in $validated) {
        $exe = $entry.Executable
        if (!$removed.ContainsKey($exe)) {
            Add-Content -LiteralPath $UpgradeLog -Encoding UTF8 -Value "Removing $exe"
            $code = Invoke-KssolvUninstaller $exe ($UpgradeLog + '.uninstall-' + $removed.Count + '.log')
            if ($code -eq 3010) { return 3010 }
            if ($code -ne 0) { throw "Previous uninstaller failed with exit code $code`: $exe" }
            # Do not install new files over paths scheduled for deletion at the
            # next reboot: Windows would then delete the new installation too.
            if (Test-KssolvPendingRemoval $directories) { return 3010 }
            $removed[$exe] = $true
        }
        Wait-KssolvRemoval $entry.Installation $exe
    }
    return 0
}

# Dot-sourcing exposes the same functions for fixture tests without accessing the
# registry, starting a process, or changing the machine.
if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($PrepareUserLogDirectory) {
            if (!$LogPath) { throw 'An upgrade log preparation path is required.' }
            Set-Content -LiteralPath $LogPath -Encoding UTF8 -Value 'Preparing original-user upgrade diagnostics'
            Initialize-KssolvUserUpgradeLog $PrepareUserLogDirectory $PSCommandPath
            Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value 'Original-user upgrade diagnostics ready'
            exit 0
        }
        if (!$LogPath) { throw 'An upgrade log path is required.' }
        Set-Content -LiteralPath $LogPath -Encoding UTF8 -Value "KSSOLV previous-installation removal: $Scope"
        $code = Remove-KssolvPreviousInstallations $Scope $LogPath
        Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value "Completed with exit code $code"
        exit $code
    } catch {
        if ($LogPath) { Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value $_.Exception.Message }
        exit 1
    }
}
