function report = CrystalViewerEndToEnd(enforce)
%CRYSTALVIEWERENDTOEND Measure real uihtml/CEF/WebGL scene-to-frame latency.
if nargin < 1, enforce = true; end

runtime = fullfile(KSSOLV_Toolbox.RootDirectory, "+kssolv", "+ui", ...
    "+components", "+figuredocument", "@MoleculeDisplay", ...
    "CrystalViewer", "index.html");
if ~isfile(runtime)
    error("KSSOLV:CrystalViewer:RuntimeMissing", ...
        "Build and sync the Crystal Viewer runtime before benchmarking.");
end

% Match MoleculeDisplay's cache-busting source staging.  More importantly,
% register the MATLAB callback before assigning HTMLSource: the optimized
% viewer can emit its one-shot viewer:ready event before a callback assigned
% after construction has become active.
stagedRuntime = string(tempname) + ".html";
[copied, copyMessage] = copyfile(runtime, stagedRuntime, "f");
if ~copied
    error("KSSOLV:CrystalViewer:HTMLSource", ...
        "Unable to stage the benchmark viewer: %s", copyMessage);
end
runtimeCleanup = onCleanup(@()deleteIfPresent(stagedRuntime)); %#ok<NASGU>

ready = false;
rendered = containers.Map("KeyType", "char", "ValueType", "any");
clientErrors = strings(1, 0);
receivedEvents = strings(1, 0);
% uihtml defers Chromium creation while its figure is hidden, so the real
% end-to-end benchmark must briefly display an actual viewer surface.
figureHandle = uifigure("Visible", "on", ...
    "Position", [100, 100, 1000, 720], ...
    "Name", "KSSOLV Crystal Viewer benchmark");
cleanup = onCleanup(@()deleteIfValid(figureHandle)); %#ok<NASGU>
html = uihtml(figureHandle, "Position", [1, 1, 1000, 720]);
html.HTMLEventReceivedFcn = @receiveEvent;
html.HTMLSource = stagedRuntime;

started = tic;
waitFor(@isReady, 30, "viewer:ready");
uiReadyMilliseconds = toc(started) * 1000;

fixture = fullfile(KSSOLV_Toolbox.RootDirectory, "+kssolv", ...
    "+analysis", "+matgenlab", "+test", "+core", "+fixtures", ...
    "+local_env", "LiFePO4.json");
structure = kssolv.analysis.matgenlab.core.Structure.from_file(fixture);
structure = structure.add_oxidation_state_by_guess();

started = tic;
preview = kssolv.ui.scene.atomic.CrystalSceneBuilder.build( ...
    structure, includeConnectivity = false, includePolyhedra = false, ...
    requestId = "e2e-preview");
previewCompileMilliseconds = toc(started) * 1000;
started = tic;
sendScene(preview);
waitFor(@()isKey(rendered, char(preview.requestId)), 15, ...
    "preview viewer:sceneRendered");
previewTransportRenderMilliseconds = toc(started) * 1000;
previewClient = rendered(char(preview.requestId));

started = tic;
exact = kssolv.ui.scene.atomic.CrystalSceneBuilder.build( ...
    structure, algorithm = "CrystalNN", requestId = "e2e-exact");
exactCompileMilliseconds = toc(started) * 1000;
started = tic;
sendScene(exact);
waitFor(@()isKey(rendered, char(exact.requestId)), 15, ...
    "exact viewer:sceneRendered");
exactTransportRenderMilliseconds = toc(started) * 1000;
exactClient = rendered(char(exact.requestId));

report = struct( ...
    "uiReadyMilliseconds", uiReadyMilliseconds, ...
    "previewCompileMilliseconds", previewCompileMilliseconds, ...
    "previewTransportRenderMilliseconds", ...
        previewTransportRenderMilliseconds, ...
    "previewClientRenderMilliseconds", scalarField( ...
        previewClient, "elapsedMilliseconds"), ...
    "previewVisibleMilliseconds", previewCompileMilliseconds + ...
        previewTransportRenderMilliseconds, ...
    "exactCompileMilliseconds", exactCompileMilliseconds, ...
    "exactTransportRenderMilliseconds", exactTransportRenderMilliseconds, ...
    "exactClientRenderMilliseconds", scalarField( ...
        exactClient, "elapsedMilliseconds"), ...
    "exactAtoms", numel(exact.atomInstances), ...
    "exactBonds", numel(exact.bondInstances), ...
    "clientErrors", clientErrors);
disp(struct2table(rmfield(report, "clientErrors"), "AsArray", true));

if enforce
    assert(isempty(clientErrors), ...
        "KSSOLV:CrystalViewer:ClientError", ...
        "Crystal Viewer reported client errors: %s", ...
        join(clientErrors, newline));
    assert(report.previewVisibleMilliseconds <= 1000, ...
        "KSSOLV:CrystalViewer:EndToEndFirstFrameSLO", ...
        "LiFePO4 first visible frame exceeded one second.");
    assert(report.previewClientRenderMilliseconds <= 500, ...
        "KSSOLV:CrystalViewer:ClientRenderSLO", ...
        "Preview WebGL construction exceeded 500 milliseconds.");
    assert(report.exactTransportRenderMilliseconds <= 1000, ...
        "KSSOLV:CrystalViewer:ExactRenderSLO", ...
        "Exact-scene CEF transport and WebGL rendering exceeded one second.");
end

    function sendScene(scene)
        transport = kssolv.ui.scene.atomic.CrystalSceneSerializer. ...
            transportScene(scene);
        html.sendEventToHTMLSource("scene:set", jsonencode(transport));
    end

    function value = isReady()
        value = ready;
    end

    function receiveEvent(~, event)
        name = string(event.HTMLEventName);
        receivedEvents(end + 1) = name;
        data = event.HTMLEventData;
        if ischar(data) || (isstring(data) && isscalar(data))
            try
                data = jsondecode(data);
            catch
            end
        end
        switch name
            case "viewer:ready"
                ready = true;
            case "viewer:sceneRendered"
                if isstruct(data) && isfield(data, "requestId")
                    rendered(char(string(data.requestId))) = data;
                end
            case "viewer:error"
                if isstruct(data) && isfield(data, "message")
                    clientErrors(end + 1) = string(data.message);
                else
                    clientErrors(end + 1) = "Unknown viewer error";
                end
        end
    end

    function waitFor(predicate, timeoutSeconds, label)
        waitStarted = tic;
        while ~predicate()
            drawnow;
            pause(0.01);
            if toc(waitStarted) > timeoutSeconds
                error("KSSOLV:CrystalViewer:BenchmarkTimeout", ...
                    "Timed out waiting for %s. Events: [%s]. Errors: [%s].", ...
                    label, listText(receivedEvents, ", "), ...
                    listText(clientErrors, " | "));
            end
        end
    end
end

function value = scalarField(input, name)
if ~isstruct(input) || ~isfield(input, name) || ...
        ~isnumeric(input.(name)) || ~isscalar(input.(name))
    value = NaN;
else
    value = double(input.(name));
end
end

function deleteIfValid(value)
if ~isempty(value) && isvalid(value), delete(value); end
end

function deleteIfPresent(path)
if isfile(path), delete(path); end
end

function value = listText(items, delimiter)
if isempty(items)
    value = "";
else
    value = strjoin(items, delimiter);
end
end
