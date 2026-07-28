function value=get_protostructure_label_from_aflow(structure,varargin)
%GET_PROTOSTRUCTURE_LABEL_FROM_AFLOW Label with an installed AFLOW binary.
options=struct("raise_errors",false,"aflow_executable","");
options=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    options(options,varargin);
executable=localResolveExecutable(options.aflow_executable);
if strlength(executable)==0
    error("KSSOLV:Matgenlab:Prototypes:AflowNotFound", ...
        "AFLOW could not be found, please specify path to its binary "+ ...
        "with aflow_executable='...'.");
end
inputPath=string(tempname)+".vasp";
outputPath=string(tempname)+".json";
cleanup=onCleanup(@()localDeleteFiles(inputPath,outputPath));
structure.to(inputPath,"poscar");
command=localQuote(executable)+" --prototype --print=json cat < "+ ...
    localQuote(inputPath)+" > "+localQuote(outputPath);
[status,diagnostic]=system(command);
if status~=0
    error("KSSOLV:Matgenlab:Prototypes:AflowExecution", ...
        "AFLOW failed with exit status %d: %s",status,strtrim(diagnostic));
end
decoded=jsondecode(fileread(outputPath));
if ~isfield(decoded,"aflow_prototype_label")
    error("KSSOLV:Matgenlab:Prototypes:AflowOutput", ...
        "AFLOW JSON output does not contain aflow_prototype_label.");
end
parts=split(string(decoded.aflow_prototype_label),"_");
if numel(parts)<4
    error("KSSOLV:Matgenlab:Prototypes:AflowOutput", ...
        "AFLOW returned a malformed prototype label.");
end
prototypeFormula=parts(1);pearsonSymbol=parts(2);spgNum=parts(3);
elementWyckoffs=parts(4:end);
elements=split(structure.chemical_system,"-");
amounts=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    element_amounts_from_wyckoffs(elements,elementWyckoffs,spgNum);
normalized=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    prefix_wyckoff_counts(join(elementWyckoffs,"_"));
allWyckoffs=kssolv.analysis.matgenlab.analysis.prototypes. ...
    canonicalize_element_wyckoffs(normalized,spgNum);
value=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    validate_label(prototypeFormula,pearsonSymbol,spgNum,allWyckoffs, ...
    structure.chemical_system,amounts,structure.composition, ...
    logical(options.raise_errors));
clear cleanup
end

function executable=localResolveExecutable(requested)
requested=string(requested);
if strlength(requested)>0&&isfile(requested)
    executable=requested;return
end
if strlength(requested)==0,requested="aflow";end
if isempty(regexp(char(requested),'^[A-Za-z0-9_.+-]+$','once'))
    executable="";return
end
[status,output]=system("command -v "+requested);
if status==0,executable=string(strtrim(output));else,executable="";end
end

function value=localQuote(path)
path=string(path);
if contains(path,"'")
    error("KSSOLV:Matgenlab:Prototypes:Path", ...
        "AFLOW paths containing single quotes are not supported.");
end
value="'"+path+"'";
end

function localDeleteFiles(varargin)
for index=1:numel(varargin)
    if isfile(varargin{index}),delete(varargin{index});end
end
end
