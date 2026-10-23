{ Logical pixels, scaled once by Inno for the selected font and display DPI. }
procedure SetBodyFont(Font: TFont);
begin
  Font.Name := WizardForm.Font.Name;
  Font.Size := ThemeBodyFontSize;
  Font.Style := [];
end;

function NewPanel(Parent: TWinControl; X, Y, W, H: Integer; Color: TColor): TPanel;
begin
  Result := TPanel.Create(WizardForm);
  Result.Parent := Parent;
  Result.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(W), ScaleY(H));
  Result.BevelOuter := bvNone;
  Result.StyleElements := [];
  Result.Color := Color;
end;

procedure SetTextBounds(LabelControl: TNewStaticText; X, Y, W, H, FontSize: Integer);
begin
  LabelControl.AutoSize := False;
  LabelControl.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(W), ScaleY(H));
  LabelControl.Font.Size := FontSize;
  LabelControl.Font.Name := WizardForm.Font.Name;
  LabelControl.WordWrap := True;
  LabelControl.StyleElements := [];
  LabelControl.Color := clWhite;
  LabelControl.Font.Color := ThemeMuted;
end;

procedure AddBrandImage(FileName: String; X, Y, W, H: Integer);
var Image: TBitmapImage;
begin
  ExtractTemporaryFile(FileName);
  Image := TBitmapImage.Create(WizardForm);
  Image.Parent := Sidebar;
  Image.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(W), ScaleY(H));
  Image.Bitmap.LoadFromFile(ExpandConstant('{tmp}\') + FileName);
  Image.Stretch := True;
end;

procedure InitializeDesign;
var W, H: Integer;
begin
  WizardForm.ClientWidth := ScaleX(760);
  WizardForm.ClientHeight := ScaleY(480);
  WizardForm.Color := clWhite;
  { Native controls keep their own fonts; normalize them explicitly too. }
  SetBodyFont(WizardForm.LicenseMemo.Font);
  SetBodyFont(WizardForm.LicenseAcceptedRadio.Font);
  SetBodyFont(WizardForm.LicenseNotAcceptedRadio.Font);
  SetBodyFont(WizardForm.BackButton.Font);
  SetBodyFont(WizardForm.NextButton.Font);
  SetBodyFont(WizardForm.CancelButton.Font);
  SetBodyFont(WizardForm.DirEdit.Font);
  SetBodyFont(WizardForm.DirBrowseButton.Font);
  SetBodyFont(WizardForm.TasksList.Font);
  SetBodyFont(WizardForm.ReadyMemo.Font);
  SetBodyFont(WizardForm.RunList.Font);
  WizardForm.OuterNotebook.SetBounds(ScaleX(DesignRailWidth), 0,
    ScaleX(DesignContentWidth), ScaleY(420));
  WizardForm.MainPanel.SetBounds(0, 0, ScaleX(DesignContentWidth), ScaleY(88));
  WizardForm.InnerNotebook.SetBounds(ScaleX(DesignInset), ScaleY(104),
    ScaleX(DesignBodyWidth), ScaleY(300));
  WizardForm.WizardBitmapImage.Visible := False;
  WizardForm.WizardBitmapImage2.Visible := False;
  WizardForm.WizardSmallBitmapImage.Visible := False;
  WizardForm.Bevel1.Visible := False;
  WizardForm.Bevel.Visible := False;
  SetTextBounds(WizardForm.PageNameLabel, DesignInset, 24, DesignBodyWidth, 30, ThemeHeadingFontSize);
  WizardForm.PageNameLabel.Font.Style := [fsBold];
  WizardForm.PageNameLabel.Font.Color := ThemeText;
  SetTextBounds(WizardForm.PageDescriptionLabel, DesignInset, 60, DesignBodyWidth, 28, ThemeBodyFontSize);

  NewPanel(WizardForm, DesignRailWidth, 420, DesignContentWidth, 1, ThemeBorder);
  WizardForm.CancelButton.SetBounds(ScaleX(646), ScaleY(436), ScaleX(82), ScaleY(28));
  WizardForm.NextButton.SetBounds(ScaleX(552), ScaleY(436), ScaleX(82), ScaleY(28));
  WizardForm.BackButton.SetBounds(ScaleX(458), ScaleY(436), ScaleX(82), ScaleY(28));

  Sidebar := NewPanel(WizardForm, 0, 0, DesignRailWidth, 480, ThemeRail);
  AddBrandImage('brand-logo.bmp', 36, 18, 128, 128);
  AddBrandImage('installer-art.bmp', 0, 150, 200, 267);
  NewPanel(WizardForm, DesignRailWidth - 1, 0, 1, 480, ThemeBorder);
  NewLabel(Sidebar, 'KSSOLV Toolbox', 24, 432, 168, 20, ThemeBodyFontSize, ThemeText);
  NewLabel(Sidebar, CustomMessage('VersionLabel'), 24, 453, 168, 18, ThemeBodyFontSize, ThemeMuted);

  SetTextBounds(WizardForm.WelcomeLabel1, DesignInset, 72, DesignBodyWidth, 68, ThemeHeadingFontSize);
  WizardForm.WelcomeLabel1.Caption := CustomMessage('SetupTitle');
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];
  WizardForm.WelcomeLabel1.Font.Color := ThemeText;
  SetTextBounds(WizardForm.WelcomeLabel2, DesignInset, 166, DesignBodyWidth, 150, ThemeBodyFontSize);
  WizardForm.WelcomeLabel2.Caption := CustomMessage('SetupBody');
  W := DesignBodyWidth;
  H := 300;
  SetTextBounds(WizardForm.LicenseLabel1, 0, 0, W, 36, ThemeBodyFontSize);
  WizardForm.LicenseMemo.SetBounds(0, ScaleY(44), ScaleX(W), ScaleY(H - 100));
  WizardForm.LicenseAcceptedRadio.SetBounds(0, ScaleY(H - 46), ScaleX(W), ScaleY(22));
  WizardForm.LicenseNotAcceptedRadio.SetBounds(0, ScaleY(H - 22), ScaleX(W), ScaleY(22));
  WizardForm.SelectDirBitmapImage.Visible := False;
  SetTextBounds(WizardForm.SelectDirLabel, 0, 0, W, 44, ThemeBodyFontSize);
  SetTextBounds(WizardForm.SelectDirBrowseLabel, 0, 72, W, 24, ThemeBodyFontSize);
  WizardForm.SelectDirBrowseLabel.Caption := CustomMessage('FolderLabel');
  WizardForm.DirEdit.AutoSize := False;
  WizardForm.DirEdit.SetBounds(0, ScaleY(102), ScaleX(W - 100), ScaleY(28));
  WizardForm.DirBrowseButton.SetBounds(ScaleX(W - 88), ScaleY(102), ScaleX(88), ScaleY(28));
  NewLabel(WizardForm.SelectDirPage, CustomMessage('FolderNote'), 0, 162, W, 70, ThemeBodyFontSize, ThemeMuted);
  SetTextBounds(WizardForm.DiskSpaceLabel, 0, H - 24, W, 24, ThemeBodyFontSize);
  SetTextBounds(WizardForm.SelectTasksLabel, 0, 0, W, 36, ThemeBodyFontSize);
  WizardForm.TasksList.SetBounds(0, ScaleY(48), ScaleX(W), ScaleY(H - 48));
  SetTextBounds(WizardForm.ReadyLabel, 0, 0, W, 36, ThemeBodyFontSize);
  WizardForm.ReadyMemo.SetBounds(0, ScaleY(48), ScaleX(W), ScaleY(H - 48));
  SetTextBounds(WizardForm.StatusLabel, 0, 0, W, 30, ThemeBodyFontSize);
  WizardForm.StatusLabel.Font.Color := ThemeText;
  SetTextBounds(WizardForm.FilenameLabel, 0, 40, W, 44, ThemeBodyFontSize);
  WizardForm.ProgressGauge.SetBounds(0, ScaleY(100), ScaleX(W), ScaleY(8));
  SetTextBounds(WizardForm.FinishedHeadingLabel, DesignInset, 72, W, 68, ThemeHeadingFontSize);
  WizardForm.FinishedHeadingLabel.Font.Style := [fsBold];
  WizardForm.FinishedHeadingLabel.Font.Color := ThemeText;
  SetTextBounds(WizardForm.FinishedLabel, DesignInset, 166, W, 110, ThemeBodyFontSize);
  WizardForm.RunList.SetBounds(ScaleX(DesignInset), ScaleY(300), ScaleX(W), ScaleY(86));
end;

procedure LayoutRuntimePage;
begin
  SetBodyFont(ReuseRuntime.Font);
  SetBodyFont(AcceptRuntime.Font);
  SetBodyFont(RuntimePage.PromptLabels[0].Font);
  SetBodyFont(RuntimePage.Edits[0].Font);
  SetBodyFont(RuntimePage.Buttons[0].Font);
  RuntimePage.SubCaptionLabel.Visible := False;
  ReuseRuntime.SetBounds(0, 0, ScaleX(DesignBodyWidth), ScaleY(22));
  RuntimeHint.SetBounds(0, ScaleY(30), ScaleX(DesignBodyWidth), ScaleY(44));
  RuntimePage.PromptLabels[0].SetBounds(0, ScaleY(82), ScaleX(DesignBodyWidth), ScaleY(24));
  RuntimePage.Edits[0].AutoSize := False;
  RuntimePage.Edits[0].SetBounds(0, ScaleY(112), ScaleX(DesignBodyWidth - 100), ScaleY(28));
  RuntimePage.Buttons[0].SetBounds(ScaleX(DesignBodyWidth - 88), ScaleY(112), ScaleX(88), ScaleY(28));
  RuntimeNotes.SetBounds(0, ScaleY(162), ScaleX(DesignBodyWidth), ScaleY(48));
  LicenseLink.SetBounds(0, ScaleY(230), ScaleX(DesignBodyWidth), ScaleY(22));
  AcceptRuntime.SetBounds(0, ScaleY(274), ScaleX(DesignBodyWidth), ScaleY(22));
end;

procedure LayoutPreparationPage;
begin
  SetTextBounds(PreparationPage.Msg1Label, 0, 0, DesignBodyWidth, 40, ThemeBodyFontSize);
  PreparationPage.Msg1Label.Font.Color := ThemeText;
  PreparationPage.Msg2Label.Visible := False;
  PreparationPage.ProgressBar.SetBounds(0, ScaleY(64), ScaleX(DesignBodyWidth), ScaleY(8));
  WarmDetail.SetBounds(0, ScaleY(106), ScaleX(DesignBodyWidth), ScaleY(150));
end;
