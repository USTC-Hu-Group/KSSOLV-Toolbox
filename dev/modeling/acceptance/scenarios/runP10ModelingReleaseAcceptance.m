function report=runP10ModelingReleaseAcceptance(outputDirectory,options)
%RUNP10MODELINGRELEASEACCEPTANCE Real-GUI reliability and edit-soak gate.
arguments
    outputDirectory string=""
    options.editCount (1,1) double {mustBeInteger,mustBePositive}=500
end
root=workingTreeRoot();
addpath(fullfile(root,"+kssolv","+core","kssolv-3o")); evalc("KSSOLV.startup()")
if outputDirectory=="", outputDirectory=reportFolder(root,"p10"); end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
report=struct("phase","P10","matlabRelease",string(version("-release")), ...
    "platform",string(computer),"passed",false,"editCount",options.editCount, ...
    "editSeconds",NaN,"rssBeforeBytes",NaN,"rssAfterBytes",NaN, ...
    "rssGrowthFraction",NaN,"staleRequestRejected",false, ...
    "backendFailureAtomic",false,"renderFailureAtomic",false, ...
    "loadingCloseAtomic",false, ...
    "saveFailureRecoverable",false,"normalSaveClearsRecovery",false, ...
    "temporaryRecoveryFiles",NaN,"timerDelta",NaN,"finalRevision",NaN, ...
    "error","","outputDirectory",outputDirectory);
app=matlab.ui.container.internal.AppContainer(struct( ...
    "Title","KSSOLV P10 Release Acceptance","ToolstripEnabled",true));
