classdef SlurmArguments
    %SLURMARGUMENTS Build scheduler options from validated fields.

    methods (Static)
        function value = build(configuration)
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            parts = strings(0, 1);
            parts = appendOption(parts, "partition", ...
                configuration.Partition);
            parts = appendOption(parts, "account", configuration.Account);
            parts = appendOption(parts, "qos", configuration.QoS);
            if strlength(configuration.Walltime) > 0
                parts(end + 1) = "--time=" + configuration.Walltime;
            end
            additional = strip(configuration.AdditionalSubmitArgs);
            if strlength(additional) > 0
                unsafeTokens = [string(newline), string(char(13)), ...
                    ";", "`", "|", "&", ">", "<"];
                if any(contains(additional, unsafeTokens)) || ...
                        contains(additional, "$(")
                    error("KSSOLV:Remote:UnsafeSubmitArguments", ...
                        "Additional Slurm arguments contain unsafe shell syntax.");
                end
                parts(end + 1) = additional;
            end
            value = strjoin(parts, " ");

            function output = appendOption(output, name, item)
                item = strip(string(item));
                if strlength(item) == 0
                    return
                end
                if isempty(regexp(char(item), ...
                        '^[A-Za-z0-9_.@:+,/-]+$', 'once'))
                    error("KSSOLV:Remote:InvalidSlurmOption", ...
                        "Slurm option %s contains unsupported characters.", ...
                        name);
                end
                output(end + 1) = "--" + name + "=" + item;
            end
        end
    end
end
