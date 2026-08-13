function [app, display, toolbox] = openInteractiveBlankMoleculeQA()
%OPENINTERACTIVEBLANKMOLECULEQA Open a blank production molecule for pointer QA.
%
% This acceptance fixture starts the complete KSSOLV shell and production
% MoleculeDisplay.  It deliberately creates no atoms through MATLAB code so
% every modeled atom and bond in the resulting task comes from physical UI
% input.  The handles are retained in the base workspace for an interactive
% desktop run.

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

project = kssolv.ui.util.DataStorage.getData("Project");
folder = project.findChildrenItem("Structure");
item = folder.createBlankMolecule(false);
item.label = "Interactive Blank Molecule QA";
item.data = kssolv.services.fileparser.ModeledStructureData( ...
    item.data.MatgenlabObject, item.label);
item.showMoleculeDisplay();
drawnow;

display = kssolv.ui.features.modeling.SessionRegistry. ...
    getInstance().getCurrentDisplay();
if isempty(display)
    error("KSSOLV:Modeling:ProductionQADisplay", ...
        "Production KSSOLV did not register the blank QA document.");
end
if display.getModel().num_sites ~= 0
    error("KSSOLV:Modeling:BlankQANotEmpty", ...
        "The blank molecule QA fixture must start with zero atoms.");
end

assignin("base", "kssolvBlankQaApp", app);
assignin("base", "kssolvBlankQaDisplay", display);
assignin("base", "kssolvBlankQaToolbox", toolbox);
end
