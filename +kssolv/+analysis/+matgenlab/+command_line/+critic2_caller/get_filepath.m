function filepath = get_filepath(filename, warningMessage, path, suffix)
%GET_FILEPATH Select the latest matching VASP output path.
if nargin < 4, suffix = ""; end
pattern = fullfile(string(path), string(filename) + string(suffix) + "*");
entries = dir(pattern);
entries = entries(~[entries.isdir]);
if isempty(entries)
    warning("KSSOLV:Matgenlab:Critic2:MissingFile", "%s", warningMessage);
    filepath = "";
    return
end
paths = string(fullfile({entries.folder}, {entries.name}));
paths = sort(paths, "descend");
if numel(paths) > 1
    warning("KSSOLV:Matgenlab:Critic2:MultipleFiles", ...
        "Multiple files detected, using %s.", ...
        string(entries(1).folder));
end
filepath = paths(1);
end
