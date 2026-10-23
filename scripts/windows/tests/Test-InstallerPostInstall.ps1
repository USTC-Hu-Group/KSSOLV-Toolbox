# Run the production installer code and Runtime file entries through a real
# isolated installation. Only external processes, registry discovery, cleanup,
# and diagnostic responses are replaced; progress pages and file I/O are real.
param([switch]$ReuseOnly)
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$installer = Join-Path $repository 'scripts\windows\installer'
$compiler = $env:KSSOLV_ISCC
if (!$compiler) { $compiler = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe' }
if (!(Test-Path -LiteralPath $compiler)) { throw 'Set KSSOLV_ISCC to the Inno Setup 7 compiler.' }
$root = Join-Path $repository ('.buildtool\installer-postinstall-tests\' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$main = Get-Content -LiteralPath (Join-Path $installer 'KSSOLV.iss') -Raw -Encoding UTF8
$messages = [regex]::Match($main, '(?s)\[Languages\].*?(?=\[Tasks\])').Value
$runtimeFiles = [regex]::Match($main, '(?s)#if RuntimeDelivery != "none".*?(?=\[Icons\])').Value
$code = [regex]::Match($main, '(?s)\[Code\].*').Value
if (!$messages -or !$runtimeFiles -or !$code) { throw 'Cannot locate production installer sections.' }
$code = $code.Replace('#include "Upgrade.iss"', 'procedure TryRemovePreviousInstallations; begin end;')
$code = $code.Replace('#include "Diagnostics.iss"', '#include "FixtureHelpers.iss"')
$code = $code.Replace('RegQueryStringValue(', 'FixtureRegQuery(')
$code = [regex]::Replace($code, '\bExecAsOriginalUser\(', 'FixturePrewarm(')
$code = [regex]::Replace($code, '\bExec\(', 'FixtureRuntime(')
$code = $code.Replace('if WizardSilent then RaiseException', 'if FixtureSilent then RaiseException')
# Record results at the real completion event; leave the post-install callback intact.
$code = $code.Replace('if CurStep <> ssPostInstall then Exit;', @'
  if CurStep = ssDone then begin
    SaveStringToFile(ExpandConstant('{param:RESULT|}'),
      Format('success=%d runtime=%d prewarm=%d diagnostics=%d page-restored=%d', [Ord(WarmSucceeded), FixtureRuntimeCalls, FixturePrewarmCalls,
         FixtureDiagnostics, Ord(WizardForm.CurPageID <> PreparationPage.ID)]), False);
  end;
  if CurStep <> ssPostInstall then Exit;
'@)
Copy-Item -LiteralPath (Join-Path $installer 'Design.iss') -Destination $root
Set-Content -LiteralPath (Join-Path $root 'RuntimeSetup.exe') -Value 'Inert Runtime payload; never executed.' -Encoding ASCII
$fixtureHelpers = @'
var FixtureRuntimeCalls, FixturePrewarmCalls, FixtureDiagnostics: Integer;

function FixtureCase: String;
begin Result := ExpandConstant('{param:CASE|reuse}'); end;

procedure FixtureRuntimeFiles(Root: String);
begin
  ForceDirectories(Root + '\runtime\win64');
  ForceDirectories(Root + '\bin\win64');
  SaveStringToFile(Root + '\runtime\win64\mclmcrrt26_2.dll', 'inert fixture', False);
  SaveStringToFile(Root + '\bin\win64\MATLABWindow.exe', 'inert fixture', False);
end;

function FixtureRegQuery(RootKey: Integer; SubKey, ValueName: String; var Value: String): Boolean;
begin
  if (SubKey <> 'SOFTWARE\MathWorks\MATLAB Runtime\26.2') or (ValueName <> 'MATLABROOT') then
    RaiseException('Unexpected registry discovery');
  Result := Pos('runtime-', FixtureCase) <> 1;
  if Result then begin
    Value := ExpandConstant('{param:DIR|}\existing-runtime');
    FixtureRuntimeFiles(Value);
  end;
  if FixtureCase = 'config-failure' then ForceDirectories(ExpandConstant('{param:DIR|}\launcher.ini'));
end;

function FixtureRuntime(const Filename, Params, WorkingDir: String; const ShowCmd: Integer;
  const Wait: TExecWait; var Code: Integer): Boolean;
begin
  FixtureRuntimeCalls := FixtureRuntimeCalls + 1;
  Log('FIXTURE_RUNTIME_EXEC ' + Filename);
  if not FileExists(Filename) then RaiseException('Packaged Runtime entry point does not exist: ' + Filename);
  if (Pos('-agreeToLicense yes', Params) = 0) or (Pos('-outputFile "', Params) = 0) or
    (Pos('-runtimeFolder "' + RuntimePage.Values[0] + '"', Params) = 0) then RaiseException('Invalid Runtime arguments');
  Code := 0; Result := True;
  if FixtureCase = 'runtime-launch-failure' then begin Result := False; Code := 5; Exit; end;
  if FixtureCase = 'runtime-exit-failure' then begin Code := 7; Exit; end;
  if FixtureCase <> 'runtime-missing' then FixtureRuntimeFiles(RuntimePage.Values[0] + '\R2026b');
end;

function FixturePrewarm(const Filename, Params, WorkingDir: String; const ShowCmd: Integer;
  const Wait: TExecWait; var Code: Integer): Boolean;
var StatusPath, Status: String; Start: Integer;
begin
  if (PreparationPage.Msg1Label.Font.Name <> WizardForm.PageDescriptionLabel.Font.Name) or
    (WarmDetail.Font.Name <> WizardForm.PageDescriptionLabel.Font.Name) or
    (WizardForm.PageNameLabel.Font.Name <> WizardForm.PageDescriptionLabel.Font.Name) or
    (PreparationPage.Msg1Label.Font.Size <> WizardForm.PageDescriptionLabel.Font.Size) or
    (WarmDetail.Font.Size <> WizardForm.PageDescriptionLabel.Font.Size) or
    (WizardForm.PageNameLabel.Font.Size - WarmDetail.Font.Size <> 2) then
    RaiseException('Inconsistent preparation page typography');
  FixturePrewarmCalls := FixturePrewarmCalls + 1;
  if Filename <> ExpandConstant('{app}\KssolvLauncher.exe') then RaiseException('Unexpected prewarm executable');
  if not FileExists(ExpandConstant('{app}\launcher.ini')) then RaiseException('Missing launcher configuration');
  Start := Pos('--result "', Params);
  if Start = 0 then RaiseException('Missing prewarm status path');
  StatusPath := Copy(Params, Start + 10, Length(Params) - Start - 10);
  Code := 0; Result := True;
  if FixtureCase = 'prewarm-launch-failure' then begin Result := False; Code := 5; Exit; end;
  if (FixtureCase = 'prewarm-exit-failure') or (FixtureCase = 'cancel') or
    ((FixtureCase = 'retry') and (FixturePrewarmCalls = 1)) then begin Code := 7; Exit; end;
  if FixtureCase = 'prewarm-missing-status' then Exit;
  Status := '{"status":"success","buildHash":"{#BuildHash}"}';
  if FixtureCase = 'prewarm-wrong-build' then Status := '{"status":"success","buildHash":"wrong"}';
  SaveStringToFile(StatusPath, Status, False);
end;

function FixtureSilent: Boolean;
begin Result := (FixtureCase <> 'retry') and (FixtureCase <> 'cancel'); end;

procedure OpenInstallerLog(Sender: TObject);
begin end;

function ShowInstallerDiagnostic(Message: String; AllowRetry, ContinueInstallation: Boolean): Integer;
begin
  FixtureDiagnostics := FixtureDiagnostics + 1;
  Log('FIXTURE_DIAGNOSTIC ' + Message);
  Result := mrOk;
  if AllowRetry then begin
    if (FixtureCase = 'retry') and (FixtureDiagnostics = 1) then Result := mrRetry
    else Result := mrCancel;
  end;
end;
'@
Set-Content -LiteralPath (Join-Path $root 'FixtureHelpers.iss') -Value $fixtureHelpers -Encoding UTF8
$setup = @'
[Setup]
AppId=KSSOLVPostInstallFixture
AppName=KSSOLV Post-install Fixture
AppVersion=1
DefaultDirName={tmp}\fixture-application
UsePreviousAppDir=no
UsePreviousLanguage=no
PrivilegesRequired=lowest
Uninstallable=no
SetupLogging=yes
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputDir=.
WizardStyle=modern light
WizardSizePercent=120,120
OutputBaseFilename=fixture
[Dirs]
Name: "{app}\installation-state"
'@
$stage = Join-Path $repository '.buildtool\standalone\windows-stage'
$baseDefines = @"
#define AppVersion "0.5.0"
#define RuntimeRelease "R2026b"
#define RuntimeVersion "26.2"
#define BuildHash "fixture-application-sha256"
#define RuntimeInstaller "$root\RuntimeSetup.exe"
#define RuntimePayload "$root\payload"
#define RuntimeEntryPoint "RuntimeSetup.exe"
"@
$null = New-Item -ItemType Directory -Path (Join-Path $root 'payload')
Copy-Item -LiteralPath (Join-Path $root 'RuntimeSetup.exe') -Destination (Join-Path $root 'payload')
$files = "[Files]`nSource: `"$stage\brand-logo.bmp`"; Flags: dontcopy`nSource: `"$stage\installer-art.bmp`"; Flags: dontcopy`n"
$files += 'Source: "' + $installer + '\matlabruntime_license_agreement.pdf"; Flags: dontcopy' + "`n"
$cases = @(
    @{ Name = 'reuse'; Success = 1; Runtime = 0; Prewarm = 1; Diagnostics = 0 },
    @{ Name = 'runtime-new'; Success = 1; Runtime = 1; Prewarm = 1; Diagnostics = 0 },
    @{ Name = 'runtime-launch-failure'; Success = 0; Runtime = 1; Prewarm = 0; Diagnostics = 1 },
    @{ Name = 'runtime-exit-failure'; Success = 0; Runtime = 1; Prewarm = 0; Diagnostics = 1 },
    @{ Name = 'runtime-missing'; Success = 0; Runtime = 1; Prewarm = 0; Diagnostics = 1 },
    @{ Name = 'config-failure'; Success = 0; Runtime = 0; Prewarm = 0; Diagnostics = 1 },
    @{ Name = 'prewarm-launch-failure'; Success = 0; Runtime = 0; Prewarm = 1; Diagnostics = 1 },
    @{ Name = 'prewarm-exit-failure'; Success = 0; Runtime = 0; Prewarm = 1; Diagnostics = 1 },
    @{ Name = 'prewarm-missing-status'; Success = 0; Runtime = 0; Prewarm = 1; Diagnostics = 1 },
    @{ Name = 'prewarm-wrong-build'; Success = 0; Runtime = 0; Prewarm = 1; Diagnostics = 1 },
    @{ Name = 'retry'; Success = 1; Runtime = 0; Prewarm = 2; Diagnostics = 1 },
    @{ Name = 'cancel'; Success = 0; Runtime = 0; Prewarm = 1; Diagnostics = 1 }
)
foreach ($mode in @('web', 'installer', 'none')) {
    $zip = [int]($mode -eq 'installer')
    $source = $baseDefines + "`n#define RuntimeDelivery `"$mode`"`n#define RuntimeIsZip `"$zip`"`n" +
        $setup + "`n" + $messages + $files + $runtimeFiles + $code
    $file = Join-Path $root 'fixture.iss'
    Set-Content -LiteralPath $file -Value $source -Encoding UTF8
    $ErrorActionPreference = 'Continue'
    & $compiler '/Qp' $file *> (Join-Path $root "$mode-compile.log")
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath (Join-Path $root "$mode-compile.log"); throw 'Fixture compilation failed.' }
    foreach ($language in @('en', 'zh')) {
        foreach ($case in $cases) {
            if (($ReuseOnly -and $case.Name -ne 'reuse') -or ($mode -eq 'none' -and $case.Name.StartsWith('runtime-'))) { continue }
            $name = "$mode-$language-$($case.Name)"
            $app = Join-Path $root $name
            $resultFile = "$app-result.txt"
            $setupLog = "$app-setup.log"
            $arguments = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LANG=' + $language + ' /CASE=' + $case.Name +
                ' /ACCEPTRUNTIMELICENSE=yes /DIR="' + $app + '" /RUNTIMEFOLDER="' + $app + '\new-runtime" /RESULT="' + $resultFile + '" /LOG="' + $setupLog + '"'
            $process = Start-Process -FilePath (Join-Path $root 'fixture.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru
            if (!$process.WaitForExit(30000)) {
                Get-CimInstance Win32_Process | Where-Object {
                    $_.Name -in @('fixture.exe', 'fixture.tmp') -and $_.CommandLine -and $_.CommandLine.Contains($root)
                } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                throw "Post-install fixture timed out: $name ($root)"
            }
            $expected = "success=$($case.Success) runtime=$($case.Runtime) prewarm=$($case.Prewarm) diagnostics=$($case.Diagnostics) page-restored=1"
            $actual = if (Test-Path -LiteralPath $resultFile) { [IO.File]::ReadAllText($resultFile) } else { 'No result' }
            if ($actual -ne $expected -or $process.ExitCode -ne (1 - $case.Success)) {
                Get-Content -LiteralPath $setupLog -Tail 16
                throw "Post-install failed: $name, expected '$expected', got '$actual', exit=$($process.ExitCode) ($root)"
            }
            Write-Output "PASS $name"
        }
    }
}
Write-Output "INSTALLER_POSTINSTALL_TEST_ROOT $root"
