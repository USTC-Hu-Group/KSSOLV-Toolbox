function report = CrystalViewerStartup(prewarm)
%CRYSTALVIEWERSTARTUP Time opening a real structure through its first frame.
% Run false/true in separate fresh MATLAB -nojvm processes for cold comparison.
arguments
    prewarm (1,1) logical = true
end
app = matlab.ui.container.internal.AppContainer(struct('Title', 'Crystal Startup Benchmark'));
previous = kssolv.ui.util.DataStorage.getData('AppContainer');
host = [];
warmer = [];
display = [];
html = [];
resources = containers.Map({'app', 'previous', 'host', 'warmer', 'display', 'html'}, ...
    {app, previous, host, warmer, display, html}, 'UniformValues', false);
cleanup = onCleanup(@() cleanupAll(resources));
kssolv.ui.util.DataStorage.setData('AppContainer', app);
app.Visible = true;
drawnow;
prewarmMilliseconds = 0;
if prewarm
    host = uifigure('Visible', 'on', 'Name', 'Background prewarm benchmark');
    resources('host') = host;
    warmer = kssolv.ui.util.CrystalViewerPrewarm(host);
    resources('warmer') = warmer;
    started = tic;
    while ~warmer.IsReady && warmer.LastError == "" && toc(started) < 30
        pause(.01);
    end
    assert(warmer.IsReady, 'Prewarm failed: %s', warmer.LastError);
    prewarmMilliseconds = toc(started) * 1000;
end
fixture = fullfile(KSSOLV_Toolbox.RootDirectory, '+kssolv', '+analysis', ...
    '+matgenlab', '+test', '+core', '+fixtures', '+local_env', 'LiFePO4.json');
model = kssolv.analysis.matgenlab.core.Structure.from_file(fixture);
model = model.add_oxidation_state_by_guess();
firstFrameMilliseconds = NaN;
completeMilliseconds = NaN;
errors = strings(1, 0);
started = tic;
display = kssolv.ui.components.figuredocument.MoleculeDisplay(model);
resources('display') = display;
display.Display();
documentOpenMilliseconds = toc(started) * 1000;
html = findall(display.Document.Figure, '-isa', 'matlab.ui.control.HTML');
resources('html') = html; %#ok<NASGU> The cleanup retains this mutable Map handle.
original = html.HTMLEventReceivedFcn;
html.HTMLEventReceivedFcn = @receive;
while isnan(completeMilliseconds) && toc(started) < 30
    pause(.01);
    drawnow;
end
assert(isfinite(completeMilliseconds), 'No complete scene. Errors: %s', join(errors, newline));
assert(isempty(errors), 'Viewer errors: %s', join(errors, newline));
report = struct('prewarm', prewarm, 'prewarmMilliseconds', prewarmMilliseconds, ...
    'documentOpenMilliseconds', documentOpenMilliseconds, ...
    'firstFrameMilliseconds', firstFrameMilliseconds, ...
    'completeMilliseconds', completeMilliseconds);
disp(struct2table(report));
clear cleanup

    function receive(src, event)
        original(src, event);
        if string(event.HTMLEventName) == "viewer:sceneRendered"
            data = event.HTMLEventData;
            if ischar(data) || isstring(data), data = jsondecode(data); end
            if startsWith(string(data.requestId), "initial-")
                firstFrameMilliseconds = toc(started) * 1000;
            else
                completeMilliseconds = toc(started) * 1000;
            end
        elseif string(event.HTMLEventName) == "viewer:error"
            errors(end + 1) = string(jsonencode(event.HTMLEventData));
        end
    end

end

function cleanupAll(resources)
% Capture the resource registry so error unwinding cannot clear UI handles first.
html = resources('html');
display = resources('display');
warmer = resources('warmer');
host = resources('host');
app = resources('app');
if ~isempty(html) && isvalid(html), html.HTMLEventReceivedFcn = []; end
if ~isempty(display) && isvalid(display)
    display.prepareForShutdown();
    document = display.Document;
    if ~isempty(document) && isvalid(document), delete(document); end
    delete(display);
end
if ~isempty(warmer) && isvalid(warmer), delete(warmer); end
if ~isempty(host) && isvalid(host), delete(host); end
if isvalid(app), delete(app); end
kssolv.ui.util.DataStorage.setData('AppContainer', resources('previous'));
end
