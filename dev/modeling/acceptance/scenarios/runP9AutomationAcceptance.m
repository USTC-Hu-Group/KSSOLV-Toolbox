function report=runP9AutomationAcceptance(outputDirectory)
%RUNP9AUTOMATIONACCEPTANCE Real GUI recording/replay and batch acceptance.
arguments, outputDirectory string="", end
root=workingTreeRoot();
addpath(fullfile(root,"+kssolv","+core","kssolv-3o")); evalc("KSSOLV.startup()")
if outputDirectory=="", outputDirectory=reportFolder(root,"p9"); end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
report=struct("phase","P9","matlabRelease",string(version("-release")), ...
    "platform",string(computer),"passed",false,"guiOperations",0, ...
    "replayVerified",false,"resultHash","","batchRequested",100, ...
    "batchSucceeded",0,"batchCancelledCleanly",false, ...
    "progressEvents",0,"error","","outputDirectory",outputDirectory);
app=matlab.ui.container.internal.AppContainer(struct( ...
    "Title","KSSOLV P9 Automation Acceptance","ToolstripEnabled",true));
cleanup=onCleanup(@()cleanupScenario(app));
try
    kssolv.ui.util.DataStorage.setData("AppContainer",app);
    tabs=matlab.ui.internal.toolstrip.TabGroup(); tabs.Tag="kssolvTabGroup";
    app.add(tabs); modeling=kssolv.ui.components.tab.ModelingTab(tabs); %#ok<NASGU>
    app.Visible=true; drawnow
    initial=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
    project=kssolv.services.filemanager.Project();
    folder=project.findChildrenItem("Structure");
    item=kssolv.services.filemanager.Structure("P9 Recorded Crystal");
    item.data=kssolv.services.fileparser.ModeledStructureData(initial,item.label);
    folder.addChildrenItem(item); kssolv.ui.util.DataStorage.setData("Project",project);
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();
    display=kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        initial,"",item.name); display.Display(); drawnow

    display.startOperationRecording();
    for step=1:10
        parameters=struct("indices",1,"vector",[.01*step,0,0], ...
            "fractional",false);
        if mod(step,2)==1
            transaction=display.previewModelingCommand( ...
                "translate_atoms",parameters);
            transaction.preview();
            display.commitModelingTransaction(transaction, ...
                "Recorded viewer translation");
        else
            result=kssolv.modeling.CommandExecutor.execute( ...
                display.getModel(),"translate_atoms",parameters);
            display.applyRecordedModel(result.model, ...
                "Recorded Modeling-tab translation", ...
                "translate_atoms",parameters);
        end
    end
    recipe=display.stopOperationRecording();
    report.guiOperations=numel(recipe.operations); assert(report.guiOperations==10);
    recipePath=fullfile(outputDirectory,"gui-modeling-recipe.json");
    writeText(recipePath,jsonencode(recipe,PrettyPrint=true));
    [replayed,replayReport]=kssolv.modeling.provenance. ...
        OperationRecorder.replay(initial,recipe);
    report.replayVerified=replayReport.verified;
    report.resultHash=kssolv.modeling.provenance.CanonicalHash.of(replayed);
    assert(report.resultHash== ...
        kssolv.modeling.provenance.CanonicalHash.of(display.getModel()));

    request=struct("schemaVersion",1,"commandId","translate_atoms", ...
        "parameters",struct("indices",1,"vector",[.1,0,0], ...
        "fractional",false));
    progress=0;
    batch=kssolv.modeling.BatchModeler.run(repmat({initial},1,100), ...
        repmat({request},1,100),progressFcn=@countProgress);
    report.batchSucceeded=batch.succeeded;
    report.progressEvents=progress;
    assert(report.batchSucceeded==100 && progress==100);
    cancelChecks=0;
    cancelled=kssolv.modeling.BatchModeler.run(repmat({initial},1,10), ...
        repmat({request},1,10),cancelFcn=@cancelAfterThree);
    report.batchCancelledCleanly=cancelled.cancelled && ...
        cancelled.completed==3 && sum([cancelled.entries.cancelled])==7;
    assert(report.batchCancelledCleanly);

    display.saveChangesToProject();
    exportapp(display.Document.Figure,fullfile(outputDirectory,"p9-recorder.png"));
    batchSummary=rmfield(batch,"entries");
    writeText(fullfile(outputDirectory,"batch-summary.json"), ...
        jsonencode(batchSummary,PrettyPrint=true));
    report.passed=true;
catch exception
    report.error=string(getReport(exception,"extended","hyperlinks","off"));
end
writeText(fullfile(outputDirectory,"report.json"),jsonencode(report,PrettyPrint=true));
if ~report.passed, error("KSSOLV:Modeling:AcceptanceP9","%s",report.error); end
clear cleanup
    function countProgress(~,~), progress=progress+1; end
    function value=cancelAfterThree()
        cancelChecks=cancelChecks+1; value=cancelChecks>3;
    end
end

function path=reportFolder(root,prefix)
stamp=string(datetime("now",Format="yyyyMMdd-HHmmss"));
path=fullfile(root,"dev","modeling","acceptance","reports",prefix+"-"+stamp);
end
function writeText(path,value)
file=fopen(path,"w","n","UTF-8"); cleanup=onCleanup(@()fclose(file));
fwrite(file,char(value),"char"); clear cleanup
end
function cleanupScenario(app)
registry=kssolv.ui.util.DataStorage.getData("ModelingSessionRegistry");
if ~isempty(registry)&&isvalid(registry), delete(registry); end
if ~isempty(app)&&isvalid(app), delete(app); end
kssolv.ui.util.DataStorage.removeData("Project");
kssolv.ui.util.DataStorage.removeData("AppContainer");
end
