function [app, display, toolbox] = openInteractiveModelingQA()
%OPENINTERACTIVEMODELINGQA Open a persistent production KSSOLV QA scene.
%
% This entry point deliberately starts the complete production KSSOLV shell.
% It does not construct a reduced AppContainer or test-only toolstrip. The
% caller owns APP, DISPLAY, and TOOLBOX. Handles are also assigned in the
% base workspace so the session remains alive after this function returns.

root = workingTreeRoot();
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();

existingToolbox = kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
if isa(existingToolbox, "kssolv.KSSOLVToolbox") && ...
        isvalid(existingToolbox)
    delete(existingToolbox);
else
    existing = kssolv.ui.util.DataStorage.getData("AppContainer");
    if ~isempty(existing) && isvalid(existing)
        delete(existing);
    end
end

toolbox = kssolv();
app = toolbox.getAppContainer();
app.WindowBounds = [80, 80, 1200, 800];
app.Visible = true;
drawnow;

coordinates = [ ...
    -1.55,  0.55,  0.00
    -0.72,  0.00,  0.00
     0.72,  0.00,  0.00
     1.55, -0.15,  0.78];
molecule = kssolv.analysis.matgenlab.core.Molecule( ...
    ["H", "O", "O", "H"], coordinates);
molecule.properties.topology = struct( ...
    "bonds", [1, 2, 1; 2, 3, 1; 3, 4, 1], ...
    "origin", "source");

project = kssolv.ui.util.DataStorage.getData("Project");
folder = project.findChildrenItem("Structure");
item = folder.createBlankMolecule(false);
item.label = "Interactive Modeling QA H2O2";
item.data = kssolv.services.fileparser.ModeledStructureData( ...
    molecule, item.label);
item.showMoleculeDisplay();
drawnow;
display = kssolv.ui.features.modeling.SessionRegistry. ...
    getInstance().getCurrentDisplay();
if isempty(display)
    error("KSSOLV:Modeling:ProductionQADisplay", ...
        "Production KSSOLV did not register the QA structure document.");
end

assignin("base", "kssolvInteractiveQaApp", app);
assignin("base", "kssolvInteractiveQaDisplay", display);
assignin("base", "kssolvInteractiveQaToolbox", toolbox);
end
