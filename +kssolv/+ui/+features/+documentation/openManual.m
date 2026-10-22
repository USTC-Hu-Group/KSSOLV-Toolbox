function openManual()
%OPENMANUAL Open the localized manual with the desktop's default PDF viewer.
% Online actions are handled in the client browser, not on the server desktop.
if isKSSOLVOnline(), return, end
kssolv.ui.util.openWithSystemDefault( ...
    kssolv.ui.features.documentation.manualPath());
end
