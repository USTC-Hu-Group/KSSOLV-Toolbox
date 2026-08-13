function report = runP3P4MoleculeBuilderAcceptance(outputDirectory)
%RUNP3P4MOLECULEBUILDERACCEPTANCE Real GUI molecular builder acceptance.

arguments
    outputDirectory string = ""
end
root = workingTreeRoot();
addpath(fullfile(root,"+kssolv","+core","kssolv-3o"));
evalc("KSSOLV.startup()");
if outputDirectory == ""
    stamp = string(datetime("now", "TimeZone", "local", ...
        "Format", "yyyyMMdd-HHmmss"));
    outputDirectory = fullfile(root, "dev", "modeling", ...
        "acceptance", "reports", "p3-p4-" + stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
report = struct("phase", "P3-P4", ...
    "matlabRelease", string(version("-release")), ...
    "platform", string(computer), "passed", false, ...
    "formula", "", "bondLengthError", NaN, ...
    "angleErrorDegrees", NaN, "dihedralErrorDegrees", NaN, ...
    "fragmentRegressions", 0, "historyRecords", 0, "error", "", ...
    "outputDirectory", outputDirectory);

app = matlab.ui.container.internal.AppContainer(struct( ...
    "Title", "KSSOLV P3-P4 Molecular Builder Acceptance", ...
    "ToolstripEnabled", true));
cleanup = onCleanup(@()cleanupScenario(app));
try
    kssolv.ui.util.DataStorage.setData("AppContainer", app);
    tabGroup = matlab.ui.internal.toolstrip.TabGroup();
    tabGroup.Tag = "kssolvTabGroup"; app.add(tabGroup);
    modelingTab = kssolv.ui.components.tab.ModelingTab(tabGroup); %#ok<NASGU>
    app.Visible = true; drawnow

    project = kssolv.services.filemanager.Project();
    folder = project.findChildrenItem("Structure");
    item = folder.createBlankMolecule(false);
    item.label = "P3-P4 Benzamide";
    kssolv.ui.util.DataStorage.setData("Project", project);
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();
    display = kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        item.data.MatgenlabObject, "", item.name);
    display.Display(); drawnow

    apply("sketch_ring", struct("ringSize",6,"species","C", ...
        "center",[0,0,0],"normal",[0,0,1], ...
        "aromatic",true,"bondOrder",1.5));
    apply("sketch_atom", struct("species","C", ...
        "coordinates",[2.8,0,0],"connectTo",1,"bondOrder",1, ...
        "formalCharge",0,"hybridization","sp2","aromatic",false));
    apply("sketch_atom", struct("species","O", ...
        "coordinates",[4.03,0,0],"connectTo",7,"bondOrder",2, ...
        "formalCharge",0,"hybridization","sp2","aromatic",false));
    apply("sketch_atom", struct("species","N", ...
        "coordinates",[2.8,1.33,0],"connectTo",7,"bondOrder",1, ...
        "formalCharge",0,"hybridization","sp2","aromatic",false));
    % Attach the methyl fragment while the amide nitrogen still has an
    % available valence.  The previous sequence added hydrogens first and
    % then attempted to over-coordinate a saturated nitrogen, which the
    % production valence preflight correctly rejects.
    apply("attach_fragment",struct("indices",9, ...
        "fragmentName","Methyl","fragmentIndex",1,"bondOrder",1));
    apply("add_hydrogens", struct("indices",1:13));
    report.formula = display.getModel().formula;
    assert(elementCount(display.getModel(),"C") == 8);
    assert(elementCount(display.getModel(),"H") == 9);
    assert(elementCount(display.getModel(),"N") == 1);
    assert(elementCount(display.getModel(),"O") == 1);

    apply("set_distance", struct("indices",[7,8], ...
        "value",1.231234,"scope","atom"));
    measured = analysis("measure_geometry",struct("indices",[7,8]));
    report.bondLengthError = abs(measured.value-1.231234);
    apply("set_angle", struct("indices",[1,7,9], ...
        "value",121.25,"scope","subtree"));
    measured = analysis("measure_geometry",struct("indices",[1,7,9]));
    report.angleErrorDegrees = abs(measured.value-121.25);
    apply("set_dihedral", struct("indices",[2,1,7,9], ...
        "value",35.5,"scope","subtree"));
    measured = analysis("measure_geometry", ...
        struct("indices",[2,1,7,9]));
    report.dihedralErrorDegrees = abs( ...
        mod(measured.value-35.5+180,360)-180);

    report.fragmentRegressions = 100;
    for sample = 1:100
        host = kssolv.analysis.matgenlab.core.Molecule( ...
            {"C"},[0,0,0],charge_spin_check=false, ...
            properties=struct("topology",struct( ...
            "bonds",zeros(0,3),"origin","source")));
        [assembled,~] = kssolv.modeling.fragments.FragmentLibrary. ...
            attach(host,"O-H fragment",1);
        assert(assembled.num_sites == 3);
    end
    report.historyRecords = display.getRevision();
    assert(report.bondLengthError < 1e-6);
    assert(report.angleErrorDegrees < 1e-5);
    assert(report.dihedralErrorDegrees < 1e-5);
    display.undo(); display.redo();
    display.saveChangesToProject();
    model = display.getModel();
    model.to(fullfile(outputDirectory,"benzamide-derived.mol"),"mol");
    model.to(fullfile(outputDirectory,"benzamide-derived.sdf"),"sdf");
    exportapp(display.Document.Figure, ...
        fullfile(outputDirectory,"p3-p4-molecule-builder.png"));
    report.passed = true;
catch exception
    report.error = string(getReport(exception,"extended","hyperlinks","off"));
end
writeText(fullfile(outputDirectory,"report.json"), ...
    jsonencode(report,PrettyPrint=true));
if ~report.passed
    error("KSSOLV:Modeling:AcceptanceP3P4","%s",report.error);
end
clear cleanup

    function apply(commandId, parameters)
        transaction = display.previewModelingCommand(commandId,parameters);
        preview = transaction.preview(); assert(preview.changed);
        display.commitModelingTransaction(transaction,commandId);
    end
    function value = analysis(commandId, parameters)
        value = kssolv.modeling.CommandExecutor.execute( ...
            display.getModel(),commandId,parameters).analysis;
    end
end

function count = elementCount(model,symbol)
count = sum(arrayfun(@(index)string(model(index).specie.symbol)==symbol, ...
    1:model.num_sites));
end
function writeText(path,value)
file=fopen(path,"w","n","UTF-8");
if file<0, error("KSSOLV:Modeling:AcceptanceWrite","Cannot write report."); end
cleanup=onCleanup(@()fclose(file)); fwrite(file,char(value),"char"); clear cleanup
end
function cleanupScenario(app)
registry=kssolv.ui.util.DataStorage.getData("ModelingSessionRegistry");
if ~isempty(registry)&&isvalid(registry), delete(registry); end
if ~isempty(app)&&isvalid(app), delete(app); end
kssolv.ui.util.DataStorage.removeData("Project");
kssolv.ui.util.DataStorage.removeData("AppContainer");
end
