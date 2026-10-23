; Windows only. Build through ../package_installer.ps1 (Inno Setup >= 7).
#if Ver < EncodeVer(7, 0, 0)
  #error Inno Setup 7 or later is required.
#endif

[Setup]
AppId={{5200919D-0E3D-4525-AD64-977F32DEDD5D}
AppName=KSSOLV Toolbox
AppVersion={#AppVersion}
AppPublisher=KSSOLV Toolbox Development Team
AppPublisherURL=https://github.com/USTC-Hu-Group/KSSOLV-Toolbox
DefaultDirName={autopf}\KSSOLV Toolbox
DefaultGroupName=KSSOLV Toolbox
DisableWelcomePage=no
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=admin
; Always request UAC on launch; /CURRENTUSER must not bypass elevation.
PrivilegesRequiredOverridesAllowed=
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern light
WizardSizePercent=120,120
WizardBackColor=#ffffff
SetupIconFile={#Stage}\kssolv.ico
UninstallDisplayIcon={app}\KssolvLauncher.exe
OutputDir={#ReleaseDirectory}
OutputBaseFilename=KSSOLV_Toolbox_V{#AppVersion}
Compression=lzma2/fast
SolidCompression=yes
LicenseFile={#Repository}\LICENSE
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
Uninstallable=yes
#if RuntimeDelivery == "installer"
DiskSpanning=yes
#endif

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "zh"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[LangOptions]
en.DialogFontName=Segoe UI
zh.DialogFontName=Microsoft YaHei UI
DialogFontSize=9

[Messages]
en.WelcomeLabel1=KSSOLV Toolbox Setup
zh.WelcomeLabel1=KSSOLV Toolbox 安装向导
en.WelcomeLabel2=This wizard will install KSSOLV Toolbox on your computer.
zh.WelcomeLabel2=此向导将引导您完成 KSSOLV Toolbox 的安装。
en.FinishedHeadingLabel=Installation complete
zh.FinishedHeadingLabel=安装完成
en.FinishedLabel=KSSOLV Toolbox has been installed on your computer.%n%nClick Finish to close Setup.
zh.FinishedLabel=KSSOLV Toolbox 已成功安装到您的计算机。%n%n单击“完成”退出安装向导。
en.SelectDirLabel3=Setup will install KSSOLV Toolbox in the following folder.
zh.SelectDirLabel3=安装程序将把 KSSOLV Toolbox 安装到以下文件夹。
en.ReadyLabel1=Click Install to begin installing KSSOLV Toolbox.
zh.ReadyLabel1=单击“安装”开始安装 KSSOLV Toolbox。

[CustomMessages]
en.SetupTitle=KSSOLV Toolbox Setup
zh.SetupTitle=KSSOLV Toolbox 安装向导
en.SetupBody=This wizard will install KSSOLV Toolbox on your computer.%n%nClose other applications before continuing.%n%nClick Next to continue.
zh.SetupBody=此向导将引导您完成 KSSOLV Toolbox 的安装。%n%n建议您在继续之前关闭其他应用程序。%n%n单击“下一步”继续。
en.VersionLabel=Version {#AppVersion}
zh.VersionLabel=版本 {#AppVersion}
en.FolderLabel=Application folder
zh.FolderLabel=应用安装目录
en.FolderNote=Choose Browse to select a different local folder. The application and MATLAB Runtime can be installed on different drives.
zh.FolderNote=可单击“浏览”选择其他本地文件夹。软件与 MATLAB Runtime 支持安装到不同盘符。
en.RuntimeTitle=MATLAB Runtime
zh.RuntimeTitle=MATLAB Runtime 运行环境
en.RuntimeDescription=Choose where MATLAB Runtime lives. It can be on a different drive from the application.
zh.RuntimeDescription=选择 MATLAB Runtime 所在位置，可与应用安装在不同盘符。
en.RuntimePrompt=New Runtime installation folder (ASCII characters only):
zh.RuntimePrompt=新 Runtime 安装目录（仅支持 ASCII 字符）：
en.ReuseRuntime=Use the existing {#RuntimeRelease} Runtime
zh.ReuseRuntime=使用已安装的 {#RuntimeRelease} Runtime
en.RuntimeExisting=Existing Runtime: 
zh.RuntimeExisting=已有 Runtime：
en.RuntimeNote=MATLAB Runtime is required to run this application. It is shared with other MATLAB applications and kept when you uninstall KSSOLV Toolbox.
zh.RuntimeNote=MATLAB Runtime 是运行本软件所需的组件，可与其他 MATLAB 应用共享。卸载本软件时会保留该组件。
en.RuntimeLicense=I accept the MATLAB Runtime license agreement.
zh.RuntimeLicense=我接受 MATLAB Runtime 许可协议。
en.ViewRuntimeLicense=Read MATLAB Runtime license (PDF)
zh.ViewRuntimeLicense=阅读 MATLAB Runtime 许可协议（PDF）
en.RuntimeLicenseRequired=Read and accept the MATLAB Runtime license to continue.
zh.RuntimeLicenseRequired=请阅读并接受 MATLAB Runtime 许可协议后继续。
en.AsciiPath=MATLAB Runtime requires an absolute local folder containing only ASCII characters. Choose a path such as E:\MathWorks\MATLAB Runtime.
zh.AsciiPath=MATLAB Runtime 需要仅包含 ASCII 字符的本地绝对路径，例如 E:\MathWorks\MATLAB Runtime。
en.RuntimeMissing=This package requires an existing {#RuntimeRelease} MATLAB Runtime. Install the matching Runtime before continuing.
zh.RuntimeMissing=此安装包需要已安装的 {#RuntimeRelease} MATLAB Runtime，请先安装匹配版本后继续。
en.RuntimePreparing=Preparing MATLAB Runtime
zh.RuntimePreparing=正在配置 MATLAB Runtime
en.RuntimeWait=Downloading or installing the computation engine. This may take a while on the first installation.
zh.RuntimeWait=正在下载或安装计算引擎，首次安装可能需要较长时间。
en.RuntimeFailed=MATLAB Runtime installation failed. See the installation log:
zh.RuntimeFailed=MATLAB Runtime 安装失败，请查看安装日志：
en.WarmTitle=Completing installation
zh.WarmTitle=正在完成安装
en.WarmDescription=Please wait while Setup configures the application.
zh.WarmDescription=请稍候，安装程序正在配置应用程序。
en.WarmStatus=Configuring KSSOLV Toolbox...
zh.WarmStatus=正在配置 KSSOLV Toolbox……
en.WarmDetail=This may take several minutes. Please keep Setup open until installation is complete.
zh.WarmDetail=此过程可能需要几分钟。请保持安装程序开启，直至安装完成。
en.WarmFailed=Application configuration could not be completed. Click Retry to try again, or Cancel to exit Setup.%n%nFor details, see:
zh.WarmFailed=未能完成应用程序配置。单击“重试”再次尝试，或单击“取消”退出安装。%n%n详细信息：
en.FailedTitle=Installation incomplete
zh.FailedTitle=安装未完成
en.FailedDetail=Setup could not complete the application configuration. Review the installation log and run Setup again.
zh.FailedDetail=安装程序未能完成应用程序配置。请检查安装日志并重新运行安装程序。
en.LaunchApp=Open KSSOLV Toolbox
zh.LaunchApp=打开 KSSOLV Toolbox
en.DesktopShortcut=Create a desktop shortcut
zh.DesktopShortcut=创建桌面快捷方式
en.RuntimeSummary=MATLAB Runtime:
zh.RuntimeSummary=MATLAB Runtime：
en.UpgradeStatus=Removing the previous KSSOLV Toolbox installation...
zh.UpgradeStatus=正在卸载旧版 KSSOLV Toolbox……
en.UpgradeFailed=Could not check or remove previous KSSOLV Toolbox installations. Details:
zh.UpgradeFailed=无法完成旧版 KSSOLV Toolbox 的检查或卸载。详细信息：
en.UpgradeRestart=Restart Windows to finish removing the previous KSSOLV Toolbox installation, then run Setup again.
zh.UpgradeRestart=请重启 Windows 完成旧版 KSSOLV Toolbox 的卸载，然后重新运行安装程序。

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; Flags: unchecked

[Dirs]
Name: "{app}\installation-state"; Permissions: users-modify

[Files]
Source: "Remove-PreviousInstallation.ps1"; Flags: dontcopy
Source: "{#Application}"; DestDir: "{app}\application"; Flags: ignoreversion
Source: "{#Stage}\KssolvLauncher.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Stage}\Microsoft.Web.WebView2.Core.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Stage}\Microsoft.Web.WebView2.WinForms.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Stage}\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Stage}\WebView2-SDK-LICENSE.txt"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "{#Stage}\startup\*"; DestDir: "{app}\startup"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Stage}\kssolv.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Repository}\LICENSE"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "{#Repository}\THIRD-PARTY-LICENSES.md"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "{#Repository}\COMMERCIAL-LICENSE.md"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "matlabruntime_license_agreement.pdf"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "matlabruntime_license_agreement.pdf"; Flags: dontcopy
Source: "{#Stage}\brand-logo.bmp"; Flags: dontcopy
Source: "{#Stage}\installer-art.bmp"; Flags: dontcopy
#if RuntimeDelivery != "none"
  #if RuntimeIsZip == "0"
Source: "{#RuntimeInstaller}"; DestDir: "{tmp}\kssolv-runtime"; DestName: "setup.exe"; Flags: deleteafterinstall; Check: InstallNewRuntime
  #else
Source: "{#RuntimePayload}\*"; DestDir: "{tmp}\kssolv-runtime"; Flags: recursesubdirs createallsubdirs deleteafterinstall; Check: InstallNewRuntime
  #endif
#endif

[Icons]
Name: "{autoprograms}\KSSOLV Toolbox"; Filename: "{app}\KssolvLauncher.exe"; WorkingDir: "{app}"; IconFilename: "{app}\kssolv.ico"
Name: "{autodesktop}\KSSOLV Toolbox"; Filename: "{app}\KssolvLauncher.exe"; WorkingDir: "{app}"; IconFilename: "{app}\kssolv.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\KssolvLauncher.exe"; Description: "{cm:LaunchApp}"; Flags: postinstall nowait skipifsilent runasoriginaluser; Check: CanLaunch

[UninstallDelete]
Type: files; Name: "{app}\launcher.ini"
Type: filesandordirs; Name: "{app}\installation-state"

[Code]
const
  ThemeRail = $00FAF6F3;
  ThemeText = $003B3026;
  ThemeMuted = $00746759;
  ThemeBorder = $00E8E2DA;
  DesignRailWidth = 200;
  DesignContentWidth = 560;
  DesignInset = 32;
  DesignBodyWidth = 496;
var
  RuntimePage: TInputDirWizardPage;
  ReuseRuntime, AcceptRuntime: TNewCheckBox;
  RuntimeHint, RuntimeNotes, LicenseLink: TNewStaticText;
  PreparationPage: TOutputMarqueeProgressWizardPage;
  WarmDetail: TNewStaticText;
  Sidebar: TPanel;
  ExistingRuntime, ResolvedRuntime, SuggestedRuntime: String;
  WarmSucceeded: Boolean;
  WarmAttempt: Integer;
  UpgradeAttempt: Integer;

function NewLabel(Parent: TWinControl; Caption: String; X, Y, W, H, Size: Integer; Color: TColor): TNewStaticText;
begin
  Result := TNewStaticText.Create(WizardForm);
  Result.Parent := Parent;
  Result.AutoSize := False;
  Result.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(W), ScaleY(H));
  Result.Caption := Caption;
  Result.ShowAccelChar := False;
  Result.Font.Name := WizardForm.Font.Name;
  Result.Font.Size := Size;
  Result.Font.Color := Color;
  Result.StyleElements := [];
  Result.Color := clWhite;
  if Parent is TPanel then Result.Color := TPanel(Parent).Color;
  Result.WordWrap := True;
end;

function RuntimeIsUsable(Root: String): Boolean;
begin
  Result := FileExists(AddBackslash(Root) + 'runtime\win64\mclmcrrt{#StringChange(RuntimeVersion, ".", "_")}.dll')
    and FileExists(AddBackslash(Root) + 'bin\win64\MATLABWindow.exe');
end;

function InstallNewRuntime: Boolean;
begin
  Result := not (ReuseRuntime.Checked and RuntimeIsUsable(ExistingRuntime));
end;

function CanLaunch: Boolean;
begin
  Result := WarmSucceeded;
end;

function GetCustomSetupExitCode: Integer;
begin
  if WarmSucceeded then Result := 0 else Result := 1;
end;

procedure RuntimeSelectionChanged(Sender: TObject);
begin
  RuntimePage.Edits[0].Enabled := not ReuseRuntime.Checked;
  RuntimePage.Buttons[0].Enabled := not ReuseRuntime.Checked;
end;

procedure ShowRuntimeLicense(Sender: TObject);
var ResultCode: Integer;
begin
  ExtractTemporaryFile('matlabruntime_license_agreement.pdf');
  ShellExecAsOriginalUser('open', ExpandConstant('{tmp}\matlabruntime_license_agreement.pdf'), '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
end;

#include "Design.iss"

procedure InitializeWizard;
begin
  InitializeDesign;

  RuntimePage := CreateInputDirPage(wpSelectTasks, CustomMessage('RuntimeTitle'),
    CustomMessage('RuntimeDescription'), CustomMessage('RuntimePrompt'), False, '');
  RuntimePage.Add('MATLAB Runtime {#RuntimeRelease}');
  ExistingRuntime := '';
  RegQueryStringValue(HKLM64, 'SOFTWARE\MathWorks\MATLAB Runtime\{#RuntimeVersion}', 'MATLABROOT', ExistingRuntime);
  if not RuntimeIsUsable(ExistingRuntime) then ExistingRuntime := '';
  SuggestedRuntime := ExpandConstant('{autopf}\MATLAB\MATLAB Runtime');
  RuntimePage.Values[0] := ExpandConstant('{param:RUNTIMEFOLDER|}') ;
  if RuntimePage.Values[0] = '' then RuntimePage.Values[0] := SuggestedRuntime;
  ReuseRuntime := TNewCheckBox.Create(WizardForm);
  ReuseRuntime.Parent := RuntimePage.Surface;
  ReuseRuntime.SetBounds(0, ScaleY(110), RuntimePage.SurfaceWidth, ScaleY(28));
  ReuseRuntime.Caption := CustomMessage('ReuseRuntime');
  ReuseRuntime.Enabled := ExistingRuntime <> '';
  ReuseRuntime.Checked := (ExistingRuntime <> '') and (ExpandConstant('{param:REUSERUNTIME|yes}') <> 'no');
  ReuseRuntime.OnClick := @RuntimeSelectionChanged;
  RuntimeHint := NewLabel(RuntimePage.Surface, CustomMessage('RuntimeExisting') + ExistingRuntime, 0, 144, 430, 52, 9, $006A635B);
  RuntimeNotes := NewLabel(RuntimePage.Surface, CustomMessage('RuntimeNote'), 0, 206, 430, 66, 10, $006A635B);
  LicenseLink := NewLabel(RuntimePage.Surface, CustomMessage('ViewRuntimeLicense'), 0, 278, 430, 28, 10, $007A7042);
  LicenseLink.Font.Style := [fsUnderline];
  LicenseLink.Cursor := crHand;
  LicenseLink.OnClick := @ShowRuntimeLicense;
  AcceptRuntime := TNewCheckBox.Create(WizardForm);
  AcceptRuntime.Parent := RuntimePage.Surface;
  AcceptRuntime.SetBounds(0, ScaleY(310), RuntimePage.SurfaceWidth, ScaleY(32));
  AcceptRuntime.Caption := CustomMessage('RuntimeLicense');
  { Silent invocation is an explicit operator acknowledgement, never an implicit GUI default. }
  AcceptRuntime.Checked := ExpandConstant('{param:ACCEPTRUNTIMELICENSE|no}') = 'yes';
  LayoutRuntimePage;
  RuntimeSelectionChanged(nil);

  PreparationPage := CreateOutputMarqueeProgressPage(CustomMessage('WarmTitle'), CustomMessage('WarmDescription'));
  WarmDetail := NewLabel(PreparationPage.Surface, CustomMessage('WarmDetail'), 0, 110, 430, 220, 11, $006A635B);
  LayoutPreparationPage;
end;

procedure CurPageChanged(CurPageID: Integer);
var Drive: String;
begin
  if (CurPageID = wpFinished) and not WarmSucceeded then begin
    WizardForm.FinishedHeadingLabel.Caption := CustomMessage('FailedTitle');
    WizardForm.FinishedLabel.Caption := CustomMessage('FailedDetail');
    WizardForm.RunList.Visible := False;
  end;
  if (CurPageID = RuntimePage.ID) and (RuntimePage.Values[0] = SuggestedRuntime)
    and (ExpandConstant('{param:RUNTIMEFOLDER|}') = '') then begin
    Drive := ExtractFileDrive(WizardDirValue);
    if Drive <> '' then begin
      SuggestedRuntime := Drive + '\MathWorks\MATLAB Runtime';
      RuntimePage.Values[0] := SuggestedRuntime;
    end;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var Path: String; I: Integer;
begin
  Result := True;
  if CurPageID <> RuntimePage.ID then Exit;
  if not AcceptRuntime.Checked then begin
    MsgBox(CustomMessage('RuntimeLicenseRequired'), mbError, MB_OK); Result := False; Exit;
  end;
#if RuntimeDelivery == "none"
  if InstallNewRuntime then begin
    MsgBox(CustomMessage('RuntimeMissing'), mbError, MB_OK); Result := False; Exit;
  end;
#endif
  if not InstallNewRuntime then Exit;
  Path := RuntimePage.Values[0];
  Result := (Length(Path) >= 3) and (Copy(Path, 2, 2) = ':\');
  for I := 1 to Length(Path) do if Ord(Path[I]) > 127 then Result := False;
  if not Result then MsgBox(CustomMessage('AsciiPath'), mbError, MB_OK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Path, PowerShell, Parameters, UpgradeLog, UserLogDirectory: String; I, J, Code: Integer; Success: Boolean; UpgradeText: TArrayOfString;
begin
  Result := '';
  if not AcceptRuntime.Checked then Result := CustomMessage('RuntimeLicenseRequired');
  if InstallNewRuntime then begin
    Path := RuntimePage.Values[0];
    if (Length(Path) < 3) or (Copy(Path, 2, 2) <> ':\') then Result := CustomMessage('AsciiPath');
    for I := 1 to Length(Path) do if Ord(Path[I]) > 127 then Result := CustomMessage('AsciiPath');
  end;
#if RuntimeDelivery == "none"
  if InstallNewRuntime then Result := CustomMessage('RuntimeMissing');
#endif
  if Result <> '' then Exit;
  ExtractTemporaryFile('Remove-PreviousInstallation.ps1');
  PowerShell := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  WizardForm.StatusLabel.Caption := CustomMessage('UpgradeStatus');
  UpgradeAttempt := UpgradeAttempt + 1;
  UserLogDirectory := ExpandConstant('{tmp}\upgrade-user-') + IntToStr(UpgradeAttempt);
  UpgradeLog := ExpandConstant('{tmp}\kssolv-upgrade-prepare.log');
  { Keep executable code protected; only original-user diagnostic logs are writable. }
  Parameters := '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
    + ExpandConstant('{tmp}\Remove-PreviousInstallation.ps1') + '" -PrepareUserLogDirectory "' + UserLogDirectory
    + '" -LogPath "' + UpgradeLog + '"';
  Success := Exec(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code);
  Log(Format('KSSOLV_UPGRADE_LOG_PREPARE started=%d result=%d', [Ord(Success), Code]));
  if LoadStringsFromFile(UpgradeLog, UpgradeText) then
    for J := 0 to GetArrayLength(UpgradeText) - 1 do Log(UpgradeText[J]);
  if not Success or (Code <> 0) then begin
    if not Success then Log('Upgrade log preparation launch error: ' + SysErrorMessage(Code));
    Result := CustomMessage('UpgradeFailed') + #13#10 + ExpandConstant('{log}');
    Exit;
  end;
  { The per-user uninstall must run as the original user, even after UAC. }
  for I := 0 to 1 do begin
    if I = 0 then Path := 'User' else Path := 'Machine';
    if I = 0 then UpgradeLog := UserLogDirectory + '\kssolv-upgrade-User.log'
    else UpgradeLog := ExpandConstant('{tmp}\kssolv-upgrade-Machine.log');
    Log('KSSOLV_UPGRADE_START scope=' + Path);
    Parameters := '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
      + ExpandConstant('{tmp}\Remove-PreviousInstallation.ps1') + '" -Scope ' + Path + ' -LogPath "' + UpgradeLog + '"';
    if I = 1 then Parameters := Parameters + ' -TargetDirectory "' + WizardDirValue + '"';
    if I = 0 then Success := ExecAsOriginalUser(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code)
    else Success := Exec(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code);
    Log(Format('KSSOLV_UPGRADE_RESULT scope=%s started=%d result=%d', [Path, Ord(Success), Code]));
    if LoadStringsFromFile(UpgradeLog, UpgradeText) then
      for J := 0 to GetArrayLength(UpgradeText) - 1 do Log(UpgradeText[J])
    else Log('Upgrade helper produced no log: ' + UpgradeLog);
    if not Success then Log('Upgrade helper launch error: ' + SysErrorMessage(Code));
    if Success and (Code = 3010) then begin
      NeedsRestart := True;
      Result := CustomMessage('UpgradeRestart');
      Exit;
    end;
    if not Success or (Code <> 0) then begin
      Result := CustomMessage('UpgradeFailed') + #13#10 + ExpandConstant('{log}');
      Exit;
    end;
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var Root: String;
begin
  if InstallNewRuntime then Root := AddBackslash(RuntimePage.Values[0]) + '{#RuntimeRelease}'
  else Root := ExistingRuntime;
  Result := MemoDirInfo + NewLine + NewLine + CustomMessage('RuntimeSummary') + NewLine + Space + Root
    + NewLine + NewLine + MemoTasksInfo;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var Code, Answer: Integer; LogFile, StatusFile, Parameters, Config: String; StatusText: AnsiString;
begin
  if CurStep <> ssPostInstall then Exit;
  PreparationPage.Show;
  PreparationPage.Animate;
  try
    if InstallNewRuntime then begin
      PreparationPage.SetText(CustomMessage('RuntimePreparing'), CustomMessage('RuntimeWait'));
      PreparationPage.SetProgress(0, 0);
      WarmDetail.Caption := CustomMessage('RuntimeWait');
      LogFile := ExpandConstant('{app}\installation-state\runtime-install.log');
#if RuntimeDelivery != "none"
      Parameters := '-agreeToLicense yes -runtimeFolder "' + RuntimePage.Values[0] + '" -outputFile "' + LogFile + '"';
      if not Exec(ExpandConstant('{tmp}\kssolv-runtime\{#RuntimeEntryPoint}'), Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code)
        or (Code <> 0) then RaiseException(CustomMessage('RuntimeFailed') + #13#10 + LogFile);
#endif
      ResolvedRuntime := AddBackslash(RuntimePage.Values[0]) + '{#RuntimeRelease}';
    end else ResolvedRuntime := ExistingRuntime;
    if not RuntimeIsUsable(ResolvedRuntime) then RaiseException(CustomMessage('RuntimeMissing') + #13#10 + ResolvedRuntime);

    Config := 'RuntimeRoot=' + ResolvedRuntime + #13#10 + 'RuntimeRelease={#RuntimeRelease}' + #13#10
      + 'RuntimeVersion={#RuntimeVersion}' + #13#10 + 'Version={#AppVersion}' + #13#10 + 'BuildHash={#BuildHash}' + #13#10
      + 'Language=' + ActiveLanguage + #13#10;
    if not SaveStringToFile(ExpandConstant('{app}\launcher.ini'), Config, False) then RaiseException('Cannot write launcher.ini');
    PreparationPage.SetText(CustomMessage('WarmStatus'), '');
    WarmDetail.Caption := CustomMessage('WarmDetail');
    Log('KSSOLV_PREWARM_START user-context=original-user');
    repeat
      WarmAttempt := WarmAttempt + 1;
      StatusFile := ExpandConstant('{app}\installation-state\prewarm-')
        + GetDateTimeString('yyyymmddhhnnss', #0, #0) + '-' + IntToStr(WarmAttempt) + '.json';
      if FileExists(StatusFile) then DeleteFile(StatusFile);
      Parameters := '--prewarm --language ' + ActiveLanguage + ' --result "' + StatusFile + '"';
      WarmSucceeded := ExecAsOriginalUser(ExpandConstant('{app}\KssolvLauncher.exe'), Parameters,
        ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, Code);
      if WarmSucceeded then WarmSucceeded := Code = 0;
      if WarmSucceeded then WarmSucceeded := LoadStringFromFile(StatusFile, StatusText);
      if WarmSucceeded then WarmSucceeded := (Pos('"status":"success"', StatusText) > 0)
        and (Pos('{#BuildHash}', StatusText) > 0);
      if not WarmSucceeded then begin
        Log('KSSOLV_PREWARM_FAILED exit=' + IntToStr(Code) + ' status=' + StatusFile);
        if WizardSilent then RaiseException(CustomMessage('WarmFailed') + #13#10 + StatusFile);
        Answer := MsgBox(CustomMessage('WarmFailed') + #13#10 + StatusFile, mbError, MB_RETRYCANCEL);
        if Answer <> IDRETRY then RaiseException(CustomMessage('WarmFailed'));
      end;
    until WarmSucceeded;
    Log('KSSOLV_INSTALL_PREWARM_OK ' + StatusFile);
    PreparationPage.SetProgress(100, 100);
  finally
    PreparationPage.Hide;
  end;
end;
