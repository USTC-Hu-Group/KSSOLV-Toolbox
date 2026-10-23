procedure TryRemovePreviousInstallations;
var Scope, PowerShell, Parameters, UpgradeLog, UserLogDirectory: String;
  I, J, Code: Integer; Success: Boolean; UpgradeText: TArrayOfString;
begin
  try
    ExtractTemporaryFile('Remove-PreviousInstallation.ps1');
    PowerShell := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
    WizardForm.StatusLabel.Caption := CustomMessage('UpgradeStatus');
    UpgradeAttempt := UpgradeAttempt + 1;
    UserLogDirectory := ExpandConstant('{tmp}\upgrade-user-') + IntToStr(UpgradeAttempt);
    UpgradeLog := ExpandConstant('{tmp}\kssolv-upgrade-prepare.log');
    Parameters := '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
      + ExpandConstant('{tmp}\Remove-PreviousInstallation.ps1') + '" -PrepareUserLogDirectory "' + UserLogDirectory
      + '" -LogPath "' + UpgradeLog + '"';
    Success := Exec(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code);
    Log(Format('KSSOLV_UPGRADE_LOG_PREPARE started=%d result=%d', [Ord(Success), Code]));
    if LoadStringsFromFile(UpgradeLog, UpgradeText) then
      for J := 0 to GetArrayLength(UpgradeText) - 1 do Log(UpgradeText[J]);
    if not Success or (Code <> 0) then begin
      if not Success then Log('Upgrade log preparation launch error: ' + SysErrorMessage(Code));
      Log('KSSOLV_UPGRADE_SKIPPED preparation failed; continuing installation');
      ShowInstallerDiagnostic(CustomMessage('UpgradeSkipped'), False, True);
      Exit;
    end;
    for I := 0 to 1 do begin
      if I = 0 then Scope := 'User' else Scope := 'Machine';
      if I = 0 then UpgradeLog := UserLogDirectory + '\kssolv-upgrade-User.log'
      else UpgradeLog := ExpandConstant('{tmp}\kssolv-upgrade-Machine.log');
      Log('KSSOLV_UPGRADE_START scope=' + Scope);
      Parameters := '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
        + ExpandConstant('{tmp}\Remove-PreviousInstallation.ps1') + '" -Scope ' + Scope + ' -LogPath "' + UpgradeLog + '"'
        + ' -TargetDirectory "' + WizardDirValue + '"';
      if I = 0 then Success := ExecAsOriginalUser(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code)
      else Success := Exec(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, Code);
      Log(Format('KSSOLV_UPGRADE_RESULT scope=%s started=%d result=%d', [Scope, Ord(Success), Code]));
      if LoadStringsFromFile(UpgradeLog, UpgradeText) then
        for J := 0 to GetArrayLength(UpgradeText) - 1 do Log(UpgradeText[J])
      else Log('Upgrade helper produced no log: ' + UpgradeLog);
      if not Success or (Code <> 0) then begin
        if not Success then Log('Upgrade helper launch error: ' + SysErrorMessage(Code));
        if Success and (Code = 3010) then UpgradeNeedsRestart := True;
        Log('KSSOLV_UPGRADE_SKIPPED scope=' + Scope + '; continuing installation');
        ShowInstallerDiagnostic(CustomMessage('UpgradeSkipped'), False, True);
        Exit;
      end;
    end;
  except
    Log('KSSOLV_UPGRADE_SKIPPED ' + GetExceptionMessage + '; continuing installation');
    ShowInstallerDiagnostic(CustomMessage('UpgradeSkipped'), False, True);
  end;
end;
