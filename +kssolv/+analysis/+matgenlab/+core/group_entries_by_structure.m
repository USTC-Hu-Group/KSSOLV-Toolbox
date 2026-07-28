function groups=group_entries_by_structure(entries,varargin)
%GROUP_ENTRIES_BY_STRUCTURE Group ComputedStructureEntry objects by similarity.
options=struct(species_to_remove=[],ltol=.2,stol=.4,angle_tol=5, ...
    primitive_cell=true,scale=true,comparator=[],ncpus=[]);
for index=1:2:numel(varargin)
    key=char(lower(string(varargin{index})));
    if isfield(options,key),options.(key)=varargin{index+1};
    else,error("KSSOLV:Matgenlab:Entries:UnknownOption","Unknown option '%s'.",key);
    end
end
if ~iscell(entries),entries=num2cell(entries);end
hosts=cellfun(@(entry)host(entry.structure,options.species_to_remove,options), ...
    entries,"UniformOutput",false);
matcher=kssolv.analysis.matgenlab.core.StructureMatcher( ...
    options.ltol,options.stol,options.angle_tol, ...
    options.primitive_cell,options.scale,false,false,options.comparator);
remaining=1:numel(entries); groups=cell(1,0);
while ~isempty(remaining)
    reference=remaining(1); matches=reference;
    for candidate=remaining(2:end)
        if matcher.fit(hosts{reference},hosts{candidate})
            matches(end+1)=candidate; %#ok<AGROW>
        end
    end
    groups{end+1}=entries(matches); %#ok<AGROW>
    remaining=setdiff(remaining,matches,"stable");
end

function value=host(structure,toRemove,opt)
    value=structure;
    if ~isempty(toRemove),value=value.remove_species(toRemove);end
    if opt.primitive_cell
        try
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(value,.01,5);
            value=analyzer.find_primitive(true);
        catch
            % Match pymatgen's tolerant grouping behavior: if symmetry
            % reduction is unavailable, compare the supplied cell.
        end
    end
end
end
