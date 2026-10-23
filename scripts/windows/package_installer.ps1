[CmdletBinding()]
param(
    [ValidateSet('auto', 'web', 'installer', 'none')][string]$RuntimeDelivery = 'auto',
    [string]$InnoCompiler = $env:KSSOLV_ISCC,
    [ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$OutputName
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This packaging script is Windows only.' }
# MATLAB can inherit PowerShell 7's PSModulePath when it starts Windows PowerShell 5.1.
# Load native modules by absolute path rather than depending on that inherited search path.
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Utility')
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Management')
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$releaseDirectory = Join-Path $repository 'Release'
$cacheDirectory = Join-Path $repository '.buildtool\standalone'
$baseDirectory = Join-Path $cacheDirectory 'base-installer'
$stage = Join-Path $cacheDirectory 'windows-stage'
$application = Join-Path $cacheDirectory 'build\KSSOLV_Toolbox.exe'
if (!(Test-Path -LiteralPath $application)) { throw "Missing application: $application" }

# KSSOLV_Toolbox.Version is the single project version source, shared with MATLAB.
# Reading the constant here also supports repackaging without starting MATLAB.
$versionSource = Join-Path $repository 'KSSOLV_Toolbox.m'
$versionDeclaration = [regex]::Match((Get-Content -LiteralPath $versionSource -Raw -Encoding UTF8),
    '(?m)^\s*Version\s+string\s*=\s*[''"](?<version>\d+(?:\.\d+){1,3})[''"]\s*(?:%[^\r\n]*)?$')
if (!$versionDeclaration.Success) { throw "Cannot read numeric KSSOLV_Toolbox.Version from $versionSource" }
$Version = $versionDeclaration.Groups['version'].Value
$versionParts = @($Version.Split('.') | ForEach-Object { [int]$_ })
while ($versionParts.Count -lt 4) { $versionParts += 0 }
$expectedFileVersion = $versionParts -join '.'
$applicationInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($application)
$applicationVersion = @($applicationInfo.FileMajorPart, $applicationInfo.FileMinorPart,
    $applicationInfo.FileBuildPart, $applicationInfo.FilePrivatePart) -join '.'
if ($applicationVersion -ne $expectedFileVersion) {
    throw "Project version $Version differs from compiled application version $applicationVersion. Run buildInstaller() before packaging."
}
Write-Output "WINDOWS_INSTALLER_VERSION $Version (KSSOLV_Toolbox.Version; compiled application verified)"

# buildInstaller completes MathWorks base packaging first, just like on macOS.
$baseInstaller = @("$baseDirectory\KSSOLV_Toolbox_V$Version.exe",
    "$baseDirectory\KSSOLV_Toolbox_V$Version.zip") |
    ForEach-Object { if (Test-Path -LiteralPath $_) { Get-Item -LiteralPath $_ } } |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if (!$baseInstaller -or $baseInstaller.LastWriteTimeUtc -lt (Get-Item -LiteralPath $application).LastWriteTimeUtc) {
    throw 'Missing or stale MathWorks base installer. Run buildInstaller() before this script.'
}
$buildMetadata = Join-Path $cacheDirectory 'build\buildresult.json'
if (!(Test-Path -LiteralPath $buildMetadata)) { throw 'Missing buildresult.json. Run buildInstaller() first.' }
$runtimeMetadataPath = Join-Path $cacheDirectory 'build\runtime-metadata.json'
if (!(Test-Path -LiteralPath $runtimeMetadataPath)) {
    throw 'Missing runtime-metadata.json. Run buildInstaller() to record the build Runtime versions.'
}
$runtimeMetadata = Get-Content -LiteralPath $runtimeMetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$RuntimeRelease = [string]$runtimeMetadata.RuntimeRelease
$RuntimeVersion = [string]$runtimeMetadata.RuntimeVersion
if ($RuntimeRelease -notmatch '^R\d{4}[ab]$' -or $RuntimeVersion -notmatch '^\d+\.\d+$' -or
    $runtimeMetadata.StartupProtocolVersion -ne 1 -or
    [string]$runtimeMetadata.ApplicationVersion -ne $Version -or
    (Get-Item -LiteralPath $runtimeMetadataPath).LastWriteTimeUtc -lt (Get-Item -LiteralPath $application).LastWriteTimeUtc) {
    throw 'Invalid or stale Runtime build metadata. Run buildInstaller() again.'
}
Write-Output "WINDOWS_INSTALLER_RUNTIME $RuntimeRelease ($RuntimeVersion; from build/runtime-metadata.json)"

if (!$InnoCompiler) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe')
    )
    $InnoCompiler = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (!$InnoCompiler -or !(Test-Path -LiteralPath $InnoCompiler)) {
    throw 'Install Inno Setup 7 (winget install --id JRSoftware.InnoSetup.7 -e) or set KSSOLV_ISCC.'
}
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $csc)) { throw '.NET Framework 4.x compiler is required.' }
& $csc /nologo /target:exe /reference:System.Drawing.dll "/out:$stage\BrandAssets.exe" "$PSScriptRoot\installer\BrandAssets.cs"
if ($LASTEXITCODE -ne 0) { throw 'Installer artwork compilation failed.' }
& "$stage\BrandAssets.exe" $stage "$repository\+kssolv\+ui\resources\icons\companyLOGO.png" "$PSScriptRoot\installer\assets\crystal.png"
if ($LASTEXITCODE -ne 0) { throw 'Installer artwork generation failed.' }
. "$PSScriptRoot\launcher\StartupDependencies.ps1"
$webViewReferences = Initialize-StartupHostDependencies $stage
& $csc /nologo /target:winexe /platform:x64 /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll @webViewReferences "/win32manifest:$PSScriptRoot\launcher\KssolvLauncher.manifest" "/win32icon:$stage\kssolv.ico" "/out:$stage\KssolvLauncher.exe" "$PSScriptRoot\launcher\KssolvLauncher.cs" "$PSScriptRoot\launcher\SplashWindow.cs" "$PSScriptRoot\launcher\StartupCard.cs"
if ($LASTEXITCODE -ne 0) { throw 'Windows launcher compilation failed.' }
New-Item -ItemType Directory -Path "$stage\startup" -Force | Out-Null
Copy-Item -LiteralPath "$repository\scripts\startup\index.html" -Destination "$stage\startup\index.html"
Copy-Item -LiteralPath "$repository\+kssolv\+ui\resources\icons\companyLOGO.png" -Destination "$stage\startup\company-logo.png"
Copy-Item -LiteralPath "$repository\scripts\startup\quantum-materials.png" -Destination "$stage\startup\quantum-materials.png"
& $csc /nologo /target:exe /platform:x64 /main:StartupPreviewBuilder /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll @webViewReferences "/win32manifest:$PSScriptRoot\launcher\KssolvLauncher.manifest" "/out:$stage\StartupPreviewBuilder.exe" "$PSScriptRoot\launcher\StartupPreviewBuilder.cs" "$PSScriptRoot\launcher\StartupCard.cs"
if ($LASTEXITCODE -ne 0) { throw 'Startup preview builder compilation failed.' }
& "$stage\StartupPreviewBuilder.exe" "$stage\startup" $Version
if ($LASTEXITCODE -ne 0) { throw 'Shared HTML startup preview generation failed.' }
$buildHash = (Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash.ToLowerInvariant()
# Reuse the base bootstrap and its exact Runtime components. No MATLAB process.
$runtimeDirectory = Join-Path $stage ('runtime-' + [Guid]::NewGuid().ToString('N'))
& $csc /nologo /target:exe /platform:x64 /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/out:$stage\RuntimePayload.exe" "$PSScriptRoot\installer\RuntimePayload.cs"
if ($LASTEXITCODE -ne 0) { throw 'Runtime payload extractor compilation failed.' }
& "$stage\RuntimePayload.exe" $baseInstaller.FullName $application $runtimeDirectory $RuntimeDelivery
if ($LASTEXITCODE -ne 0) { throw 'Cannot reuse Runtime payload from the base installer.' }
$payloadInfo = Get-Content -LiteralPath (Join-Path $runtimeDirectory 'payload.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$RuntimeDelivery = [string]$payloadInfo.RuntimeDelivery
$runtimeIsZip = [int]$payloadInfo.RuntimeIsZip
$runtimeInstaller = Join-Path $runtimeDirectory 'RuntimeSetup.exe'
$runtimePayload = $runtimeDirectory
$runtimeEntryPoint = 'RuntimeSetup.exe'
$defines = @("/DAppVersion=$Version", "/DRuntimeRelease=$RuntimeRelease", "/DRuntimeVersion=$RuntimeVersion",
    "/DBuildHash=$buildHash", "/DRuntimeDelivery=$RuntimeDelivery", "/DRepository=$repository",
    "/DStage=$stage", "/DReleaseDirectory=$releaseDirectory", "/DApplication=$application", "/DRuntimeInstaller=$runtimeInstaller",
    "/DRuntimePayload=$runtimePayload", "/DRuntimeIsZip=$runtimeIsZip", "/DRuntimeEntryPoint=$runtimeEntryPoint")
if ($OutputName) { $defines += "/F$OutputName" }
& $InnoCompiler @defines "$PSScriptRoot\installer\KSSOLV.iss"
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup packaging failed.' }
if (!$OutputName) { $OutputName = "KSSOLV_Toolbox_V${Version}" }
$artifacts = @(Get-Item -LiteralPath "$releaseDirectory\$OutputName.exe")
# Offline installers may have companion volumes; the base installer stays private.
$artifacts += @(Get-ChildItem -LiteralPath $releaseDirectory -Filter "$OutputName-*.bin" -File)
$toolbox = Join-Path $releaseDirectory "KSSOLV_Toolbox_V$Version.mltbx"
if (Test-Path -LiteralPath $toolbox) { $artifacts += Get-Item -LiteralPath $toolbox }
$checksums = foreach ($artifact in $artifacts | Sort-Object Name) {
    $hash = (Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($artifact.Name)"
}
$checksums | Set-Content -LiteralPath "$releaseDirectory\SHA256SUMS-V$Version-Windows.txt" -Encoding ascii
Write-Output "WINDOWS_INSTALLER_SUCCESS $releaseDirectory\$OutputName.exe"
