function format=get_structure_format(varargin)
%GET_STRUCTURE_FORMAT Resolve a structure handler by name or filename.
options=parseLookup(varargin{:});
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.structures();
if strlength(options.name)>0
    key=char(lower(options.name));
    if isKey(registry,key),format=registry(key);return,end
    error("KSSOLV:Matgenlab:Registry:InvalidStructureFormat", ...
        "Invalid fmt='%s'.",options.name);
end
if strlength(options.filename)==0
    error("KSSOLV:Matgenlab:Registry:Lookup", ...
        "Either fmt or filename must be provided.");
end
format=resolveFilename(registry,options.filename);
if isempty(format)
    error("KSSOLV:Matgenlab:Registry:StructureExtension", ...
        "Unrecognized extension in filename='%s'.",options.filename);
end
end
function options=parseLookup(varargin)
options=struct("name","","filename","");
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    name=lower(string(varargin{index}));
    if isfield(options,name),options.(name)=string(varargin{index+1});end
end
end
function format=resolveFilename(registry,filename)
format=[];
priority={'cif','poscar','chgcar','vasprun','cssr','json','yaml', ...
    'xsf','exciting','mcsqs','lmto','aims','fleur-inpgen','res', ...
    'pwmat','abinit-nc','prismatic'};
registered=keys(registry);
custom=registered(~ismember(registered,priority));
names=[priority,custom];
for index=1:numel(names)
    if ~isKey(registry,names{index}),continue,end
    candidate=registry(names{index});
    for pattern=candidate.patterns
        if wildcardMatch(filename,pattern{1},candidate.case_insensitive)
            format=candidate;return
        end
    end
end
end
function matched=wildcardMatch(filename,pattern,caseInsensitive)
[~,base,extension]=fileparts(char(filename));base=[base,extension];
if caseInsensitive,base=lower(base);pattern=lower(pattern);end
expression="^"+regexptranslate("wildcard",pattern)+"$";
matched=~isempty(regexp(base,expression,"once"));
end
