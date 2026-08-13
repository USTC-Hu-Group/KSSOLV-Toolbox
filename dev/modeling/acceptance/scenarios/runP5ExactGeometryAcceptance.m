function report = runP5ExactGeometryAcceptance(outputDirectory)
%RUNP5EXACTGEOMETRYACCEPTANCE Production exact-edit and round-trip gate.

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
        "acceptance", "reports", "p5-exact-geometry-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

report = struct("phase", "P5-exact-geometry", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), "productionShell", false, ...
    "distanceErrorAngstrom", Inf, "angleErrorDegrees", Inf, ...
    "dihedralErrorDegrees", Inf, "moveErrorAngstrom", Inf, ...
    "rotationErrorAngstrom", Inf, "bondOrderPassed", false, ...
    "periodicInitialDistanceAngstrom", Inf, ...
    "periodicDistanceErrorAngstrom", Inf, ...
    "periodicAngleErrorDegrees", Inf, ...
    "periodicDihedralErrorDegrees", Inf, ...
    "periodicMinimumImagePassed", false, ...
    "hybridizationPassed", false, "roundTripFormats", strings(0,1), ...
    "undoRedoPassed", false, "passed", false, "error", "", ...
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

    molecule = moleculeFixture();
    project = kssolv.ui.util.DataStorage.getData("Project");
    folder = project.findChildrenItem("Structure");
    item = folder.createBlankMolecule(false);
    item.label = "P5 Exact Geometry QA";
    item.data = kssolv.services.fileparser.ModeledStructureData( ...
        molecule, item.label);
    item.showMoleculeDisplay();
    drawnow;
    display = kssolv.ui.features.modeling.SessionRegistry. ...
        getInstance().getCurrentDisplay();
    assert(~isempty(display));

    movedTarget = [3.4, .2, 1.1];
    moved = execute(molecule, "move_atoms", struct( ...
        "indices", 4, "coordinates", movedTarget, "cartesian", true));
    report.moveErrorAngstrom = norm(moved.cart_coords(4,:) - movedTarget);

    rotationAngle = 37;
    rotated = execute(molecule, "rotate_atoms", struct( ...
        "indices", 1:molecule.num_sites, "angleDegrees", rotationAngle, ...
        "axis", [0,0,1], "anchor", [0,0,0]));
    rotation = [cosd(rotationAngle), -sind(rotationAngle), 0; ...
        sind(rotationAngle), cosd(rotationAngle), 0; 0,0,1];
    expected = molecule.cart_coords * rotation.';
    report.rotationErrorAngstrom = max(vecnorm( ...
        rotated.cart_coords - expected, 2, 2));

    apply(display, "set_distance", struct("indices", [1,2], ...
        "value", 1.234567, "scope", "subtree"));
    measured = kssolv.modeling.geometry.MolecularGeometryCommands. ...
        measure(display.getModel(), [1,2]);
    report.distanceErrorAngstrom = abs(measured.value - 1.234567);

    apply(display, "set_angle", struct("indices", [1,2,3], ...
        "value", 117.25, "scope", "subtree"));
    measured = kssolv.modeling.geometry.MolecularGeometryCommands. ...
        measure(display.getModel(), [1,2,3]);
    report.angleErrorDegrees = abs(measured.value - 117.25);

    apply(display, "set_dihedral", struct("indices", [1,2,3,4], ...
        "value", -62.75, "scope", "subtree"));
    measured = kssolv.modeling.geometry.MolecularGeometryCommands. ...
        measure(display.getModel(), [1,2,3,4]);
    report.dihedralErrorDegrees = abs(wrap180(measured.value + 62.75));

    apply(display, "set_bond_order", struct( ...
        "indices", [1,2], "bondOrder", 2));
    apply(display, "set_atom_chemistry", struct( ...
        "indices", [1,2], "hybridization", "sp2", ...
        "formalCharge", 0, "aromatic", false));
    edited = display.getModel();
    bonds = edited.properties.topology.bonds;
    pair = sort(bonds(:,1:2), 2);
    targetPair = find(all(pair == [1,2], 2), 1);
    report.bondOrderPassed = ~isempty(targetPair) && ...
        bonds(targetPair, 3) == 2;
    hybridization = siteTextProperty(edited, "hybridization", "auto");
    report.hybridizationPassed = all(hybridization(1:2) == "sp2");

    for format = ["mol", "sdf"]
        text = edited.to("", format);
        restored = kssolv.analysis.matgenlab.core.Molecule. ...
            from_str(text, format);
        if isequal(restored.properties.topology.bonds, ...
                edited.properties.topology.bonds)
            report.roundTripFormats(end + 1, 1) = format;
        end
    end

    finalHash = kssolv.modeling.provenance.CanonicalHash.of(edited);
    display.undo();
    undoHybridization = siteTextProperty( ...
        display.getModel(), "hybridization", "auto");
    undoPassed = any(undoHybridization(1:2) ~= "sp2");
    display.redo();
    redoPassed = kssolv.modeling.provenance.CanonicalHash.of( ...
        display.getModel()) == finalHash;
    report.undoRedoPassed = undoPassed && redoPassed;

    display.resetViewerCamera();
    drawnow;
    pause(.9);
    drawnow;
    exportapp(display.Document.Figure, fullfile(outputDirectory, ...
        "production-exact-geometry.png"));
    edited.to(fullfile(outputDirectory, "edited-molecule.mol"), "mol");
    edited.to(fullfile(outputDirectory, "edited-molecule.sdf"), "sdf");

    periodic = periodicFixture();
    crystalItem = folder.createBlankStructure(false);
    crystalItem.label = "P5 Periodic Geometry QA";
    crystalItem.data = kssolv.services.fileparser.ModeledStructureData( ...
        periodic, crystalItem.label);
    crystalItem.showMoleculeDisplay();
    drawnow;
    crystalDisplay = kssolv.ui.features.modeling.SessionRegistry. ...
        getInstance().getCurrentDisplay();
    assert(~isempty(crystalDisplay));
    measured = kssolv.modeling.geometry.MolecularGeometryCommands. ...
        measure(crystalDisplay.getModel(), [1,4]);
    report.periodicInitialDistanceAngstrom = measured.value;
    apply(crystalDisplay, "set_distance", struct("indices", [1,4], ...
        "value", 2.4, "scope", "atom"));
    measured = kssolv.modeling.geometry.MolecularGeometryCommands. ...
        measure(crystalDisplay.getModel(), [1,4]);
    report.periodicDistanceErrorAngstrom = abs(measured.value - 2.4);
    apply(crystalDisplay, "set_angle", struct("indices", [1,4,7], ...
        "value", 112.25, "scope", "atom"));
    measured = kssolv.modeling.geometry.MolecularGeometryCommands. ...
        measure(crystalDisplay.getModel(), [1,4,7]);
    report.periodicAngleErrorDegrees = abs(measured.value - 112.25);
    apply(crystalDisplay, "set_dihedral", struct( ...
        "indices", [1,4,7,2], "value", 170.25, "scope", "atom"));
    measured = kssolv.modeling.geometry.MolecularGeometryCommands. ...
        measure(crystalDisplay.getModel(), [1,4,7,2]);
    report.periodicDihedralErrorDegrees = ...
        abs(wrap180(measured.value - 170.25));
    fractional = crystalDisplay.getModel().frac_coords;
    report.periodicMinimumImagePassed = ...
        abs(report.periodicInitialDistanceAngstrom - ...
        sqrt(3) * 5.43 / 4) < 1e-10 && ...
        all(fractional >= 0, "all") && all(fractional < 1, "all");
    crystalDisplay.resetViewerCamera();
    drawnow;
    pause(5.2);
    drawnow;
    exportapp(crystalDisplay.Document.Figure, ...
        fullfile(outputDirectory, "production-periodic-geometry.png"));
    crystalDisplay.getModel().to(fullfile(outputDirectory, ...
        "periodic-edited-structure.cif"), "cif");
    report.passed = report.productionShell && ...
        report.distanceErrorAngstrom < 1e-6 && ...
        report.angleErrorDegrees < 1e-5 && ...
        report.dihedralErrorDegrees < 1e-5 && ...
        report.moveErrorAngstrom < 1e-12 && ...
        report.rotationErrorAngstrom < 1e-12 && ...
        report.periodicDistanceErrorAngstrom < 1e-6 && ...
        report.periodicAngleErrorDegrees < 1e-5 && ...
        report.periodicDihedralErrorDegrees < 1e-5 && ...
        report.periodicMinimumImagePassed && ...
        report.bondOrderPassed && report.hybridizationPassed && ...
        numel(report.roundTripFormats) == 2 && report.undoRedoPassed;
