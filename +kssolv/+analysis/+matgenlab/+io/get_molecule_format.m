function format=get_molecule_format(varargin)
%GET_MOLECULE_FORMAT Resolve a molecule handler by name or filename.
options=struct("name","","filename","");
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    name=lower(string(varargin{index}));
    if isfield(options,name),options.(name)=string(varargin{index+1});end
end
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.molecules();
if strlength(options.name)>0
    key=char(lower(options.name));
    if isKey(registry,key),format=registry(key);return,end
    error("KSSOLV:Matgenlab:Registry:InvalidMoleculeFormat", ...
        "Invalid fmt='%s'.",options.name);
end
if strlength(options.filename)==0
    error("KSSOLV:Matgenlab:Registry:Lookup", ...
        "Either fmt or filename must be provided.");
end
format=[];priority={'xyz','gaussian','gaussian-out','json','yaml'};
registered=keys(registry);
names=[priority,registered(~ismember(registered,priority))];
for index=1:numel(names)
    if ~isKey(registry,names{index}),continue,end
    candidate=registry(names{index});
    for pattern=candidate.patterns
        [~,base,extension]=fileparts(char(options.filename));
        base=strcat(base,extension);target=pattern{1};
        if candidate.case_insensitive
            base=lower(base);target=lower(target);
        end
        expression="^"+regexptranslate("wildcard",target)+"$";
        if ~isempty(regexp(base,expression,"once"))
            format=candidate;return
        end
    end
end
if isempty(format)
    error("KSSOLV:Matgenlab:Registry:MoleculeExtension", ...
        "Cannot determine file type.");
end
end
