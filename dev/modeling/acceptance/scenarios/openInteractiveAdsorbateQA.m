function [app, display, toolbox] = openInteractiveAdsorbateQA()
%OPENINTERACTIVEADSORBATEQA Open a production slab for real pointer QA.

root = workingTreeRoot();
addpath(fullfile(root, "+kssolv", "+core", "kssolv-3o"));
KSSOLV.startup();

existing = kssolv.ui.util.DataStorage.getData("KSSOLVToolbox");
if isa(existing, "kssolv.KSSOLVToolbox") && isvalid(existing)
    delete(existing);
end
toolbox = kssolv();
app = toolbox.getAppContainer();
app.WindowBounds = [80, 80, 1200, 800];
app.Visible = true;
drawnow;

fragmentStorePath = string(tempname) + ".json";
port = struct("id", "oxygen-anchor", "label", "O anchor", ...
    "headIndices", 1, "leavingAtomIndices", zeros(1, 0), ...
    "defaultBondOrders", 1, "orientation", [1, 0, 0], ...
    "maxConnections", 1, "mode", "monodentate", ...
    "bondOverrides", zeros(0, 3));
custom = kssolv.analysis.matgenlab.core.Molecule( ...
    ["O", "C", "H"], [0,0,0;1.22,0,0;1.82,.82,0], ...
    charge_spin_check = false, properties = struct( ...
    "topology", struct("bonds", [1,2,2;2,3,1], ...
    "origin", "source", "schemaVersion", 1)));
kssolv.modeling.fragments.FragmentLibrary.saveUser( ...
    "QA Custom Formyl", custom, ports = port, ...
    storePath = fragmentStorePath);
kssolv.ui.util.DataStorage.setData( ...
    "ModelingFragmentStorePath", fragmentStorePath);

lattice = diag([6, 6, 18]);
fractional = [ ...
    .25,.25,.45; .75,.25,.45; .25,.75,.45; .75,.75,.45; ...
    .25,.25,.50; .75,.25,.50; .25,.75,.50; .75,.75,.50];
slab = kssolv.analysis.matgenlab.core.Structure( ...
    lattice, repmat("Cu", 1, size(fractional, 1)), fractional, ...
    labels = "Cu" + string(1:size(fractional, 1)));

project = kssolv.ui.util.DataStorage.getData("Project");
folder = project.findChildrenItem("Structure");
item = folder.createBlankStructure(false);
item.label = "Interactive Generic Adsorbate QA";
item.data = kssolv.services.fileparser.ModeledStructureData( ...
    slab, item.label);
item.showMoleculeDisplay();
drawnow;
display = kssolv.ui.features.modeling.SessionRegistry. ...
    getInstance().getCurrentDisplay();
if isempty(display)
    error("KSSOLV:Modeling:ProductionQADisplay", ...
        "Production KSSOLV did not register the QA slab document.");
end

assignin("base", "kssolvAdsorbateQaApp", app);
assignin("base", "kssolvAdsorbateQaDisplay", display);
assignin("base", "kssolvAdsorbateQaToolbox", toolbox);
assignin("base", "kssolvAdsorbateQaFragmentStore", fragmentStorePath);
assignin("base", "display", display);
end
