function configureFigureDocumentDocking()
%CONFIGUREFIGUREDOCUMENTDOCKING Allow AppContainer documents in Runtime.
% Runtime otherwise coerces Figure.WindowStyle="docked" to "normal",
% including embedded FigureDocuments. The client then propagates that value
% back to Document.Docked, undoing a render-time redock. Configure the session
% before constructing any FigureDocuments or FigurePanels.

if ~isdeployed
    return
end

try
    rootSettings = settings;
    rootSettings.matlab.ui.figure.DockFigureInDeployment.TemporaryValue = true;
catch exception
    % This is an internal MathWorks setting. Retain the existing per-document
    % compatibility fallback for releases that do not provide it.
    warning('KSSOLV:UI:FigureDocumentDockingUnavailable', ...
        'Cannot enable Runtime figure document docking: %s', exception.message);
end
end
