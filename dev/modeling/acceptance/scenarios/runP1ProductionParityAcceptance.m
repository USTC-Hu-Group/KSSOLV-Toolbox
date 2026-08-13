function report = runP1ProductionParityAcceptance(outputDirectory)
%RUNP1PRODUCTIONPARITYACCEPTANCE Verify the complete production UI host.

arguments
    outputDirectory string = ""
end
root = string(workingTreeRoot());
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();
if outputDirectory == ""
    stamp = string(datetime("now", "TimeZone", "local", ...
        "Format", "yyyyMMdd-HHmmss"));
    outputDirectory = fullfile(root, "dev", "modeling", ...
        "acceptance", "reports", "p1-production-parity-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

report = struct( ...
    "phase", "P1-production-parity", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), ...
    "productionShell", false, ...
    "runtimeVerified", false, ...
    "runtimeRevision", "", ...
    "runtimeSha256", "", ...
    "panels", strings(0, 1), ...
    "modelFormula", "", ...
    "modelSites", 0, ...
    "modelBonds", 0, ...
    "passed", false, ...
    "error", "", ...
    "outputDirectory", outputDirectory);

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
    drawnow;

    panelTags = ["ProjectBrowser", "InfoBrowser", "ConfigBrowser", ...
        "RunBrowser", "CommandWindow"];
    for panelTag = panelTags
        panel = app.getPanel(char(panelTag));
        assert(~isempty(panel), "Missing production panel: %s", panelTag);
    end
    report.panels = panelTags.';
    report.productionShell = true;

    runtimeEntry = fullfile(root, "+kssolv", "+ui", "+components", ...
        "+figuredocument", "@MoleculeDisplay", "CrystalViewer", ...
        "index.html");
    manifest = kssolv.ui.util.CrystalViewerRuntime.verify(runtimeEntry);
    report.runtimeVerified = true;
    report.runtimeRevision = string(manifest.sourceRevision);
    report.runtimeSha256 = string(manifest.entrySha256);

    coordinates = [ ...
        -1.55,  0.55,  0.00
        -0.72,  0.00,  0.00
         0.72,  0.00,  0.00
         1.55, -0.15,  0.78];
    molecule = kssolv.analysis.matgenlab.core.Molecule( ...
        ["H", "O", "O", "H"], coordinates);
    molecule.properties.topology = struct( ...
        "bonds", [1, 2, 1; 2, 3, 1; 3, 4, 1], ...
        "origin", "source", "schemaVersion", 1);
    project = kssolv.ui.util.DataStorage.getData("Project");
    folder = project.findChildrenItem("Structure");
    item = folder.createBlankMolecule(false);
    item.label = "P1 Production QA H2O2";
    item.data = kssolv.services.fileparser.ModeledStructureData( ...
        molecule, item.label);
    item.showMoleculeDisplay();
    drawnow;

    registry = kssolv.ui.features.modeling.SessionRegistry.getInstance();
    display = registry.getCurrentDisplay();
    assert(~isempty(display) && registry.count() == 1, ...
        "Production structure document was not registered.");
    renderedModel = display.getModel();
    report.modelFormula = renderedModel.formula;
    report.modelSites = renderedModel.num_sites;
    report.modelBonds = size(renderedModel.properties.topology.bonds, 1);
    assert(report.modelSites == 4 && report.modelBonds == 3);
    assert(~isempty(app.getDocumentGroup("Structure")));

    report.passed = true;
catch exception
    report.error = string(getReport(exception, "extended", ...
        "hyperlinks", "off"));
end

writeText(fullfile(outputDirectory, "report.json"), ...
    jsonencode(report, PrettyPrint = true));
if ~report.passed
    error("KSSOLV:Modeling:P1ProductionParity", "%s", report.error);
end
clear cleanup
end

function cleanupScenario(toolbox)
if ~isempty(toolbox) && isvalid(toolbox), delete(toolbox); end
registry = kssolv.ui.util.DataStorage.getData("ModelingSessionRegistry");
if ~isempty(registry) && isvalid(registry), delete(registry); end
kssolv.ui.util.DataStorage.removeData("ModelingSessionRegistry");
kssolv.ui.util.DataStorage.removeData("Project");
kssolv.ui.util.DataStorage.removeData("ProjectFilename");
end

function writeText(path, value)
file = fopen(path, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Modeling:AcceptanceWrite", ...
        "Cannot write acceptance report: %s", path);
end
cleanup = onCleanup(@()fclose(file));
fwrite(file, char(value), "char");
clear cleanup
end
