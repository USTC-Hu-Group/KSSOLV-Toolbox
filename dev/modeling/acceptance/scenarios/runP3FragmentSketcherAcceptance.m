function report = runP3FragmentSketcherAcceptance(outputDirectory)
%RUNP3FRAGMENTSKETCHERACCEPTANCE Production-shell fragment acceptance.

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
        "acceptance", "reports", "p3-fragment-sketcher-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

report = struct("phase", "P3-fragment-sketcher", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), "productionShell", false, ...
    "schemaVersion", 0, "builtInFragments", 0, ...
    "carboxylPorts", strings(0,1), "monodentatePassed", false, ...
    "bidentatePassed", false, "assemblyRegressions", 0, ...
    "userRoundTrip", false, "passed", false, "error", "", ...
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
    report.productionShell = true;

    entries = kssolv.modeling.fragments.FragmentLibrary.list( ...
        "", includeUser = false);
    report.schemaVersion = ...
        kssolv.modeling.fragments.FragmentLibrary.SchemaVersion;
    report.builtInFragments = numel(entries);
    ports = kssolv.modeling.fragments.FragmentLibrary.ports("Carboxyl");
    report.carboxylPorts = reshape(string({ports.id}), [], 1);
    assert(report.schemaVersion == 2 && report.builtInFragments >= 13);

    molecule = blankMolecule();
    molecule = execute(molecule, "sketch_ring", struct( ...
        "ringSize", 6, "species", "C", "center", [0,0,0], ...
        "normal", [0,0,1], "aromatic", true));
    project = kssolv.ui.util.DataStorage.getData("Project");
    folder = project.findChildrenItem("Structure");
    item = folder.createBlankMolecule(false);
    item.label = "P3 Production COOH";
    item.data = kssolv.services.fileparser.ModeledStructureData( ...
        molecule, item.label);
    item.showMoleculeDisplay();
    drawnow;
    display = kssolv.ui.features.modeling.SessionRegistry. ...
        getInstance().getCurrentDisplay();
    assert(~isempty(display));

    transaction = display.previewModelingCommand("attach_fragment", ...
        struct("indices", 1, "fragmentName", "Carboxyl", ...
        "portId", "carbon", "fragmentIndex", 1, "bondOrder", 1));
    preview = transaction.preview();
    assert(preview.changed);
    display.commitModelingTransaction(transaction, "attach_fragment");
    carbonAttached = display.getModel();
    assert(carbonAttached.num_sites == 10);
    display.undo();
    assert(display.getModel().num_sites == 6);
    display.redo();
    assert(display.getModel().num_sites == 10);

    host = blankWithAtoms("C", [0,0,0]);
    [monodentate, metadata] = kssolv.modeling.fragments. ...
        FragmentLibrary.attach(host, "Carboxyl", 1, ...
        portId = "oxygen-single");
    report.monodentatePassed = monodentate.num_sites == 4 && ...
        metadata.portMode == "monodentate" && ...
        ~any(siteSymbols(monodentate) == "H");

    separation = norm([1.23,0,0] - [-.65,1.12,0]);
    host = blankWithAtoms(["Cu","Cu"], [0,0,0;0,separation,0]);
    [bidentate, metadata] = kssolv.modeling.fragments. ...
        FragmentLibrary.attach(host, "Carboxyl", [1,2], ...
        portId = "oxygen-bidentate");
    report.bidentatePassed = bidentate.num_sites == 5 && ...
        metadata.portMode == "bidentate" && ...
        numel(metadata.connectionHead) == 2;

    for sample = 1:100
        host = blankWithAtoms("C", [0,0,0]);
        assembled = kssolv.modeling.fragments.FragmentLibrary. ...
            attach(host, "Carboxyl", 1, portId = "carbon");
        bonds = assembled.properties.topology.bonds;
        assert(size(unique(sort(bonds(:,1:2),2), "rows"), 1) == ...
            size(bonds,1));
        report.assemblyRegressions = sample;
    end

    store = fullfile(outputDirectory, "user-fragments.json");
    custom = blankWithAtoms(["C","H"], [0,0,0;1.09,0,0]);
    custom = execute(custom, "add_bond", ...
        struct("indices", [1,2], "bondOrder", 1));
    port = struct("id", "carbon", "label", "Carbon connection", ...
        "headIndices", 1, "leavingAtomIndices", 2, ...
        "defaultBondOrders", 1, "orientation", [-1,0,0], ...
        "mode", "covalent", "bondOverrides", zeros(0,3));
    kssolv.modeling.fragments.FragmentLibrary.saveUser( ...
        "P3 Custom", custom, ports = port, storePath = store, ...
        overwrite = true);
    roundTrip = kssolv.modeling.fragments.FragmentLibrary.loadStore(store);
    report.userRoundTrip = roundTrip.schemaVersion == 2 && ...
        roundTrip.fragments(1).ports.id == "carbon" && ...
        roundTrip.fragments(1).ports.leavingAtomIndices == 2;

    browser = kssolv.ui.features.modeling.FragmentBrowser( ...
        [], Visible = true, StorePath = store);
    browserCleanup = onCleanup(@()deleteIfValid(browser));
    browser.refresh("COOH");
    drawnow;
    exportapp(browser.Figure, fullfile(outputDirectory, ...
        "fragment-browser-cooh.png"));
    carbonAttached.to(fullfile(outputDirectory, ...
        "benzene-cooh.mol"), "mol");

    report.passed = report.monodentatePassed && ...
        report.bidentatePassed && report.userRoundTrip && ...
        report.assemblyRegressions == 100;
catch exception
    report.error = string(getReport(exception, "extended", ...
        "hyperlinks", "off"));
end
writeText(fullfile(outputDirectory, "report.json"), ...
    jsonencode(report, PrettyPrint = true));
if ~report.passed
    error("KSSOLV:Modeling:P3FragmentSketcher", "%s", report.error);
end
clear browserCleanup cleanup
end

function molecule = blankMolecule()
properties = struct("topology", struct("bonds", zeros(0,3), ...
    "origin", "source", "schemaVersion", 1));
molecule = kssolv.analysis.matgenlab.core.Molecule( ...
    cell(1,0), zeros(0,3), charge_spin_check = false, ...
    properties = properties);
end

function molecule = blankWithAtoms(species, coordinates)
molecule = blankMolecule();
species = reshape(string(species), 1, []);
for index = 1:numel(species)
    molecule = execute(molecule, "sketch_atom", struct( ...
        "species", species(index), "coordinates", coordinates(index,:)));
end
end

function model = execute(model, commandId, parameters)
result = kssolv.modeling.CommandExecutor.execute( ...
    model, commandId, parameters);
model = result.model;
end

function symbols = siteSymbols(model)
symbols = arrayfun(@(index)string(model(index).specie.symbol), ...
    1:model.num_sites);
end

function deleteIfValid(value)
if ~isempty(value) && isvalid(value), delete(value); end
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
