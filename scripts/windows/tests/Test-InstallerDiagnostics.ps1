# Execute production Pascal callbacks and real dialog controls in an isolated
# Inno fixture. External cleanup processes and the log viewer are replaced.
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$installer = Join-Path $repository 'scripts\windows\installer'
$compiler = $env:KSSOLV_ISCC
if (!$compiler) { $compiler = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe' }
if (!(Test-Path -LiteralPath $compiler)) { throw 'Set KSSOLV_ISCC to the Inno Setup 7 compiler.' }
$root = Join-Path $repository ('.buildtool\installer-diagnostics-tests\' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
$main = Get-Content -LiteralPath (Join-Path $installer 'KSSOLV.iss') -Raw -Encoding UTF8
$messages = [regex]::Match($main, '(?s)\[CustomMessages\](.*?)\[Tasks\]').Groups[1].Value
$languageOptions = [regex]::Match($main, '(?s)\[LangOptions\].*?(?=\[Messages\])').Value
$prepare = [regex]::Match($main, '(?s)function PrepareToInstall\(.*?(?=function UpdateReadyMemo)').Value
if (!$messages -or !$prepare) { throw 'Cannot locate production messages or preparation callback.' }
$diagnostics = Get-Content -LiteralPath (Join-Path $installer 'Diagnostics.iss') -Raw -Encoding UTF8
$diagnostics = $diagnostics.Replace('ShellExec(', 'FixtureShellExec(')
$diagnostics = $diagnostics.Replace('Result := Dialog.ShowModal;', @'
    FixtureDialogs := FixtureDialogs + 1;
    if (Abs(Dialog.ClientWidth - ScaleX(600)) > 1) or (Abs(Dialog.ClientHeight - ScaleY(280)) > 1) then
      RaiseException(Format('Dialog was scaled twice: %d x %d, expected %d x %d', [Dialog.ClientWidth, Dialog.ClientHeight, ScaleX(600), ScaleY(280)]));
    if OpenLogButton.Caption <> CustomMessage('OpenLog') then RaiseException('Missing log button');
    PostMessage(OpenLogButton.Handle, $00F5, 0, 0);
    if FixtureDismiss and AllowRetry then PostMessage(DismissButton.Handle, $00F5, 0, 0)
    else PostMessage(ConfirmButton.Handle, $00F5, 0, 0);
    Result := Dialog.ShowModal;
'@)
$upgrade = Get-Content -LiteralPath (Join-Path $installer 'Upgrade.iss') -Raw -Encoding UTF8
$upgrade = [regex]::Replace($upgrade, '\b(?:ExecAsOriginalUser|Exec)\(', 'FixtureExec(')
$upgrade = $upgrade.Replace('ExtractTemporaryFile(', 'FixtureExtract(')
Set-Content -LiteralPath (Join-Path $root 'Diagnostics.iss') -Value $diagnostics -Encoding UTF8
Set-Content -LiteralPath (Join-Path $root 'Upgrade.iss') -Value $upgrade -Encoding UTF8
Set-Content -LiteralPath (Join-Path $root 'Prepare.iss') -Value $prepare -Encoding UTF8
$fixture = @'
#define RuntimeDelivery "web"
#define AppVersion "0.5.0"
#define RuntimeRelease "R2026b"
#define RuntimeVersion "26.2"
[Setup]
AppId=KSSOLVInstallerDiagnosticsFixture
AppName=KSSOLV Installer Diagnostics Fixture
AppVersion=1
DefaultDirName={tmp}\fixture-application
UsePreviousAppDir=no
PrivilegesRequired=lowest
CreateAppDir=no
Uninstallable=no
SetupLogging=yes
WizardStyle=modern light
WizardSizePercent=120,120
OutputDir=.
OutputBaseFilename=fixture
[Languages]
Name: en; MessagesFile: compiler:Default.isl
Name: zh; MessagesFile: compiler:Languages\ChineseSimplified.isl
@LANGUAGEOPTIONS@
[CustomMessages]
@MESSAGES@
[Code]
var UpgradeAttempt: Integer; UpgradeNeedsRestart: Boolean;
  FixtureCase, FixtureDialogs, FixtureOpenLogs, FixtureCleanupCalls: Integer;
  FixtureDismiss: Boolean;
  AcceptRuntime: TNewCheckBox; RuntimePage: TInputDirWizardPage;

function InstallNewRuntime: Boolean;
begin Result := False; end;

procedure FixtureExtract(Name: String);
begin
  if Name <> 'Remove-PreviousInstallation.ps1' then RaiseException('Unexpected extraction');
  if FixtureCase = 2 then RaiseException('Simulated extraction exception');
end;

function FixtureExec(const Filename, Params, WorkingDir: String; const ShowCmd: Integer;
  const Wait: TExecWait; var Code: Integer): Boolean;
begin
  Result := True; Code := 0;
  if Pos('-PrepareUserLogDirectory', Params) > 0 then begin
    if FixtureCase = 0 then begin Result := False; Code := 5; end;
    if FixtureCase = 1 then Code := 1;
    Exit;
  end;
  FixtureCleanupCalls := FixtureCleanupCalls + 1;
  if Pos('-Scope User', Params) > 0 then begin
    if FixtureCase = 3 then begin Result := False; Code := 5; end;
    if FixtureCase = 4 then Code := 7;
    if FixtureCase = 5 then Code := 3010;
  end else if Pos('-Scope Machine', Params) > 0 then begin
    if FixtureCase = 6 then begin Result := False; Code := 5; end;
    if FixtureCase = 7 then Code := 7;
    if FixtureCase = 8 then Code := 3010;
  end else RaiseException('Unexpected cleanup arguments');
end;

function FixtureShellExec(const Verb, Filename, Params, WorkingDir: String; const ShowCmd: Integer;
  const Wait: TExecWait; var Code: Integer): Boolean;
begin
  if (Verb <> 'open') or (Filename <> ExpandConstant('{log}')) or not FileExists(Filename) then
    RaiseException('Log button did not open the current Setup log');
  FixtureOpenLogs := FixtureOpenLogs + 1;
  Code := 0; Result := True;
end;

#include "Diagnostics.iss"
#include "Upgrade.iss"
#include "Prepare.iss"

procedure InitializeWizard;
var I, BeforeDialogs, Answer: Integer; Restart: Boolean; Message: String;
begin
  try
  AcceptRuntime := TNewCheckBox.Create(WizardForm);
  AcceptRuntime.Checked := True;
  if (ActiveLanguage = 'zh') and (CustomMessage('OpenLog') <> #25171#24320#26085#24535) then RaiseException('Chinese log label missing');
  if (ActiveLanguage = 'en') and (CustomMessage('OpenLog') <> 'Open log') then RaiseException('English log label missing');
  for I := 0 to 9 do begin
    FixtureCase := I; UpgradeNeedsRestart := False; Restart := False;
    BeforeDialogs := FixtureDialogs; FixtureCleanupCalls := 0;
    Message := PrepareToInstall(Restart);
    if (Message <> '') or Restart then RaiseException('Legacy cleanup blocked installation: ' + IntToStr(I));
    if (I < 9) and (FixtureDialogs <> BeforeDialogs + 1) then RaiseException('Missing cleanup warning');
    if (I = 9) and (FixtureDialogs <> BeforeDialogs) then RaiseException('Unexpected success warning');
    if (I <= 2) and (FixtureCleanupCalls <> 0) then RaiseException('Cleanup ran after preparation failed');
    if ((I >= 3) and (I <= 5)) and (FixtureCleanupCalls <> 1) then RaiseException('Cleanup continued after user failure');
    if (I >= 6) and (FixtureCleanupCalls <> 2) then RaiseException('Machine cleanup was not exercised');
    if UpgradeNeedsRestart <> ((I = 5) or (I = 8)) then RaiseException('Incorrect completion restart status');
  end;
  Answer := ShowInstallerDiagnostic('Validation error fixture', False, False);
  if Answer <> mrOk then RaiseException('Validation dialog did not close');
  Answer := ShowInstallerDiagnostic('Retry fixture', True, False);
  if Answer <> mrRetry then RaiseException('Retry button failed');
  FixtureDismiss := True;
  Answer := ShowInstallerDiagnostic('Cancel fixture', True, False);
  if Answer <> mrCancel then RaiseException('Cancel button failed');
  if (FixtureDialogs <> 12) or (FixtureOpenLogs <> 12) then RaiseException('Log click handlers were not exercised');
  SaveStringToFile(ExpandConstant('{param:RESULT|}'), 'PASS 10 cleanup outcomes; 12 dialogs and current-log clicks; retry/cancel', False);
  except
    SaveStringToFile(ExpandConstant('{param:RESULT|}'), 'FAIL ' + GetExceptionMessage, False);
  end;
  Abort;
end;
'@
$fixture = $fixture.Replace('@MESSAGES@', $messages).Replace('@LANGUAGEOPTIONS@', $languageOptions)
$file = Join-Path $root 'fixture.iss'
Set-Content -LiteralPath $file -Value $fixture -Encoding UTF8
$ErrorActionPreference = 'Continue' # Windows PowerShell wraps native stderr.
& $compiler '/Qp' $file *> (Join-Path $root 'compile.log')
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath (Join-Path $root 'compile.log'); throw 'Fixture compilation failed.' }
foreach ($language in @('en', 'zh')) {
    $resultFile = Join-Path $root "$language-result.txt"
    $setupLog = Join-Path $root "$language-setup.log"
    $arguments = '/SUPPRESSMSGBOXES /LANG=' + $language + ' /RESULT="' + $resultFile + '" /LOG="' + $setupLog + '"'
    $process = Start-Process -FilePath (Join-Path $root 'fixture.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit(30000)) {
        # Setup has a loader and a temporary child. Stop only this fixture's
        # processes; otherwise a failed assertion can leave its message box up.
        Get-CimInstance Win32_Process | Where-Object {
            $_.Name -in @('fixture.exe', 'fixture.tmp') -and $_.CommandLine -and $_.CommandLine.Contains($root)
        } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        throw "The $language diagnostics fixture timed out: $root"
    }
    # Abort exits the fixture before installation, after all callback assertions.
    if (!(Test-Path -LiteralPath $resultFile)) { Get-Content -LiteralPath $setupLog -Tail 25; throw "Fixture failed: $language" }
    if (![IO.File]::ReadAllText($resultFile).StartsWith('PASS ')) { throw [IO.File]::ReadAllText($resultFile) }
    Write-Output "$language`: $([IO.File]::ReadAllText($resultFile))"
}
Write-Output "INSTALLER_DIAGNOSTICS_TEST_ROOT $root"
