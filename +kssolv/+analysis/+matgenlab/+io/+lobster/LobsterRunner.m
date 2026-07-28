classdef LobsterRunner
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERRUNNER Explicit external-executable boundary for LOBSTER.
    methods (Static)
        function result = run(executable, working_directory, options)
            arguments
                executable (1,1) string
                working_directory (1,1) string = "."
                options.arguments (1,:) string = strings(1, 0)
                options.allow_external (1,1) logical = false
            end
            if ~options.allow_external
                error("KSSOLV:Matgenlab:Lobster:ExternalBoundary", ...
                    "Set allow_external=true to execute LOBSTER explicitly.");
            end
            if ~isfolder(working_directory)
                error("KSSOLV:Matgenlab:Lobster:WorkingDirectory", ...
                    "Working directory '%s' does not exist.", working_directory);
            end
            oldDirectory = pwd;
            cleanup = onCleanup(@() cd(oldDirectory));
            cd(working_directory);
            quoted = """" + replace(executable, """", "\""") + """";
            for argument = options.arguments
                quoted = quoted + " """ + replace(argument, """", "\""") + """";
            end
            [status, output] = system(quoted);
            result = struct("status", status, "output", output, ...
                "command", quoted, "working_directory", working_directory);
            if status ~= 0
                error("KSSOLV:Matgenlab:Lobster:ExternalFailure", ...
                    "LOBSTER exited with status %d: %s", status, output);
            end
        end
    end
end
