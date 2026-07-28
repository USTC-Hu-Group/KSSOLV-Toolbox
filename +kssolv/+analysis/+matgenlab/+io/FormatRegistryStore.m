classdef FormatRegistryStore
    %FORMATREGISTRYSTORE Persistent registry state shared by public helpers.
    methods (Static)
        function registry=structures(reset)
            if nargin<1,reset=false;end
            persistent structureRegistry
            if reset||isempty(structureRegistry)
                structureRegistry=containers.Map( ...
                    "KeyType","char","ValueType","any");
                registerStructureBuiltins(structureRegistry);
            end
            registry=structureRegistry;
        end
        function registry=molecules(reset)
            if nargin<1,reset=false;end
            persistent moleculeRegistry
            if reset||isempty(moleculeRegistry)
                moleculeRegistry=containers.Map( ...
                    "KeyType","char","ValueType","any");
                registerMoleculeBuiltins(moleculeRegistry);
            end
            registry=moleculeRegistry;
        end
    end
end

function registerStructureBuiltins(registry)
definitions={ ...
    "cif",{"*.cif*","*.mcif*"}; ...
    "mcif",{}; ...
    "poscar",{"*POSCAR*","*CONTCAR*","*.vasp"}; ...
    "vasp",{}; ...
    "chgcar",{"CHGCAR*","LOCPOT*"}; ...
    "locpot",{}; ...
    "vasprun",{"vasprun*.xml*"}; ...
    "cssr",{"*.cssr*"}; ...
    "json",{"*.json*","*.mson*"}; ...
    "mson",{}; ...
    "yaml",{"*.yaml*","*.yml*"}; ...
    "yml",{}; ...
    "xsf",{"*.xsf*"}; ...
    "exciting",{"input*.xml"}; ...
    "mcsqs",{"*rndstr.in*","*lat.in*","*bestsqs*"}; ...
    "lmto",{"CTRL*"}; ...
    "aims",{"geometry.in*"}; ...
    "fleur-inpgen",{"inp*.xml","*.in*","inp_*"}; ...
    "fleur",{}; ...
    "res",{"*.res"}; ...
    "pwmat",{"*.config*","*.pwmat*"}; ...
    "config",{}; ...
    "abinit-nc",{"*.nc"}; ...
    "prismatic",{"*prismatic*"}; ...
    "xyz",{}};
for index=1:size(definitions,1)
    name=definitions{index,1};patterns=definitions{index,2};
    options=handlersForStructure(name,patterns);
    registry(char(name))=kssolv.analysis.matgenlab.io. ...
        StructureFormat(name,options);
end
end

function options=handlersForStructure(name,patterns)
options=struct("patterns",{patterns},"read_str",[], ...
    "write_str",[]);
switch name
    case {"json","mson"}
        options.read_str=@readStructureJSON;
        options.write_str=@writeJSON;
    case {"yaml","yml"}
        options.read_str=@readStructureYAML;
        options.write_str=@writeJSON;
    case "cif"
        options.read_str=@readStructureCIF;
        options.write_str=@writeStructureCIF;
    case {"poscar","vasp"}
        options.read_str=@readStructurePOSCAR;
        options.write_str=@writeStructurePOSCAR;
    case "cssr"
        options.read_str=@readStructureCSSR;
        options.write_str=@writeStructureCSSR;
    case "mcsqs"
        options.read_str=@readStructureMCSQS;
        options.write_str=@writeStructureMCSQS;
    case "prismatic"
        options.write_str=@writeStructurePrismatic;
    case "exciting"
        options.read_str=@readStructureExciting;
        options.write_str=@writeStructureExciting;
    case {"pwmat","config"}
        options.read_str=@readStructurePWmat;
        options.write_str=@writeStructurePWmat;
    case "lmto"
        options.read_str=@readStructureLMTO;
        options.write_str=@writeStructureLMTO;
    case "xyz"
        options.write_str=@writeStructureXYZ;
end
end

function registerMoleculeBuiltins(registry)
definitions={ ...
    "xyz",{"*.xyz*"}; ...
    "gaussian",{"*.gjf*","*.g03*","*.g09*","*.com*","*.inp*"}; ...
    "gjf",{};"g03",{};"g09",{};"com",{};"inp",{}; ...
    "gaussian-out",{"*.out*","*.lis*","*.log*"}; ...
    "json",{"*.json*","*.mson*"};"mson",{}; ...
    "yaml",{"*.yaml*","*.yml*"};"yml",{}; ...
    "babel",{};"pdb",{"*.pdb","*.pdb.gz","*.pdb.bz2"}; ...
    "mol",{"*.mol","*.mol.gz","*.mol.bz2"}; ...
    "mdl",{"*.mdl","*.mdl.gz","*.mdl.bz2"}; ...
    "sdf",{"*.sdf","*.sdf.gz","*.sdf.bz2"}; ...
    "sd",{"*.sd","*.sd.gz","*.sd.bz2"}; ...
    "ml2",{"*.ml2","*.ml2.gz","*.ml2.bz2"}; ...
    "sy2",{"*.sy2","*.sy2.gz","*.sy2.bz2"}; ...
    "mol2",{"*.mol2","*.mol2.gz","*.mol2.bz2"}; ...
    "cml",{"*.cml","*.cml.gz","*.cml.bz2"}; ...
    "mrv",{"*.mrv","*.mrv.gz","*.mrv.bz2"}};
