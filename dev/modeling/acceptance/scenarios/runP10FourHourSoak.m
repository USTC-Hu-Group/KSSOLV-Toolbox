function report=runP10FourHourSoak(outputDirectory,options)
%RUNP10FOURHOURSOAK Four-hour production GUI resource qualification.
arguments
    outputDirectory string=""
    options.durationSeconds (1,1) double {mustBePositive}=4*60*60
    options.editCount (1,1) double {mustBeInteger,mustBePositive}=500
    options.sampleSeconds (1,1) double {mustBePositive}=60
    options.warmupSeconds (1,1) double {mustBeNonnegative}=10*60
    options.requireQualification (1,1) logical=true
end
minimumDuration=4*60*60;
minimumEdits=500;
if options.requireQualification && ...
        (options.durationSeconds<minimumDuration || options.editCount<minimumEdits)
    error("KSSOLV:Modeling:SoakQualification", ...
        "A qualifying P10 soak requires at least 14400 seconds and 500 edits.");
end
root=workingTreeRoot();
addpath(fullfile(root,"+kssolv","+core","kssolv-3o"));
evalc("KSSOLV.startup()")
if outputDirectory==""
    stamp=string(datetime("now",Format="yyyyMMdd-HHmmss"));
    outputDirectory=fullfile(root,"dev","modeling","acceptance", ...
        "reports","p10-four-hour-"+stamp);
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
report=struct("phase","P10-four-hour-soak", ...
    "matlabRelease",string(version("-release")), ...
    "platform",string(computer),"startedAt",string(datetime("now")), ...
    "durationRequiredSeconds",minimumDuration, ...
    "durationRequestedSeconds",options.durationSeconds, ...
    "durationActualSeconds",NaN,"editCountRequired",minimumEdits, ...
    "editCountRequested",options.editCount,"editCountCompleted",0, ...
    "qualified",false,"passed",false,"rssGrowthFraction",NaN, ...
    "stableBaselineBytes",NaN,"stableFinalBytes",NaN, ...
    "stableSampleCount",0,"warmupSeconds",options.warmupSeconds, ...
    "timerDelta",NaN,"temporaryFiles",NaN,"parallelPoolCreated",false, ...
    "remainingModelingSessions",NaN, ...
    "finalRevision",NaN,"samplesFile","samples.csv", ...
    "error","","outputDirectory",outputDirectory);
app=matlab.ui.container.internal.AppContainer(struct( ...
    "Title","KSSOLV P10 Four-Hour Soak","ToolstripEnabled",true));
