function [status, viewer] = parse_view(args)
%PARSE_VIEW Load and visualize a structure for the pmg view command.
if ~isstruct(args) || ~isfield(args, "filename")
    error("KSSOLV:Matgenlab:Pmg:ViewArguments", ...
        "args.filename is required.");
end
filename = firstValue(args.filename);
excluded = strings(1, 0);
if isfield(args, "exclude_bonding") && ~isempty(args.exclude_bonding)
    excluded = split(string(firstValue(args.exclude_bonding)), ",").';
    excluded = strip(excluded);
    excluded(strlength(excluded) == 0) = [];
end
structure = kssolv.analysis.matgenlab.core.Structure.from_file(filename);
if isfield(args, "viewer_factory") && ~isempty(args.viewer_factory)
    viewer = args.viewer_factory(excluded);
else
    viewer = kssolv.analysis.matgenlab.vis.StructureVis( ...
        [], true, false, true, 0.5, excluded);
end
viewer.set_structure(structure);
showViewer = true;
if isfield(args, "show"), showViewer = logical(args.show); end
if showViewer, viewer.show(); end
status = 0;
end

function value = firstValue(input)
if iscell(input), value = input{1}; else, value = input(1); end
end