catch exception
    report.error = string(getReport(exception, "extended", ...
        "hyperlinks", "off"));
end
writeText(fullfile(outputDirectory, "report.json"), ...
    jsonencode(report, PrettyPrint = true));
if ~report.passed
    error("KSSOLV:Modeling:P5ExactGeometry", "%s", report.error);
end
clear cleanup
end

function apply(display, commandId, parameters)
transaction = display.previewModelingCommand(commandId, parameters);
preview = transaction.preview();
assert(preview.changed);
display.commitModelingTransaction(transaction, commandId);
end

function model = execute(model, commandId, parameters)
result = kssolv.modeling.CommandExecutor.execute( ...
    model, commandId, parameters);
model = result.model;
end

function value = wrap180(value)
value = mod(value + 180, 360) - 180;
end

function values = siteTextProperty(model, name, defaultValue)
values = strings(1, model.num_sites);
for index = 1:model.num_sites
    values(index) = string(kssolv.modeling.chemistry. ...
        MoleculeDiagnostics.siteScalar( ...
        model(index), name, defaultValue));
end
end

function molecule = moleculeFixture()
carbonBonds = [1,2,1;2,3,1;3,4,1];
hydrogenBonds = [1,5,1;1,6,1;2,7,1;3,8,1;3,9,1; ...
    4,10,1;4,11,1;4,12,1];
properties = struct("topology", struct("bonds", ...
    [carbonBonds; hydrogenBonds], "origin", "source", ...
    "schemaVersion", 1));
molecule = kssolv.analysis.matgenlab.core.Molecule( ...
    ["C","C","C","C",repmat("H",1,8)], ...
    [0,0,0;1.5,0,0;2.0,1.4,0;3.0,1.7,1.0; ...
    -.6,.8,0;-.6,-.8,0;1.8,-.9,0;1.8,1.8,-.9; ...
    1.8,2.1,.7;3.8,1.2,1.2;3.2,2.7,1.2;2.7,1.3,1.9], ...
    charge_spin_check = false, properties = properties);
end

function value = periodicFixture()
value = kssolv.analysis.matgenlab.core.Structure. ...
    from_spacegroup("Fd-3m", eye(3) * 5.43, "Si", [0,0,0]);
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