cleanup=onCleanup(@()cleanupScenario(app));
try
    kssolv.ui.util.DataStorage.setData("AppContainer",app);
    tabs=matlab.ui.internal.toolstrip.TabGroup(); tabs.Tag="kssolvTabGroup";
    app.add(tabs); kssolv.ui.components.tab.ModelingTab(tabs);
    app.Visible=true; drawnow
    initial=kssolv.modeling.test.ModelingFunctionalTestUtils.simpleCubic();
    project=kssolv.services.filemanager.Project();
    folder=project.findChildrenItem("Structure");
    item=kssolv.services.filemanager.Structure("P10 Four-Hour Crystal");
    item.data=kssolv.services.fileparser.ModeledStructureData(initial,item.label);
    folder.addChildrenItem(item);
    kssolv.ui.util.DataStorage.setData("Project",project);
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();
    display=kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        initial,"",item.name); display.Display(); drawnow
    baselineHash=kssolv.modeling.provenance.CanonicalHash.of( ...
        display.getModel());
    timerCount=numel(timerfindall);
    poolBefore=gcp("nocreate");
    recovery=kssolv.modeling.provenance.RecoveryJournal(item.name);
    started=tic; nextEdit=0; nextSample=0;
    editInterval=options.durationSeconds/options.editCount;
    sampleElapsed=zeros(0,1); sampleRss=zeros(0,1);
    while toc(started)<options.durationSeconds
        elapsed=toc(started);
        while report.editCountCompleted<options.editCount && elapsed>=nextEdit
            index=report.editCountCompleted+1;
            vector=[(-1)^index*1e-4,mod(index,3)*1e-6,0];
            transaction=display.previewModelingCommand( ...
                "translate_atoms",struct("indices",1,"vector",vector, ...
                "fractional",false));
            transaction.preview();
            display.commitModelingTransaction(transaction,"P10 soak edit");
            report.editCountCompleted=index;
            nextEdit=index*editInterval;
            elapsed=toc(started);
        end
        if elapsed>=nextSample
            sampleElapsed(end+1,1)=elapsed; %#ok<AGROW>
            sampleRss(end+1,1)=residentBytes(); %#ok<AGROW>
            nextSample=nextSample+options.sampleSeconds;
            writetable(table(sampleElapsed,sampleRss, ...
                VariableNames=["ElapsedSeconds","ResidentBytes"]), ...
                fullfile(outputDirectory,report.samplesFile));
        end
        drawnow limitrate
        pause(min(.1,max(options.durationSeconds-toc(started),0)));
    end
    while report.editCountCompleted<options.editCount
        index=report.editCountCompleted+1;
        transaction=display.previewModelingCommand( ...
            "translate_atoms",struct("indices",1, ...
            "vector",[(-1)^index*1e-4,mod(index,3)*1e-6,0], ...
            "fractional",false));
        transaction.preview();
        display.commitModelingTransaction(transaction,"P10 soak edit");
        report.editCountCompleted=index;
    end
    report.durationActualSeconds=toc(started);
    sampleElapsed(end+1,1)=report.durationActualSeconds;
    sampleRss(end+1,1)=residentBytes();
    sampleTable=table(sampleElapsed,sampleRss, ...
        VariableNames=["ElapsedSeconds","ResidentBytes"]);
    writetable(sampleTable,fullfile(outputDirectory,report.samplesFile));
    stableStart=min(options.warmupSeconds,options.durationSeconds/2);
    stableTable=sampleTable(sampleTable.ElapsedSeconds>=stableStart,:);
    report.stableSampleCount=height(stableTable);
    window=min(5,height(stableTable));
    report.stableBaselineBytes=median( ...
        stableTable.ResidentBytes(1:window),"omitnan");
    report.stableFinalBytes=median( ...
        stableTable.ResidentBytes(end-window+1:end),"omitnan");
    report.rssGrowthFraction=(report.stableFinalBytes- ...
        report.stableBaselineBytes)/max(report.stableBaselineBytes,1);
    report.finalRevision=display.getRevision();
    display.saveChangesToProject();
    assert(~recovery.exists());
    assert(kssolv.modeling.provenance.CanonicalHash.of( ...
        display.getModel())~=baselineHash);
    exportapp(display.Document.Figure, ...
        fullfile(outputDirectory,"p10-four-hour-final.png"));
    delete(display.Document); delete(display); drawnow
    registry=kssolv.ui.features.modeling.SessionRegistry.getInstance();
    report.remainingModelingSessions=registry.count();
    report.timerDelta=numel(timerfindall)-timerCount;
    poolAfter=gcp("nocreate");
    report.parallelPoolCreated=isempty(poolBefore)&&~isempty(poolAfter);
    report.temporaryFiles=numel(dir(fullfile(recovery.Directory,"*.tmp")));
    report.qualified=options.durationSeconds>=minimumDuration && ...
        report.durationActualSeconds>=minimumDuration && ...
        report.editCountCompleted>=minimumEdits;
    enoughStableSamples=~options.requireQualification || ...
        report.stableSampleCount>=10;
    resourcesClean=report.timerDelta==0 && report.temporaryFiles==0 && ...
        ~report.parallelPoolCreated && ...
        report.remainingModelingSessions==0;
    report.passed=report.editCountCompleted==options.editCount && ...
        report.finalRevision==options.editCount && resourcesClean && ...
        enoughStableSamples && report.rssGrowthFraction<=.10 && ...
        (~options.requireQualification || report.qualified);
    assert(report.passed,"KSSOLV:Modeling:SoakFailed", ...
        "P10 soak resource or qualification gate failed.");
catch exception
    report.durationActualSeconds=toc(startedIfDefined());
    report.error=string(getReport(exception,"extended","hyperlinks","off"));
end
report.finishedAt=string(datetime("now"));
writeText(fullfile(outputDirectory,"report.json"), ...
    jsonencode(report,PrettyPrint=true));
if ~report.passed
    error("KSSOLV:Modeling:AcceptanceP10Soak","%s",report.error);
end
clear cleanup

    function value=startedIfDefined()
        if exist("started","var"), value=started; else, value=tic; end
    end
end

function value=residentBytes()
[status,text]=system("ps -o rss= -p "+string(matlabProcessID));
if status~=0, value=NaN; else, value=str2double(strtrim(text))*1024; end
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
