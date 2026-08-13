function report = runP2DirectManipulationAcceptance(outputDirectory)
%RUNP2DIRECTMANIPULATIONACCEPTANCE Real GUI/history/selection P2 acceptance.

arguments
    outputDirectory string = ""
end
root = workingTreeRoot();
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();
if outputDirectory == ""
    stamp = string(datetime("now", "TimeZone", "local", ...
        "Format", "yyyyMMdd-HHmmss"));
    outputDirectory = fullfile(root, "dev", "modeling", ...
        "acceptance", "reports", "p2-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

report = struct( ...
    "phase", "P2", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), ...
    "startedAt", string(datetime("now", "TimeZone", "local", ...
    "Format", "yyyy-MM-dd'T'HH:mm:ssXXX")), ...
    "outputDirectory", outputDirectory, ...
    "productionShell", false, ...
    "passed", false, ...
    "translationUndoErrorAngstrom", NaN, ...
    "rotationRedoErrorAngstrom", NaN, ...
    "selectionSetResolved", 0, ...
    "historyRecordsPerDrag", NaN, ...
    "benchmarkAtoms", 0, ...
    "dragP95FrameMilliseconds", NaN, ...
    "dragFramesPerSecond", NaN, ...
    "error", "");

existing = kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
if isa(existing, "kssolv.KSSOLVToolbox") && isvalid(existing)
    error("KSSOLV:Modeling:ProductionQARequiresCleanSession", ...
        "Close the existing KSSOLV application before production QA.");
end
toolbox = kssolv();
cleanup = onCleanup(@()cleanupScenario(toolbox));
try
    app = toolbox.getAppContainer();
    app.WindowBounds = [80, 80, 1200, 800];
    app.Visible = true;
    report.productionShell = true;
    drawnow

    coordinates = [(0:11).' * 1.42, zeros(12, 2)];
    molecule = kssolv.analysis.matgenlab.core.Molecule( ...
        repmat("C", 1, 12), coordinates);
    molecule.properties.topology = struct( ...
        "bonds", [(1:11).', (2:12).', ones(11, 1)], ...
        "origin", "source");
    project = kssolv.ui.util.DataStorage.getData("Project");
    folder = project.findChildrenItem("Structure");
    item = folder.createBlankMolecule(false);
    item.label = "P2 Carbon Chain";
    item.data = kssolv.services.fileparser.ModeledStructureData( ...
        molecule, item.label);
    item.showMoleculeDisplay();
    drawnow
    display = kssolv.ui.features.modeling.SessionRegistry. ...
        getInstance().getCurrentDisplay();
    assert(~isempty(display));
    display.setSelectedSiteIndices([2, 4, 6, 8, 10]);
    waitForSelection(display, [2, 4, 6, 8, 10]);
    display.saveSelectionSet("even-chain-sites");
    % Discard this same-session checkpoint so Display cannot mistake it for
    % a previous crash draft in a noninteractive acceptance run.
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();
    beforeTranslation = display.getModel().cart_coords;
    revision = display.getRevision();
    commit("translate_atoms", struct( ...
        "indices", [2, 4, 6, 8, 10], ...
        "vector", [0.125, -0.25, 0.375], ...
        "fractional", false), "Pointer Move");
    report.historyRecordsPerDrag = display.getRevision() - revision;
    translated = display.getModel().cart_coords;
    display.undo();
    report.translationUndoErrorAngstrom = max(abs( ...
        display.getModel().cart_coords - beforeTranslation), [], "all");
    display.redo();
    assert(max(abs(display.getModel().cart_coords - translated), [], "all") ...
        < 1e-10);

    revision = display.getRevision();
    anchor = mean(translated([2, 4, 6, 8, 10], :), 1);
    commit("rotate_atoms", struct( ...
        "indices", [2, 4, 6, 8, 10], ...
        "angleDegrees", 15, "axis", [0, 0, 1], ...
        "anchor", anchor), "Pointer Rotate");
    assert(display.getRevision() - revision == 1);
    rotated = display.getModel().cart_coords;
    display.undo();
    display.redo();
    report.rotationRedoErrorAngstrom = max(abs( ...
        display.getModel().cart_coords - rotated), [], "all");

    [resolved, missing] = ...
        kssolv.modeling.selection.SelectionSetStore.resolve( ...
        display.getModel(), "even-chain-sites");
    report.selectionSetResolved = numel(resolved);
    assert(isequal(resolved, [2, 4, 6, 8, 10]));
    assert(isempty(missing));
    display.saveChangesToProject();
    reopened = kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        item.data.MatgenlabObject, "", item.name);
    [reopenedSelection, reopenedMissing] = ...
        kssolv.modeling.selection.SelectionSetStore.resolve( ...
        reopened.getModel(), "even-chain-sites");
    assert(isequal(reopenedSelection, resolved));
    assert(isempty(reopenedMissing));
    delete(reopened);

    assert(report.historyRecordsPerDrag == 1);
    assert(report.translationUndoErrorAngstrom < 1e-10);
    assert(report.rotationRedoErrorAngstrom < 1e-10);
    screenshot = fullfile(outputDirectory, "p2-direct-manipulation.png");
    exportapp(display.Document.Figure, screenshot);

    [x, y, z] = ndgrid(0:9, 0:9, 0:9);
    benchmarkMolecule = ...
        kssolv.analysis.matgenlab.core.Molecule( ...
        repmat("C", 1, 1000), [x(:), y(:), z(:)] * 1.8);
    benchmarkMolecule.properties.topology = struct( ...
        "bonds", zeros(0, 3), "origin", "source");
    benchmarkDisplay = ...
        kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        benchmarkMolecule);
    benchmarkDisplay.Display();
    drawnow
    benchmark = benchmarkDisplay.benchmarkViewerInteraction(5, 120);
    report.benchmarkAtoms = double(benchmark.atoms);
    report.dragP95FrameMilliseconds = ...
        double(benchmark.p95FrameMilliseconds);
    report.dragFramesPerSecond = double(benchmark.framesPerSecond);
    assert(report.benchmarkAtoms == 1000);
    assert(report.dragFramesPerSecond >= 45);
    delete(benchmarkDisplay.Document);
    delete(benchmarkDisplay);
    report.passed = report.productionShell;
