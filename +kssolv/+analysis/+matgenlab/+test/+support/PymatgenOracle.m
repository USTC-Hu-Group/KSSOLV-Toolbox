classdef PymatgenOracle
    %PYMATGENORACLE Invoke the frozen Python reference in development tests.
    %
    % Set MATGENLAB_PYTHON to the Python executable containing the pinned
    % pymatgen dependencies. This class lives under +test and is excluded
    % from packaged KSSOLV Toolbox releases.

    methods (Static)
        function response = execute(request, options)
            arguments
                request (1,1) struct
                options.Python (1,1) string = ...
                    kssolv.analysis.matgenlab.test.support.PymatgenOracle.python()
            end

            runner = fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "dev", "matgenlab", "reference_runner.py");
            if ~isfile(runner)
                error("KSSOLV:Matgenlab:Oracle:MissingRunner", ...
                    "Reference runner was not found at '%s'.", runner);
            end

            requestPath = string(tempname) + ".json";
            responsePath = string(tempname) + ".json";
            cleanup = onCleanup(@() ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle ...
                    .deleteFiles(requestPath, responsePath));

            fid = fopen(requestPath, "w", "n", "UTF-8");
            if fid < 0
                error("KSSOLV:Matgenlab:Oracle:RequestWriteFailed", ...
                    "Cannot create reference request '%s'.", requestPath);
            end
            fileCleanup = onCleanup(@() fclose(fid));
            fwrite(fid, kssolv.analysis.matgenlab.util.encode(request), "char");
            clear fileCleanup

            command = sprintf('"%s" "%s" --request "%s" --response "%s"', ...
                options.Python, runner, requestPath, responsePath);
            [status, output] = system(command);
            if ~isfile(responsePath)
                error("KSSOLV:Matgenlab:Oracle:ExecutionFailed", ...
                    "Reference runner failed with status %d: %s", ...
                    status, strtrim(output));
            end

            response = jsondecode(fileread(responsePath));
            if status ~= 0 || ~response.ok
                error("KSSOLV:Matgenlab:Oracle:ReferenceError", ...
                    "pymatgen raised %s: %s", ...
                    response.error.type, response.error.message);
            end
            clear cleanup
        end

        function executable = python()
            executable = string(getenv("MATGENLAB_PYTHON"));
            if executable == ""
                executable = "python3";
            end
        end

        function available = isAvailable()
            executable = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle.python();
            command = sprintf('"%s" -c "import pymatgen, monty"', executable);
            available = system(command) == 0;
        end
    end

    methods (Static, Access = private)
        function deleteFiles(varargin)
            for index = 1:nargin
                path = varargin{index};
                if isfile(path)
                    delete(path);
                end
            end
        end
    end
end