for index=1:size(definitions,1)
    name=definitions{index,1};patterns=definitions{index,2};
    options=struct("patterns",{patterns},"read_str",[], ...
        "read_file",[],"write_str",[],"write_file",[]);
    if any(name==["json","mson"])
        options.read_str=@readMoleculeJSON;options.write_str=@writeJSON;
    elseif any(name==["yaml","yml"])
        options.read_str=@readMoleculeYAML;options.write_str=@writeJSON;
    elseif name=="xyz"
        options.read_str=@readMoleculeXYZ;
        options.write_str=@writeMoleculeXYZ;
    elseif any(name==["gaussian","gjf","g03","g09","com","inp"])
        options.read_str=@readMoleculeGaussian;
        options.read_file=@readMoleculeGaussianFile;
        options.write_str=@writeMoleculeGaussian;
        options.write_file=@writeMoleculeGaussianFile;
    elseif name=="gaussian-out"
        options.read_str=@readMoleculeGaussianOutput;
        options.read_file=@readMoleculeGaussianOutputFile;
    elseif any(name==["pdb","mol","mdl","sdf","sd", ...
            "ml2","sy2","mol2","cml","mrv"])
        options.read_str=babelReadStringHandler(name);
        options.read_file=babelReadFileHandler(name);
        options.write_str=babelWriteStringHandler(name);
        options.write_file=babelWriteFileHandler(name);
    end
    registry(char(name))=kssolv.analysis.matgenlab.io. ...
        MoleculeFormat(name,options);
end
end

function handler=babelReadStringHandler(format)
handler=@readValue;
    function value=readValue(text,varargin)
        ignoreExtra(varargin);
        value=kssolv.analysis.matgenlab.io.babel. ...
            BabelMolAdaptor.from_str(text,format).pymatgen_mol;
    end
end
function handler=babelReadFileHandler(format)
handler=@readValue;
    function value=readValue(filename,varargin)
        ignoreExtra(varargin);
        value=kssolv.analysis.matgenlab.io.babel. ...
            BabelMolAdaptor.from_file(filename,format).pymatgen_mol;
    end
end
function handler=babelWriteStringHandler(format)
handler=@writeValue;
    function text=writeValue(value,varargin)
        ignoreExtra(varargin);
        temporary=tempname+"."+format;
        cleanup=onCleanup(@()cleanupTemporary(temporary));
        kssolv.analysis.matgenlab.io.babel. ...
            BabelMolAdaptor(value).write_file(temporary,format);
        text=string(fileread(temporary));
        clear cleanup
    end
end
function handler=babelWriteFileHandler(format)
handler=@writeValue;
    function writeValue(value,filename,varargin)
        ignoreExtra(varargin);
        kssolv.analysis.matgenlab.io.babel. ...
            BabelMolAdaptor(value).write_file(filename,format);
    end
end

