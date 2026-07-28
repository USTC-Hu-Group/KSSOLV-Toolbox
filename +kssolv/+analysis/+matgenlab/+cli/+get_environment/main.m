function [status, result, transcript] = main(options)
%MAIN Run a non-interactive ChemEnv command-line workflow.
arguments
    options.setup (1,1) logical = false
    options.message_level (1,1) string = "WARNING"
    options.configuration = []
    options.structure = []
    options.strategy = []
    options.valences = "undefined"
    options.setup_callback = []
    options.compute_callback = []
    options.Print (1,1) logical = true
end
levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"];
if ~ismember(upper(options.message_level), levels)
    error("KSSOLV:Matgenlab:ChemEnvCLI:MessageLevel", ...
        "message_level must be DEBUG, INFO, WARNING, ERROR, or CRITICAL.");
end
configuration = options.configuration;
if isempty(configuration)
    configuration = kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        ChemEnvConfig();
end
lines = strings(1, 0);
if options.setup
    if isempty(options.setup_callback)
        error("KSSOLV:Matgenlab:ChemEnvCLI:SetupCallbackRequired", ...
            "Interactive setup requires an explicitly supplied callback.");
    end
    configuration = options.setup_callback(configuration);
    lines(end + 1) = " Setup completed";
end
lines(end + 1) = "Chemical Environment package (ChemEnv)";
lines(end + 1) = string(configuration.package_options_description());
compute = options.compute_callback;
if isempty(compute)
    compute = @(config, structure, strategy, valences) ...
        kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
        compute_environments(config, "structure", structure, ...
        "strategy", strategy, "valences", valences);
end
result = compute(configuration, options.structure, ...
    options.strategy, options.valences);
lines(end + 1) = "Thank you for using the ChemEnv package";
transcript = strjoin(lines, newline) + newline;
if options.Print, fprintf("%s", transcript); end
status = 0;
end
