function report=runP7P8PolymerPackingAcceptance(outputDirectory)
%RUNP7P8POLYMERPACKINGACCEPTANCE Real GUI polymer/packing acceptance.
arguments, outputDirectory string="", end
root=workingTreeRoot();
addpath(fullfile(root,"+kssolv","+core","kssolv-3o")); evalc("KSSOLV.startup()");
if outputDirectory=="", outputDirectory=reportFolder(root,"p7-p8"); end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
report=struct("phase","P7-P8","matlabRelease",string(version("-release")), ...
    "platform",string(computer),"passed",false,"polymerAtoms",0, ...
    "blockCounts",[],"randomCounts",[],"packedAtoms",0, ...
    "densityErrorFraction",NaN,"minimumContact",NaN, ...
    "confinedAtoms",0,"polymer10000Seconds",NaN, ...
    "packing10000Seconds",NaN,"error","","outputDirectory",outputDirectory);
app=matlab.ui.container.internal.AppContainer(struct( ...
    "Title","KSSOLV P7-P8 Polymer Packing Acceptance","ToolstripEnabled",true));
cleanup=onCleanup(@()cleanupScenario(app));
try
    kssolv.ui.util.DataStorage.setData("AppContainer",app);
    tabs=matlab.ui.internal.toolstrip.TabGroup(); tabs.Tag="kssolvTabGroup";
    app.add(tabs); modeling=kssolv.ui.components.tab.ModelingTab(tabs); %#ok<NASGU>
    app.Visible=true; drawnow
    project=kssolv.services.filemanager.Project();
    item=project.findChildrenItem("Structure").createBlankMolecule(false);
    item.label="P7-P8 Polymer Packing";
    kssolv.ui.util.DataStorage.setData("Project",project);
    kssolv.modeling.provenance.RecoveryJournal(item.name).clear();
    display=kssolv.ui.components.figuredocument.MoleculeDisplay( ...
        item.data.MatgenlabObject,"",item.name); display.Display(); drawnow
    apply("build_homopolymer",struct("repeatUnit","PE", ...
        "repeatCount",5,"tacticity","syndiotactic","seed",12));
    report.polymerAtoms=display.getModel().num_sites; assert(report.polymerAtoms==32);
    apply("construct_amorphous",struct("moleculeCount",4, ...
        "density",.1,"seed",17,"tolerance",.55,"atomLimit",10000));
    packed=display.getModel(); report.packedAtoms=packed.num_sites;
    report.densityErrorFraction=abs(packed.density-.1)/.1;
    ids=cellfun(@double,packed.site_properties.molecule_id);
    report.minimumContact=minimumContact(packed.cart_coords,ids,packed.lattice.a);
    assert(report.densityErrorFraction<.005); assert(report.minimumContact>=.55-1e-12);
    assert(packed.properties.packing.state=="packed_not_equilibrated");

    blank=kssolv.analysis.matgenlab.core.Molecule( ...
        strings(1,0),zeros(0,3),charge_spin_check=false);
    block=kssolv.modeling.CommandExecutor.execute(blank,"build_block_copolymer", ...
        struct("blockKinds","PEO PPO PEO","blockLengths",[5,10,5], ...
        "seed",4)).analysis;
    report.blockCounts=block.actualCounts; assert(isequal(report.blockCounts,[10,10]));
    random=kssolv.modeling.CommandExecutor.execute(blank,"build_random_copolymer", ...
        struct("monomerKinds","PE PP","fractions",[.3,.7], ...
        "repeatCount",20,"exactComposition",true,"seed",44)).analysis;
    report.randomCounts=random.actualCounts; assert(isequal(report.randomCounts,[6,14]));

    water=makeMolecule(["O","H","H"],[0,0,0;.9572,0,0;-.239,.927,0]);
    confined=kssolv.modeling.CommandExecutor.execute(water, ...
        "build_confined_layer",struct("moleculeCount",12,"density",.25, ...
        "seed",9,"tolerance",.5,"confinementAxis",3,"region",[.05,.95]));
    report.confinedAtoms=confined.model.num_sites; assert(report.confinedAtoms==36);
    assert(confined.model.properties.packing.state=="packed_not_equilibrated");

    started=tic;
    largePolymer=kssolv.modeling.polymers.PolymerBuilder. ...
        homopolymer("PE",1666,seed=1,atomLimit=10000);
    report.polymer10000Seconds=toc(started); assert(largePolymer.num_sites==9998);
    assert(report.polymer10000Seconds<5);
    started=tic;
    largePacking=kssolv.modeling.packing.PackingBuilder.pack( ...
        {water},3333,density=.7,seed=1,tolerance=.5,atomLimit=10000);
    report.packing10000Seconds=toc(started); assert(largePacking.num_sites==9999);
    assert(report.packing10000Seconds<60);

    display.saveChangesToProject(); packed.to( ...
        fullfile(outputDirectory,"pe-amorphous.cif"),"cif");
    exportapp(display.Document.Figure,fullfile(outputDirectory,"p7-p8-packing.png"));
    report.passed=true;
catch exception
    report.error=string(getReport(exception,"extended","hyperlinks","off"));
end
writeText(fullfile(outputDirectory,"report.json"),jsonencode(report,PrettyPrint=true));
if ~report.passed, error("KSSOLV:Modeling:AcceptanceP7P8","%s",report.error); end
clear cleanup
    function apply(id,p)
        transaction=display.previewModelingCommand(id,p); transaction.preview();
        display.commitModelingTransaction(transaction,id);
    end
end

function value=makeMolecule(species,coordinates)
value=kssolv.analysis.matgenlab.core.Molecule( ...
    cellstr(species),coordinates,charge_spin_check=false);
end
function value=minimumContact(coordinates,ids,box)
value=Inf;
for first=1:size(coordinates,1)-1
    candidates=find(ids(first+1:end)~=ids(first))+first;
    if isempty(candidates), continue, end
    delta=abs(coordinates(candidates,:)-coordinates(first,:));
    delta=min(delta,box-delta);
    value=min(value,min(vecnorm(delta,2,2)));
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
