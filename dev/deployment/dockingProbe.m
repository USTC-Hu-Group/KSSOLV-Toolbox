function dockingProbe(mode, outputFile)
% Bounded, isolated AppContainer/FigureDocument deployment probe.
arguments
    mode string = "fixed"
    outputFile string = fullfile(tempdir, "docking-probe.json")
end
events = {};
probeException = [];
started = tic;
result = struct('mode', mode, 'deployed', isdeployed, ...
    'release', version('-release'), 'version', version, 'stages', {{}});
try
    s = settings;
    result.dockSetting = s.matlab.ui.figure.DockFigureInDeployment.ActiveValue;
    if mode == "allow"
        s.matlab.ui.figure.DockFigureInDeployment.TemporaryValue = true;
    elseif mode == "fixed"
        kssolv.ui.util.configureFigureDocumentDocking();
    end
    result.effectiveDockSetting = s.matlab.ui.figure.DockFigureInDeployment.ActiveValue;
    app = matlab.ui.container.internal.AppContainer(struct( ...
        'Tag', 'DockingProbe', 'Title', 'Isolated figure docking probe', ...
        'ToolstripEnabled', false));
    cleanup = onCleanup(@() delete(app));
    group = matlab.ui.internal.FigureDocumentGroup(struct('Tag', 'Workflow'));
    app.add(group);
    app.Visible = true;
    pump(3);
    doc = matlab.ui.internal.FigureDocument(struct( ...
        'Tag', 'probe', 'Title', 'Workflow probe', ...
        'DocumentGroupTag', 'Workflow'));
    fig = doc.Figure;
    listeners = {addlistener(fig, 'WindowStyle', 'PostSet', @changed), ...
        addlistener(fig, 'FigureViewReady', 'PostSet', @changed)};
    result.stages{end+1} = snapshot("constructed");
    layout = uigridlayout(fig, [1 1]);
    layout.Padding = 0;
    html = uihtml(layout, 'HTMLSource', ...
        '<html><body><h2>Workflow probe</h2></body></html>');
    result.stages{end+1} = snapshot("controls-created");
    if mode == "preadd"
        fig.WindowStyle = 'docked';
        doc.Docked = true;
    end
    app.add(doc);
    result.stages{end+1} = snapshot("added");
    pump(6);
    result.stages{end+1} = snapshot("ready");
    if mode == "fixed"
        assert(doc.Docked && fig.WindowStyle == "docked", ...
            'KSSOLV:Probe:InitialUndock', 'Initial document must stay docked.');
        for index = 2:3
            extra = matlab.ui.internal.FigureDocument(struct( ...
                'Tag', "probe" + index, 'Title', "Probe " + index, ...
                'DocumentGroupTag', 'Workflow'));
            uilabel(extra.Figure, 'Text', 'Additional document');
            app.add(extra);
            pump(2);
            assert(extra.Docked && extra.Figure.WindowStyle == "docked", ...
                'KSSOLV:Probe:AdditionalUndock', 'Additional document must stay docked.');
        end
        result.multipleDocumentsDocked = true;
        doc.Docked = false;
        pump(2);
        result.intentionalUndockHonored = ~doc.Docked;
        assert(result.intentionalUndockHonored, ...
            'KSSOLV:Probe:UndockRejected', 'Intentional undocking must remain available.');
        doc.Docked = true;
        pump(3);
        result.stages{end+1} = snapshot("intentional-redock-settled");
        assert(doc.Docked && fig.WindowStyle == "docked", ...
            'KSSOLV:Probe:RedockRejected', 'Intentional redocking must remain stable.');
    end
    if mode == "redock"
        doc.Docked = true;
        result.stages{end+1} = snapshot("redock-requested");
        pump(4);
        result.stages{end+1} = snapshot("redock-settled");
    end
    result.contentWindowStyle = doc.Content.WindowStyle;
    result.figureCapabilityEmbedded = matlab.ui.internal.FigureCapability.hasCapability( ...
        fig, matlab.ui.internal.FigureCapability.Embedded);
    result.ignoreDockingRestriction = isprop(fig, 'IgnoreDockingRestriction');
    result.htmlValid = isvalid(html);
    delete(listeners{1});
    delete(listeners{2});
    clear cleanup;
catch exception
    probeException = exception;
    result.error = getReport(exception, 'extended', 'hyperlinks', 'off');
end
result.events = events;
fid = fopen(outputFile, 'w');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(result, PrettyPrint=true));
disp(jsonencode(result));
clear fileCleanup;
if ~isempty(probeException)
    rethrow(probeException);
end
    function pump(seconds)
        begin = tic;
        while toc(begin) < seconds
            drawnow;
            pause(0.05);
        end
    end
    function value = snapshot(stage)
        value = struct('stage', stage, 'time', toc(started), ...
            'docked', doc.Docked, 'windowStyle', string(fig.WindowStyle), ...
            'ready', fig.FigureViewReady);
    end
    function changed(src, ~)
        value = snapshot(string(src.Name));
        stack = dbstack;
        value.stack = {stack.name};
        events{end+1} = value;
    end
end
