classdef JDFTXRunner
    %JDFTXRUNNER Explicit opt-in boundary for launching a JDFTx executable.
    methods (Static)
        function result = run(executable, options)
            arguments
                executable
                options.input_file = []
                options.working_directory string = pwd
                options.arguments string = strings(0, 1)
                options.allow_external (1, 1) logical = false
            end
            if ~options.allow_external
                error("KSSOLV:Matgenlab:JDFTX:ExternalBoundary", ...
                    "External execution requires allow_external=true.");
            end
            executable = string(executable);
            if ~isfile(executable)
                error("KSSOLV:Matgenlab:JDFTX:MissingExecutable", ...
                    "Executable '%s' does not exist.", executable);
            end
            arguments_value = options.arguments;
            if ~isempty(options.input_file)
                arguments_value = ["-i", string(options.input_file), ...
                    arguments_value(:).'];
            end
            quoted = compose("'%s'", replace(arguments_value, "'", "'\''"));
            command = "cd '" + replace(options.working_directory, ...
                "'", "'\''") + "' && '" + replace(executable, "'", ...
                "'\''") + "'";
            if ~isempty(quoted)
                command = command + " " + join(quoted, " ");
            end
            [status, output] = system(command);
            result = struct("status", status, "output", string(output), ...
                "command", command);
        end
    end
end
