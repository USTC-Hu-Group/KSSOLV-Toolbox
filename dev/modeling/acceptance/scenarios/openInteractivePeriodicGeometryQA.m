function [app, display, toolbox] = openInteractivePeriodicGeometryQA()
%OPENINTERACTIVEPERIODICGEOMETRYQA Open a production periodic model for pointer QA.
%
% This acceptance-only launcher uses the complete KSSOLV shell, Project
% service and production MoleculeDisplay. It adds no product menu entry or
% test-only viewer branch; all geometry operations are performed afterward
% through the normal UI with physical keyboard and pointer input.

root = workingTreeRoot();
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();

existingToolbox = kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
if isa(existingToolbox, "kssolv.KSSOLVToolbox") && ...
        isvalid(existingToolbox)
    delete(existingToolbox);
else
    existing = kssolv.ui.util.DataStorage.getData("AppContainer");
    if ~isempty(existing) && isvalid(existing), delete(existing); end
end

toolbox = kssolv();
app = toolbox.getAppContainer();
app.WindowBounds = [80, 80, 1200, 800];
app.Visible = true;
drawnow;

model = kssolv.analysis.matgenlab.core.Structure. ...
    from_spacegroup("Fd-3m", eye(3) * 5.43, "Si", [0, 0, 0]);
project = kssolv.ui.util.DataStorage.getData("Project");
folder = project.findChildrenItem("Structure");
item = folder.createBlankStructure(false);
item.label = "Interactive Periodic Geometry QA";
item.data = kssolv.services.fileparser.ModeledStructureData( ...
    model, item.label);
item.showMoleculeDisplay();
drawnow;

display = kssolv.ui.features.modeling.SessionRegistry. ...
    getInstance().getCurrentDisplay();
if isempty(display) || display.getModel().num_sites ~= 8
    error("KSSOLV:Modeling:PeriodicQADisplay", ...
        "Production KSSOLV did not open the eight-site Si QA crystal.");
end

assignin("base", "kssolvPeriodicQaApp", app);
assignin("base", "kssolvPeriodicQaDisplay", display);
assignin("base", "kssolvPeriodicQaToolbox", toolbox);
end
