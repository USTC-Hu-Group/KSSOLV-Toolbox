function report=runP5P6CrystalSurfaceAcceptance(outputDirectory)
%RUNP5P6CRYSTALSURFACEACCEPTANCE Real GUI crystal/surface acceptance.
arguments, outputDirectory string="", end
root=workingTreeRoot();
addpath(fullfile(root,"+kssolv","+core","kssolv-3o")); evalc("KSSOLV.startup()");
if outputDirectory=="", outputDirectory=reportFolder(root,"p5-p6"); end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
report=struct("phase","P5-P6","matlabRelease",string(version("-release")), ...
    "platform",string(computer),"passed",false,"spaceGroup",0, ...
    "defectDegeneracy",0,"supercellAtoms",0,"slabAtoms",0, ...
    "vacuumError",NaN,"adsorptionSites",0,"moireAngleError",NaN, ...
    "adsorbateHeightError",NaN, ...
    "historyRecords",0,"error","","outputDirectory",outputDirectory);
app=matlab.ui.container.internal.AppContainer(struct( ...
    "Title","KSSOLV P5-P6 Crystal Surface Acceptance","ToolstripEnabled",true));
cleanup=onCleanup(@()cleanupScenario(app));
try
    kssolv.ui.util.DataStorage.setData("AppContainer",app);
    tabs=matlab.ui.internal.toolstrip.TabGroup(); tabs.Tag="kssolvTabGroup";
    app.add(tabs); modeling=kssolv.ui.components.tab.ModelingTab(tabs); %#ok<NASGU>
    app.Visible=true; drawnow
    project=kssolv.services.filemanager.Project();
    item=project.findChildrenItem("Structure").createBlankStructure(false);
    item.label="P5-P6 Crystal Surface";
    kssolv.ui.util.DataStorage.setData("Project",project);
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();
    display=kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        item.data.MatgenlabObject,"",item.name); display.Display(); drawnow

    apply("build_from_spacegroup",struct("spaceGroup","Fm-3m", ...
        "lattice",eye(3)*3.92,"species","Pt", ...
        "fractionalCoordinates",[0,0,0]));
    symmetry=analysis("find_symmetry",struct("symprec",.001,"angleTolerance",5));
    report.spaceGroup=symmetry.number; assert(report.spaceGroup==225);
    defects=analysis("enumerate_point_defects",struct("defectType","vacancy"));
    report.defectDegeneracy=defects.degeneracies; assert(report.defectDegeneracy==4);
    apply("build_supercell",struct("scalingMatrix",[2,1,1]));
    report.supercellAtoms=display.getModel().num_sites; assert(report.supercellAtoms==8);
    apply("create_point_defects",struct("defectType","vacancy","indices",1));
    assert(display.getModel().num_sites==7); display.undo(); display.redo();

    % Rebuild pristine Pt and execute the production slab/vacuum workflow.
    apply("build_from_spacegroup",struct("spaceGroup","Fm-3m", ...
        "lattice",eye(3)*3.92,"species","Pt", ...
        "fractionalCoordinates",[0,0,0]));
    apply("build_slab",struct("millerIndex",[1,1,1], ...
        "slabSize",8,"vacuumSize",12,"centerSlab",true,"primitive",true));
    report.slabAtoms=display.getModel().num_sites;
    before=display.getModel().lattice.c;
    apply("add_vacuum",struct("amount",5));
    report.vacuumError=abs((display.getModel().lattice.c-before)-5);
    sites=analysis("find_adsorption_sites",struct("distance",2));
    report.adsorptionSites=sum(structfun(@(values)size(values,1),sites));
    assert(report.vacuumError<.01); assert(report.adsorptionSites>0);
    adsorbate=kssolv.analysis.matgenlab.core.Molecule( ...
        ["O","H"],[0,0,0;0,0,1],charge_spin_check=false);
    apply("place_adsorbate",struct("adsorbateModel",adsorbate, ...
        "siteType","ontop","siteIndex",1,"height",2, ...
        "anchorAtom",1,"orientationAtom",2,"direction",[0,0,1], ...
        "minimumDistance",.1));
    report.adsorbateHeightError=abs( ...
        display.getModel().properties.adsorbate.siteDescriptor.offset-2);
    assert(report.adsorbateHeightError<.01);

    graphene=kssolv.modeling.test.ModelingFunctionalTestUtils.graphene();
    moire=kssolv.modeling.CommandExecutor.execute(graphene,"twist_moire", ...
        struct("otherModel",graphene.copy(),"angleDegrees",21.786789, ...
        "gap",3.35,"vacuum",15,"maximumStrain",.03, ...
        "maximumAtoms",1000,"maximumIndex",8)).model;
    report.moireAngleError=moire.properties.moire.angle_error_degrees;
    assert(report.moireAngleError<1e-5);
    report.historyRecords=display.getRevision();
    display.saveChangesToProject();
    display.getModel().to(fullfile(outputDirectory,"pt111.cif"),"cif");
    exportapp(display.Document.Figure,fullfile(outputDirectory,"p5-p6-pt111.png"));
    report.passed=true;
catch exception
    report.error=string(getReport(exception,"extended","hyperlinks","off"));
end
writeText(fullfile(outputDirectory,"report.json"),jsonencode(report,PrettyPrint=true));
if ~report.passed, error("KSSOLV:Modeling:AcceptanceP5P6","%s",report.error); end
clear cleanup
    function apply(id,p)
        transaction=display.previewModelingCommand(id,p); transaction.preview();
        display.commitModelingTransaction(transaction,id);
    end
    function value=analysis(id,p)
        result=kssolv.modeling.CommandExecutor.execute(display.getModel(),id,p);
        if isfield(result,"data"), value=result.data; else, value=result.analysis; end
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
