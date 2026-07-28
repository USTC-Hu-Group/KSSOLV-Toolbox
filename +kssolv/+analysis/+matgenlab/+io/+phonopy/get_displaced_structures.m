function structures=get_displaced_structures( ...
        structure,atomDisp,supercellMatrix,yamlFilename,varargin)
%GET_DISPLACED_STRUCTURES Generate symmetry-inequivalent displacements.
if nargin<2||isempty(atomDisp),atomDisp=0.01;end
if nargin<3||isempty(supercellMatrix),supercellMatrix=eye(3);end
if nargin<4,yamlFilename=[];end
options=struct("is_plusminus","auto", ...
    "is_diagonal",true,"is_trigonal",false);
if isscalar(varargin)&&isstruct(varargin{1})
    supplied=varargin{1};
    names=fieldnames(supplied);
    for index=1:numel(names),options.(names{index})=supplied.(names{index});end
else
    for index=1:2:numel(varargin)
        options.(char(string(varargin{index})))=varargin{index+1};
    end
end
[perfect,translations]=kssolv.analysis.matgenlab.io.phonopy. ...
    phonopy_supercell(structure,supercellMatrix);
analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure);
dataset=analyzer.get_symmetry_dataset();
representatives=unique(double(dataset.equivalent_atoms),"stable");
directions=structure.lattice.matrix;
directions=directions./vecnorm(directions,2,2);
if ~options.is_diagonal
    directions=eye(3);
end
if options.is_trigonal
    extra=sum(directions,1);
    directions=[directions;extra/norm(extra)];
end
plusMinus=options.is_plusminus;
if ischar(plusMinus)||isstring(plusMinus)
    plusMinus=lower(string(plusMinus))=="auto"|| ...
        lower(string(plusMinus))=="true";
end
signs=1;
if logical(plusMinus),signs=[1,-1];end
structures=cell(1,1+numel(representatives)* ...
    size(directions,1)*numel(signs));
structures{1}=perfect;
displacements=zeros(numel(structures)-1,4);
output=1;
translationCount=size(translations,1);
for representative=reshape(representatives,1,[])
    atomIndex=(representative-1)*translationCount+1;
    for directionIndex=1:size(directions,1)
        for signValue=signs
            output=output+1;
            vector=signValue*atomDisp*directions(directionIndex,:);
            structures{output}=perfect.translate_sites( ...
                atomIndex,vector,frac_coords=false,to_unit_cell=true);
            displacements(output-1,:)=[atomIndex-1,vector];
        end
    end
end
if ~isempty(yamlFilename)
    writeDisplacementYaml(yamlFilename,perfect,displacements);
end
end

function writeDisplacementYaml(filename,supercell,displacements)
fid=fopen(filename,"w","n","UTF-8");
if fid<0
    error("KSSOLV:Matgenlab:Phonopy:DisplacementWrite", ...
        "Cannot write '%s'.",filename);
end
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,"natom: %d\n",supercell.num_sites);
fprintf(fid,"displacements:\n");
for index=1:size(displacements,1)
    fprintf(fid,"- atom: %d\n",displacements(index,1)+1);
    fprintf(fid,"  displacement: [ %.16g, %.16g, %.16g ]\n", ...
        displacements(index,2:4));
end
clear cleanup
end