function value=readStructureJSON(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.util.decode(text);
if ~isa(value,"kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:Registry:StructureJSON", ...
        "JSON does not contain a periodic structure.");
end
end
function value=readMoleculeJSON(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.util.decode(text);
if ~isa(value,"kssolv.analysis.matgenlab.core.IMolecule")
    error("KSSOLV:Matgenlab:Registry:MoleculeJSON", ...
        "JSON does not contain a molecule.");
end
end
function value=readStructureYAML(text,varargin)
ignoreExtra(varargin);
value=readYamlMSON(text);
if ~isa(value,"kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:Registry:StructureYAML", ...
        "YAML does not contain a periodic structure.");
end
end
function value=readMoleculeYAML(text,varargin)
ignoreExtra(varargin);
value=readYamlMSON(text);
if ~isa(value,"kssolv.analysis.matgenlab.core.IMolecule")
    error("KSSOLV:Matgenlab:Registry:MoleculeYAML", ...
        "YAML does not contain a molecule.");
end
end
function value=readYamlMSON(text)
temporaryPath=tempname+".yaml";
file=fopen(temporaryPath,"w","n","UTF-8");
if file<0
    error("KSSOLV:Matgenlab:Registry:YAMLTemporary", ...
        "Unable to create a temporary YAML file.");
end
pathCleanup=onCleanup(@()cleanupTemporary(temporaryPath));
fileCleanup=onCleanup(@()fclose(file));
fwrite(file,char(text),"char");
clear fileCleanup
decoded=kssolv.analysis.matgenlab.util.yaml_load(temporaryPath);
value=kssolv.analysis.matgenlab.util.fromDict(decoded,Strict=true);
clear pathCleanup
end
function cleanupTemporary(path)
if isfile(path),delete(path);end
end
function text=writeJSON(value,varargin)
ignoreExtra(varargin);
text=kssolv.analysis.matgenlab.util.encode(value);
end
function value=readStructureCIF(text,varargin)
ignoreExtra(varargin);
parser=kssolv.analysis.matgenlab.io.cif.CifParser.from_str(text);
values=parser.parse_structures(primitive=false,on_error="raise");
value=values{1};
end
function text=writeStructureCIF(value,varargin)
ignoreExtra(varargin);
text=string(kssolv.analysis.matgenlab.io.cif.CifWriter(value));
end
function value=readStructurePOSCAR(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.io.vasp.Poscar.from_str(text).structure;
end
function text=writeStructurePOSCAR(value,varargin)
ignoreExtra(varargin);
text=string(kssolv.analysis.matgenlab.io.vasp.Poscar(value));
end
function value=readStructureCSSR(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.io.Cssr.from_str(text).structure;
end
function text=writeStructureCSSR(value,varargin)
ignoreExtra(varargin);
text=string(kssolv.analysis.matgenlab.io.Cssr(value));
end
function value=readStructureMCSQS(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.io.Mcsqs.structure_from_str(text);
end
function text=writeStructureMCSQS(value,varargin)
ignoreExtra(varargin);
text=kssolv.analysis.matgenlab.io.Mcsqs(value).to_str();
end
function text=writeStructurePrismatic(value,varargin)
ignoreExtra(varargin);
text=kssolv.analysis.matgenlab.io.Prismatic(value).to_str();
end
function value=readStructureExciting(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.io.exciting. ...
    ExcitingInput.from_str(text).structure;
end
function text=writeStructureExciting(value,varargin)
ignoreExtra(varargin);
text=kssolv.analysis.matgenlab.io.exciting. ...
    ExcitingInput(value).write_string("unchanged");
end
function value=readStructurePWmat(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.io.pwmat. ...
    AtomConfig.from_str(text).structure;
end
function text=writeStructurePWmat(value,varargin)
ignoreExtra(varargin);
text=kssolv.analysis.matgenlab.io.pwmat.AtomConfig(value).get_str();
end
function value=readStructureLMTO(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.io.lmto. ...
    LMTOCtrl.from_str(text).structure;
end
function text=writeStructureLMTO(value,varargin)
ignoreExtra(varargin);
text=kssolv.analysis.matgenlab.io.lmto.LMTOCtrl(value).get_str();
end
function text=writeStructureXYZ(value,varargin)
ignoreExtra(varargin);
text=string(kssolv.analysis.matgenlab.io.xyz.XYZ(value));
end
function value=readMoleculeXYZ(text,varargin)
ignoreExtra(varargin);
value=kssolv.analysis.matgenlab.io.xyz.XYZ.from_str(text).molecule;
end
function text=writeMoleculeXYZ(value,varargin)
ignoreExtra(varargin);
text=string(kssolv.analysis.matgenlab.io.xyz.XYZ(value));
end
function value=readMoleculeGaussian(text,varargin)
ignoreExtra(varargin);
input=kssolv.analysis.matgenlab.io.GaussianInput.from_str(text);
value=input.molecule;
end
function value=readMoleculeGaussianFile(filename,varargin)
ignoreExtra(varargin);
input=kssolv.analysis.matgenlab.io.GaussianInput.from_file(filename);
value=input.molecule;
end
function text=writeMoleculeGaussian(value,varargin)
ignoreExtra(varargin);
input=kssolv.analysis.matgenlab.io.GaussianInput(value);
text=input.to_str();
end
function writeMoleculeGaussianFile(value,filename,varargin)
ignoreExtra(varargin);
input=kssolv.analysis.matgenlab.io.GaussianInput(value);
input.write_file(filename);
end
function value=readMoleculeGaussianOutput(text,varargin)
ignoreExtra(varargin);
temporaryPath=tempname+".log";
file=fopen(temporaryPath,"w","n","UTF-8");
if file<0
    error("KSSOLV:Matgenlab:Registry:GaussianTemporary", ...
        "Unable to create a temporary Gaussian output.");
end
pathCleanup=onCleanup(@()cleanupTemporary(temporaryPath));
fileCleanup=onCleanup(@()fclose(file));
fwrite(file,char(text),"char");
clear fileCleanup
output=kssolv.analysis.matgenlab.io.GaussianOutput(temporaryPath);
value=output.final_structure;
clear pathCleanup
end
function value=readMoleculeGaussianOutputFile(filename,varargin)
ignoreExtra(varargin);
output=kssolv.analysis.matgenlab.io.GaussianOutput(filename);
value=output.final_structure;
end
function ignoreExtra(values)
assert(iscell(values));
end