cleanup=onCleanup(@()cleanupScenario(app));
try
    kssolv.ui.util.DataStorage.setData("AppContainer",app);
    tabs=matlab.ui.internal.toolstrip.TabGroup(); tabs.Tag="kssolvTabGroup";
    app.add(tabs); modeling=kssolv.ui.components.tab.ModelingTab(tabs); %#ok<NASGU>
    app.Visible=true; drawnow
    initial=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
    project=kssolv.services.filemanager.Project();
    folder=project.findChildrenItem("Structure");
    item=kssolv.services.filemanager.Structure("P10 Reliability Crystal");
    item.data=kssolv.services.fileparser.ModeledStructureData(initial,item.label);
    folder.addChildrenItem(item); kssolv.ui.util.DataStorage.setData("Project",project);
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();
    display=kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        initial,"",item.name); display.Display(); drawnow
    rssBefore=residentBytes(); timerCountBefore=numel(timerfindall);

    stale=display.previewModelingCommand("translate_atoms",struct( ...
        "indices",1,"vector",[.001,0,0],"fractional",false));
    started=tic;
    for index=1:options.editCount
        vector=[(-1)^index*.001,mod(index,3)*1e-5,0];
        transaction=display.previewModelingCommand("translate_atoms",struct( ...
            "indices",1,"vector",vector,"fractional",false));
        transaction.preview();
        display.commitModelingTransaction(transaction,"P10 edit soak");
        if mod(index,50)==0, drawnow limitrate, end
    end
    report.editSeconds=toc(started); report.finalRevision=display.getRevision();
    try
        display.commitModelingTransaction(stale,"stale fault");
    catch exception
        report.staleRequestRejected= ...
            string(exception.identifier)=="KSSOLV:Modeling:StaleTransaction";
    end
    stableHash=kssolv.modeling.provenance.CanonicalHash.of(display.getModel());
    try
        broken=display.previewModelingCommand("not_a_command",struct());
        broken.preview();
    catch
    end
    report.backendFailureAtomic=stableHash== ...
        kssolv.modeling.provenance.CanonicalHash.of(display.getModel());

    oversized=kssolv.analysis.matgenlab.core.Structure( ...
        kssolv.analysis.matgenlab.core.Lattice.cubic(100), ...
        repmat("H",1,25601),zeros(25601,3),skip_checks=true);
    try
        display.applyModel(oversized,"render fault injection");
    catch exception
        assert(string(exception.identifier)=="KSSOLV:CrystalViewer:StructureLimit");
    end
    report.renderFailureAtomic=stableHash== ...
        kssolv.modeling.provenance.CanonicalHash.of(display.getModel());

    loadingItem=kssolv.services.filemanager.Structure("Loading Close");
    loadingItem.data=kssolv.services.fileparser.ModeledStructureData( ...
        initial,"Loading Close"); folder.addChildrenItem(loadingItem);
    loadingDisplay=kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        initial,"",loadingItem.name); loadingDisplay.Display(); drawnow
    loadingHash=kssolv.modeling.provenance.CanonicalHash.of( ...
        loadingDisplay.getModel());
    count=4096; side=16; [x,y,z]=ndgrid(0:side-1,0:side-1,0:side-1);
    coordinates=3*[x(:),y(:),z(:)];
    loadingModel=kssolv.analysis.matgenlab.core.Structure( ...
        eye(3)*50,repmat("He",1,count),coordinates,skip_checks=true);
    closeTimer=timer("ExecutionMode","singleShot","StartDelay",.01, ...
        "TimerFcn",@(~,~)delete(loadingDisplay.Document));
    closeCleanup=onCleanup(@()deleteTimer(closeTimer)); start(closeTimer);
    try
        loadingDisplay.applyModel(loadingModel,"loading-close fault");
    catch
    end
    drawnow; report.loadingCloseAtomic=loadingHash== ...
        kssolv.modeling.provenance.CanonicalHash.of(loadingDisplay.getModel());
    delete(loadingDisplay); clear closeCleanup

    recovery=kssolv.modeling.provenance.RecoveryJournal( ...
        item.name); assert(recovery.exists());
    kssolv.ui.util.DataStorage.removeData("Project");
    try
        display.saveChangesToProject();
    catch
    end
    snapshot=recovery.recover();
    report.saveFailureRecoverable=snapshot.modelHash==stableHash;
    kssolv.ui.util.DataStorage.setData("Project",project);
    display.saveChangesToProject();
    report.normalSaveClearsRecovery=~recovery.exists();

    exportapp(display.Document.Figure,fullfile(outputDirectory,"p10-soak.png"));
    rssAfter=residentBytes(); report.rssBeforeBytes=rssBefore;
    report.rssAfterBytes=rssAfter;
    report.rssGrowthFraction=(rssAfter-rssBefore)/max(rssBefore,1);
    temporary=dir(fullfile(recovery.Directory,"*.tmp"));
    report.temporaryRecoveryFiles=numel(temporary);
    report.timerDelta=numel(timerfindall)-timerCountBefore;
    assert(report.finalRevision==options.editCount);
    assert(report.staleRequestRejected && report.backendFailureAtomic && ...
        report.renderFailureAtomic && report.saveFailureRecoverable && ...
        report.loadingCloseAtomic && ...
        report.normalSaveClearsRecovery);
    assert(report.temporaryRecoveryFiles==0 && report.timerDelta==0);
    % RSS is an intentionally conservative whole-process measure. A first
    % GUI scene may populate persistent MATLAB/CEF caches, so record the
    % number for trend analysis without hiding it behind a synthetic heap.
    report.passed=true;
catch exception
    report.error=string(getReport(exception,"extended","hyperlinks","off"));
end

function deleteTimer(value)
if isempty(value), return, end
try
    if strcmp(value.Running,"on"), stop(value); end
catch
end
try
    delete(value);
catch
end
end
writeText(fullfile(outputDirectory,"report.json"),jsonencode(report,PrettyPrint=true));
if ~report.passed, error("KSSOLV:Modeling:AcceptanceP10","%s",report.error); end
clear cleanup
end

function value=residentBytes()
[status,text]=system("ps -o rss= -p "+string(matlabProcessID));
if status~=0, value=NaN; else, value=str2double(strtrim(text))*1024; end
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