catch exception
    report.error = string(getReport(exception, "extended", ...
        "hyperlinks", "off"));
end
report.finishedAt = string(datetime("now", "TimeZone", "local", ...
    "Format", "yyyy-MM-dd'T'HH:mm:ssXXX"));
writeText(fullfile(outputDirectory, "report.json"), ...
    jsonencode(report, PrettyPrint = true));
if ~report.passed
    error("KSSOLV:Modeling:AcceptanceP2", "%s", report.error);
end
clear cleanup

    function commit(commandId, parameters, label)
        transaction = display.previewModelingCommand(commandId, parameters);
        preview = transaction.preview();
        assert(preview.changed);
        display.commitModelingTransaction(transaction, label);
    end
end

function waitForSelection(display, expected)
started = tic;
while toc(started) < 5
    drawnow
    if isequal(display.getSelectedSiteIndices(), expected)
        return
    end
    pause(.02)
end
error("KSSOLV:Modeling:AcceptanceSelectionTimeout", ...
    "The production viewer did not confirm the requested atom selection.");
end

function writeText(path, value)
file = fopen(path, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Modeling:AcceptanceWrite", ...
        "Unable to create acceptance report '%s'.", path);
end
cleanup = onCleanup(@()fclose(file));
fwrite(file, char(value), "char");
clear cleanup
end

function cleanupScenario(toolbox)
registry = kssolv.ui.util.DataStorage.getData("ModelingSessionRegistry");
if ~isempty(registry) && isvalid(registry), delete(registry); end
if ~isempty(toolbox) && isvalid(toolbox), delete(toolbox); end
kssolv.ui.util.DataStorage.removeData("Project");
kssolv.ui.util.DataStorage.removeData("ProjectFilename");
end
