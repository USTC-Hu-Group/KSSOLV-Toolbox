function report = runP1MoleculeEditingAcceptance(outputDirectory)
%RUNP1MOLECULEEDITINGACCEPTANCE Real AppContainer/uihtml P1 acceptance.

arguments
    outputDirectory string = ""
end
root = workingTreeRoot();
if outputDirectory == ""
    stamp = string(datetime("now", "TimeZone", "local", ...
        "Format", "yyyyMMdd-HHmmss"));
    outputDirectory = fullfile(root, "dev", "modeling", ...
        "acceptance", "reports", "p1-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

report = struct( ...
    "phase", "P1", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), ...
    "startedAt", string(datetime("now", "TimeZone", "local", "Format", ...
        "yyyy-MM-dd'T'HH:mm:ssXXX")), ...
    "outputDirectory", outputDirectory, ...
    "passed", false, ...
    "commands", ["substitute_atoms", "move_atoms", ...
        "translate_atoms", "delete_atoms"], ...
    "exports", ["xyz", "mol", "sdf", "mol2", "pdb"], ...
    "finalFormula", "", ...
    "error", "");

app = matlab.ui.container.internal.AppContainer(struct( ...
    "Title", "KSSOLV P1 Molecule Editing Acceptance", ...
    "ToolstripEnabled", true));
cleanup = onCleanup(@()cleanupScenario(app));
try
    kssolv.ui.util.DataStorage.setData("AppContainer", app);
    tabGroup = matlab.ui.internal.toolstrip.TabGroup();
    tabGroup.Tag = "kssolvTabGroup";
    app.add(tabGroup);
    modelingTab = kssolv.ui.components.tab.ModelingTab(tabGroup); %#ok<NASGU>
    app.Visible = true;
    drawnow

    molecule = kssolv.analysis.matgenlab.core.Molecule( ...
        ["O", "H", "H"], ...
        [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
    molecule.properties.topology = struct( ...
        "bonds", [1, 2, 1; 1, 3, 1], "origin", "source");
    project = kssolv.services.filemanager.Project();
    folder = project.findChildrenItem("Structure");
    item = kssolv.services.filemanager.Structure("P1 Water");
    item.data = kssolv.services.fileparser.ModeledStructureData( ...
        molecule, item.label);
    folder.addChildrenItem(item);
    kssolv.ui.util.DataStorage.setData("Project", project);
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();

    display = kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        molecule, "", item.name);
    display.Display();
    drawnow

    apply("substitute_atoms", struct("indices", 2, "species", "F"));
    apply("move_atoms", struct( ...
        "indices", 2, "coordinates", [1.1, 0.1, 0]));
    apply("translate_atoms", struct( ...
        "indices", [1, 3], "vector", [0, 0, 0.2]));
    apply("delete_atoms", struct("indices", 3));
    assert(display.canUndo());
    display.undo();
    assert(display.getModel().num_sites == 3);
    assert(display.canRedo());
    display.redo();
    assert(display.getModel().num_sites == 2);
    display.saveChangesToProject();
    assert(~display.hasUnsavedChanges());

    saved = item.data.MatgenlabObject;
    assert(isa(saved, "kssolv.analysis.matgenlab.core.IMolecule"));
    assert(saved.num_sites == 2);
    for format = report.exports
        path = fullfile(outputDirectory, "edited-water." + format);
        saved.to(path, format);
        restored = ...
            kssolv.analysis.matgenlab.core.Molecule.from_file(path, format);
        assert(restored.num_sites == saved.num_sites);
    end
    screenshot = fullfile(outputDirectory, "p1-molecule-viewer.png");
    exportapp(display.Document.Figure, screenshot);
    report.finalFormula = saved.formula;
    report.passed = true;
catch exception
    report.error = string(getReport(exception, "extended", ...
        "hyperlinks", "off"));
end
report.finishedAt = string(datetime("now", "TimeZone", "local", "Format", ...
    "yyyy-MM-dd'T'HH:mm:ssXXX"));
reportPath = fullfile(outputDirectory, "report.json");
writeText(reportPath, jsonencode(report, PrettyPrint = true));
if ~report.passed
    error("KSSOLV:Modeling:AcceptanceP1", "%s", report.error);
end
clear cleanup

    function apply(commandId, parameters)
        transaction = display.previewModelingCommand( ...
            commandId, parameters);
        preview = transaction.preview();
        assert(preview.changed);
        display.commitModelingTransaction(transaction, commandId);
    end
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

function cleanupScenario(app)
registry = kssolv.ui.util.DataStorage.getData("ModelingSessionRegistry");
if ~isempty(registry) && isvalid(registry), delete(registry); end
if ~isempty(app) && isvalid(app), delete(app); end
kssolv.ui.util.DataStorage.removeData("Project");
kssolv.ui.util.DataStorage.removeData("AppContainer");
end
