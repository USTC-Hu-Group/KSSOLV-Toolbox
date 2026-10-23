# Exercise Runtime reuse without installing Runtime or launching MATLAB.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$cache = Join-Path $repository '.buildtool\standalone'
$base = Get-ChildItem -LiteralPath (Join-Path $cache 'base-installer') -File | Where-Object {
    $_.Name -match '^KSSOLV_Toolbox_V\d+(?:\.\d+){1,3}\.exe$'
} | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if (!$base) { throw 'Build a MathWorks web base installer before running this test.' }
$app = Join-Path $cache 'build\KSSOLV_Toolbox.exe'
$root = Join-Path $repository ('.buildtool\runtime-payload-tests\' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$tool = Join-Path $root 'RuntimePayload.exe'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:exe /platform:x64 /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/out:$tool" "$PSScriptRoot\..\installer\RuntimePayload.cs"
if ($LASTEXITCODE -ne 0) { throw 'Runtime extractor compilation failed' }
[Reflection.Assembly]::LoadFrom($tool) | Out-Null
$bundleName = 'MW_COMPILER_EZDEPLOY_INSTALL_BUNDLE'
$agentName = 'MW_COMPILER_EZDEPLOY_INSTALL_AGENT'
$urlName = 'MW_COMPILER_EZDEPLOY_INSTALLAGENT_URL'
$originalHash = (Get-FileHash -LiteralPath $base.FullName).Hash
$bundle = [InstallerResources]::Read($base.FullName, $bundleName)
if (!$bundle -or ![InstallerResources]::Has($base.FullName, $urlName)) { throw 'Test requires a real MathWorks web base installer' }

function Get-Manifest([byte[]]$Bytes) {
    $stream = [IO.MemoryStream]::new($Bytes, $false)
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
    try {
        $reader = [IO.StreamReader]::new($zip.GetEntry('ApplicationInstallerManifest.xml').Open())
        try { [xml]$xml = $reader.ReadToEnd(); return $xml }
        finally { $reader.Dispose() }
    } finally { $zip.Dispose(); $stream.Dispose() }
}
function Assert-RuntimeManifest([byte[]]$Bytes) {
    $xml = Get-Manifest $Bytes
    if ($xml.ApplicationInstallerManifest.ApplicationName) { throw 'Application instructions leaked into Runtime manifest' }
    if ($xml.ApplicationInstallerManifest.MCRProducts.OuterXml -ne (Get-Manifest $bundle).ApplicationInstallerManifest.MCRProducts.OuterXml) {
        throw 'Runtime component list changed'
    }
    $stream = [IO.MemoryStream]::new($Bytes, $false)
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
    try { if ($zip.Entries.Count -ne 1) { throw 'Application payload remains in Runtime bundle' } }
    finally { $zip.Dispose(); $stream.Dispose() }
}
function Invoke-Reuse([string]$InputFile, [string]$Name, [string]$Mode) {
    $target = Join-Path $root $Name
    & $tool $InputFile $app $target $Mode | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Runtime reuse failed: $Name" }
    return $target
}
function Hash-Bytes([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)) }
    finally { $sha.Dispose() }
}
function Assert-Rejected([string]$InputFile, [string]$ApplicationFile, [string]$Name, [string]$Mode, [string]$Message) {
    $ErrorActionPreference = 'Continue' # PowerShell 5.1 wraps expected native stderr as an error record.
    & $tool $InputFile $ApplicationFile "$root\$Name" $Mode *> "$root\$Name.log"
    $result = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($result -eq 0 -or !(Select-String -LiteralPath "$root\$Name.log" -SimpleMatch $Message -Quiet)) {
        throw "Expected failure was not detected: $Name"
    }
}

$web = Invoke-Reuse $base.FullName 'web-output' auto
Assert-RuntimeManifest ([InstallerResources]::Read("$web\RuntimeSetup.exe", $bundleName))
if ((Hash-Bytes ([InstallerResources]::Read($base.FullName, $urlName))) -ne (Hash-Bytes ([InstallerResources]::Read("$web\RuntimeSetup.exe", $urlName)))) { throw 'Web endpoint changed' }
if ((Get-FileHash -LiteralPath $base.FullName).Hash -ne $originalHash) { throw 'Original base installer was modified' }
Write-Output 'PASS real web base reuse, component list, application removal and input preservation'

