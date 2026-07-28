function result = analyze_structures(args)
%ANALYZE_STRUCTURES Dispatch a pmg structure request by upstream priority.

if ~isstruct(args) || ~isscalar(args)
    error("KSSOLV:Matgenlab:PmgStructure:Arguments", ...
        "args must be a scalar struct.");
end
if present(args, "convert")
    result = kssolv.analysis.matgenlab.cli.pmg_structure.convert_fmt(args);
elseif present(args, "symmetry")
    result = ...
        kssolv.analysis.matgenlab.cli.pmg_structure.analyze_symmetry(args);
elseif present(args, "group")
    result = ...
        kssolv.analysis.matgenlab.cli.pmg_structure.compare_structures(args);
elseif present(args, "localenv")
    result = ...
        kssolv.analysis.matgenlab.cli.pmg_structure.analyze_localenv(args);
else
    result = [];
end
end

function value = present(args, name)
if ~isfield(args, name)
    value = false;
    return
end
candidate = args.(name);
value = ~isempty(candidate);
if islogical(candidate) || isnumeric(candidate)
    value = value && any(candidate ~= 0, "all");
elseif isstring(candidate) || ischar(candidate)
    value = value && any(strlength(string(candidate)) > 0, "all");
end
end
