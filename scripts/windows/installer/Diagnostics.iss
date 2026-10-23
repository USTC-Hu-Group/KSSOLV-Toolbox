procedure OpenInstallerLog(Sender: TObject);
var Code: Integer; LogPath: String;
begin
  LogPath := ExpandConstant('{log}');
  if not ShellExec('open', LogPath, '', '', SW_SHOWNORMAL, ewNoWait, Code) then
    MsgBox(CustomMessage('LogOpenFailed') + #13#10 + LogPath, mbError, MB_OK);
end;

function ShowInstallerDiagnostic(Message: String; AllowRetry, ContinueInstallation: Boolean): Integer;
var Dialog: TSetupForm; Body: TNewMemo; LogPath: TNewEdit;
  OpenLogButton, ConfirmButton, DismissButton: TNewButton;
begin
  Log('KSSOLV_INSTALL_DIAGNOSTIC ' + Message);
  Result := mrOk;
  if AllowRetry then Result := mrCancel;
  if WizardSilent then Exit;
  Dialog := CreateCustomForm(ScaleX(600), ScaleY(280), False, True);
  try
    Dialog.Caption := CustomMessage('SetupTitle');
    Dialog.Font.Name := WizardForm.Font.Name;
    Dialog.Font.Size := 10;
    Body := TNewMemo.Create(Dialog);
    Body.Parent := Dialog;
    Body.SetBounds(ScaleX(20), ScaleY(18), ScaleX(560), ScaleY(162));
    Body.ReadOnly := True;
    Body.ScrollBars := ssVertical;
    Body.Text := Message;
    LogPath := TNewEdit.Create(Dialog);
    LogPath.Parent := Dialog;
    LogPath.SetBounds(ScaleX(20), ScaleY(192), ScaleX(560), ScaleY(26));
    LogPath.ReadOnly := True;
    LogPath.Text := ExpandConstant('{log}');
    OpenLogButton := TNewButton.Create(Dialog);
    OpenLogButton.Parent := Dialog;
    OpenLogButton.SetBounds(ScaleX(20), ScaleY(234), ScaleX(130), ScaleY(28));
    OpenLogButton.Caption := CustomMessage('OpenLog');
    OpenLogButton.OnClick := @OpenInstallerLog;
    ConfirmButton := TNewButton.Create(Dialog);
    ConfirmButton.Parent := Dialog;
    ConfirmButton.SetBounds(ScaleX(450), ScaleY(234), ScaleX(130), ScaleY(28));
    ConfirmButton.Caption := CustomMessage('DiagnosticOK');
    if ContinueInstallation then ConfirmButton.Caption := CustomMessage('ContinueInstallation');
    ConfirmButton.ModalResult := mrOk;
    ConfirmButton.Default := True;
    ConfirmButton.Cancel := not AllowRetry;
    if AllowRetry then begin
      ConfirmButton.Left := ScaleX(308);
      ConfirmButton.Caption := CustomMessage('DiagnosticRetry');
      ConfirmButton.ModalResult := mrRetry;
      DismissButton := TNewButton.Create(Dialog);
      DismissButton.Parent := Dialog;
      DismissButton.SetBounds(ScaleX(450), ScaleY(234), ScaleX(130), ScaleY(28));
      DismissButton.Caption := CustomMessage('DiagnosticCancel');
      DismissButton.ModalResult := mrCancel;
      DismissButton.Cancel := True;
    end;
    Dialog.ActiveControl := ConfirmButton;
    Dialog.FlipAndCenterIfNeeded(True, WizardForm, False);
    Result := Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;