# Model an embedded offline agent with a deterministic ZIP fixture. No Runtime installation.
$agent = [IO.MemoryStream]::new()
$agentZip = [IO.Compression.ZipArchive]::new($agent, [IO.Compression.ZipArchiveMode]::Create, $true)
$writer = [IO.StreamWriter]::new($agentZip.CreateEntry('archives/runtime-fixture.txt').Open())
$writer.Write('Runtime payload preservation sentinel'); $writer.Dispose(); $agentZip.Dispose()
$agentBytes = $agent.ToArray(); $agent.Dispose()
$offlineBase = Join-Path $root 'OfflineBase.exe'
Copy-Item -LiteralPath $base.FullName -Destination $offlineBase
[InstallerResources]::Write($offlineBase, $urlName, $null)
[InstallerResources]::Write($offlineBase, $agentName, $agentBytes)
$offlineInputHash = (Get-FileHash -LiteralPath $offlineBase).Hash
$offline = Invoke-Reuse $offlineBase 'offline-exe-output' installer
Assert-RuntimeManifest ([InstallerResources]::Read("$offline\RuntimeSetup.exe", $bundleName))
if ((Hash-Bytes ([InstallerResources]::Read("$offline\RuntimeSetup.exe", $agentName))) -ne (Hash-Bytes $agentBytes)) { throw 'Embedded offline agent changed' }
if ((Get-FileHash -LiteralPath $offlineBase).Hash -ne $offlineInputHash) { throw 'Offline base input modified' }
Write-Output 'PASS offline EXE fixture: agent retained byte-for-byte'

$zipSource = Join-Path $root 'zip-source'
New-Item -ItemType Directory -Path "$zipSource\data" | Out-Null
Copy-Item -LiteralPath $offlineBase -Destination "$zipSource\OfflineBase.exe"
[InstallerResources]::Write("$zipSource\OfflineBase.exe", $bundleName, $null)
[InstallerResources]::Write("$zipSource\OfflineBase.exe", $agentName, $null)
$bootstrapHash = (Get-FileHash -LiteralPath "$zipSource\OfflineBase.exe").Hash
[IO.File]::WriteAllBytes("$zipSource\data\bundle.zip", $bundle)
[IO.File]::WriteAllBytes("$zipSource\data\InstallAgent.zip", $agentBytes)
$baseZip = Join-Path $root 'OfflineBase.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($zipSource, $baseZip, [IO.Compression.CompressionLevel]::NoCompression, $false)
$offlineZip = Invoke-Reuse $baseZip 'offline-zip-output' auto
Assert-RuntimeManifest ([IO.File]::ReadAllBytes("$offlineZip\data\bundle.zip"))
if ((Hash-Bytes ([IO.File]::ReadAllBytes("$offlineZip\data\InstallAgent.zip"))) -ne (Hash-Bytes $agentBytes)) { throw 'External offline agent changed' }
if ((Get-FileHash -LiteralPath "$offlineZip\RuntimeSetup.exe").Hash -ne $bootstrapHash) { throw 'ZIP bootstrap changed' }
Write-Output 'PASS offline ZIP fixture: bootstrap and agent retained byte-for-byte'

# MathWorks leaves MCRProducts absent when no Runtime is requested.
$noneStream = [IO.MemoryStream]::new()
$noneStream.Write($bundle, 0, $bundle.Length); $noneStream.Position = 0
$noneZip = [IO.Compression.ZipArchive]::new($noneStream, [IO.Compression.ZipArchiveMode]::Update, $true)
$noneXml = Get-Manifest $bundle
$noneXml.DocumentElement.RemoveChild($noneXml.DocumentElement.SelectSingleNode('MCRProducts')) | Out-Null
$noneZip.GetEntry('ApplicationInstallerManifest.xml').Delete()
$noneEntry = $noneZip.CreateEntry('ApplicationInstallerManifest.xml').Open()
$noneXml.Save($noneEntry); $noneEntry.Dispose(); $noneZip.Dispose()
$noneBase = Join-Path $root 'NoneBase.exe'
Copy-Item -LiteralPath $base.FullName -Destination $noneBase
[InstallerResources]::Write($noneBase, $bundleName, $noneStream.ToArray()); $noneStream.Dispose()
$none = Invoke-Reuse $noneBase 'none-output' auto
if ((Get-Content -LiteralPath "$none\payload.json" -Raw | ConvertFrom-Json).RuntimeDelivery -ne 'none' -or
    (Test-Path -LiteralPath "$none\RuntimeSetup.exe")) { throw 'Application-only base was not recognized' }
Write-Output 'PASS application-only base without MCRProducts recognized'

Assert-Rejected $base.FullName $app 'wrong-mode' installer 'requested installer'
$badApp = Join-Path $root 'bad-app\KSSOLV_Toolbox.exe'
New-Item -ItemType Directory -Path (Split-Path $badApp) | Out-Null
'different build' | Set-Content -LiteralPath $badApp
Assert-Rejected $base.FullName $badApp 'wrong-build' auto 'does not match the current build'
$unsafeZip = Join-Path $root 'Unsafe.zip'
$unsafe = [IO.Compression.ZipFile]::Open($unsafeZip, [IO.Compression.ZipArchiveMode]::Create)
$unsafe.CreateEntry('../outside.txt') | Out-Null; $unsafe.Dispose()
Assert-Rejected $unsafeZip $app 'unsafe-output' auto 'Unsafe path'
if (Test-Path -LiteralPath "$root\outside.txt") { throw 'ZIP traversal wrote outside output directory' }
Write-Output 'PASS missing offline agent, mismatched application and ZIP traversal rejected'
Write-Output "RUNTIME_PAYLOAD_TEST_ROOT $root"
