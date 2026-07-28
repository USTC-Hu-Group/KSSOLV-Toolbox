classdef FiestaRun < kssolv.analysis.matgenlab.util.MSONable
    %FIESTARUN Explicit-callback runner for GW and BSE FIESTA jobs.

    properties (Dependent)
        executor
    end

    properties (SetAccess = private)
        folder (1,1) string
        grid (1,:) double
        log_file (1,1) string
    end

    properties (Dependent, SetAccess = private)
        mpi_procs
    end

    properties (Access = private)
        state (1,1) ...
            kssolv.analysis.matgenlab.io.fiesta.FiestaMutableState = ...
            kssolv.analysis.matgenlab.io.fiesta.FiestaMutableState()
    end

    methods
        function obj = FiestaRun(folder, grid, logFile, executor)
            if nargin < 1 || isempty(folder), folder = pwd; end
            if nargin < 2, grid = [2, 2, 2]; end
            if nargin < 3, logFile = "log"; end
            if nargin < 4, executor = []; end
            obj.state = ...
                kssolv.analysis.matgenlab.io.fiesta.FiestaMutableState();
            obj.folder = string(folder);
            obj.grid = reshape(double(grid), 1, []);
            obj.log_file = string(logFile);
            obj.executor = executor;
        end

        function value = get.executor(obj), value = obj.state.executor; end
        function obj = set.executor(obj, value), obj.state.executor = value; end
        function value = get.mpi_procs(obj), value = obj.state.mpi_procs; end

        function run(obj)
            if numel(obj.grid) == 3
                obj.state.mpi_procs = prod(obj.grid);
                obj.gw_run();
            elseif numel(obj.grid) == 2
                obj.state.mpi_procs = prod(obj.grid);
                obj.bse_run();
            else
                error("KSSOLV:Matgenlab:Fiesta:GridSize", ...
                    "Wrong grid size: must be [nrow, ncolumn, nslice] " + ...
                    "for gw of [nrow, nslice] for bse");
            end
        end

        function bse_run(obj)
            if isnan(obj.mpi_procs)
                error("KSSOLV:Matgenlab:Fiesta:MPIProcsUnset", ...
                    "bse_run requires mpi_procs; call run first.");
            end
            commandArguments = ["-n", string(obj.mpi_procs), "bse", ...
                string(obj.grid(1)), string(obj.grid(2))];
            obj.execute(commandArguments);
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.fiesta", ...
                "x_class", "FiestaRun", "log_file", obj.log_file, ...
                "grid", obj.grid, "folder", obj.folder);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Access = private)
        function gw_run(obj)
            commandArguments = ["-n", string(obj.mpi_procs), "fiesta", ...
                string(obj.grid(1)), string(obj.grid(2)), ...
                string(obj.grid(3))];
            obj.execute(commandArguments);
        end

        function execute(obj, commandArguments)
            output = ...
                kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                invoke(obj.executor, "mpirun", commandArguments, obj.folder);
            path = ...
                kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                absolute_path(obj.folder, obj.log_file);
            kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                write_text(path, output);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.fiesta.FiestaRun( ...
                value.folder, value.grid, value.log_file);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.fiesta. ...
                FiestaRun.from_dict(value);
        end
    end
end
