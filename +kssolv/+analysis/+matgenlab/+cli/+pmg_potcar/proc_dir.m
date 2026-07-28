function visited = proc_dir(dirname, proc_file_function)
%PROC_DIR Recursively process every file below an explicit directory.

root = scalarPath(dirname, "dirname");
if ~isfolder(root)
    error("KSSOLV:Matgenlab:PmgPotcar:DirectoryMissing", ...
        "Directory does not exist: %s", root);
end
if ~isa(proc_file_function, "function_handle")
    error("KSSOLV:Matgenlab:PmgPotcar:Callback", ...
        "proc_file_function must be a function handle.");
end

listing = dir(root);
names = string({listing.name});
listing = listing(names ~= "." & names ~= "..");
visited = strings(1, 0);
for index = 1:numel(listing)
    name = string(listing(index).name);
    if listing(index).isdir
        nested = kssolv.analysis.matgenlab.cli.pmg_potcar.proc_dir( ...
            fullfile(root, name), proc_file_function);
        visited = [visited, nested]; %#ok<AGROW>
    else
        proc_file_function(root, name);
        visited(end + 1) = fullfile(root, name); %#ok<AGROW>
    end
end
end

function path = scalarPath(value, name)
path = string(value);
if ~isscalar(path) || ismissing(path) || strlength(path) == 0
    error("KSSOLV:Matgenlab:PmgPotcar:Path", ...
        "%s must be a nonempty scalar path.", name);
end
path = string(char(java.io.File(char(path)).getCanonicalPath()));
end
