function configure_pmg(args)
%CONFIGURE_PMG Dispatch a pmg configuration request with upstream priority.

if ~isstruct(args)
    error("KSSOLV:Matgenlab:PmgConfig:Arguments", ...
        "args must be a scalar struct.");
end
if present(args, "potcar_dirs")
    kssolv.analysis.matgenlab.cli.pmg_config.setup_potcars( ...
        args.potcar_dirs, "overwrite", field(args, "overwrite", false));
elseif present(args, "install")
    options = struct("work_dir", field(args, "work_dir", ""), ...
        "executor", field(args, "executor", []), ...
        "transport", field(args, "transport", []), ...
        "cleanup", field(args, "cleanup", true));
    kssolv.analysis.matgenlab.cli.pmg_config.install_software( ...
        args.install, options);
elseif present(args, "var_spec")
    options = struct("config_path", field(args, "config_path", ""), ...
        "old_config_path", field(args, "old_config_path", ""));
    kssolv.analysis.matgenlab.cli.pmg_config.add_config_var( ...
        args.var_spec, field(args, "backup", ""), options);
elseif present(args, "cp2k_data_dirs")
    kssolv.analysis.matgenlab.cli.pmg_config.setup_cp2k_data( ...
        args.cp2k_data_dirs, "overwrite", ...
        field(args, "overwrite", false));
end
end

function value = present(input, name)
if ~isfield(input, name)
    value = false;
    return
end
candidate = input.(name);
value = ~isempty(candidate);
if isstring(candidate) && all(candidate == ""), value = false; end
end

function value = field(input, name, defaultValue)
if isfield(input, name)
    value = input.(name);
else
    value = defaultValue;
end
end
