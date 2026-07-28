classdef Nwchem2Fiesta < kssolv.analysis.matgenlab.util.MSONable
    %NWCHEM2FIESTA Explicit runner for the NWCHEM2FIESTA converter.

    properties
        executor = []
    end

    properties (SetAccess = private)
        folder (1,1) string
        filename (1,1) string
        log_file (1,1) string
    end

    properties (Access = private)
        NWCHEM2FIESTA_cmd (1,1) string = "NWCHEM2FIESTA"
        nwcheminput_fn (1,1) string
        nwchemoutput_fn (1,1) string
        nwchemmovecs_fn (1,1) string
    end

    methods
        function obj = Nwchem2Fiesta(folder, filename, logFile, executor)
            if nargin < 2, filename = "nwchem"; end
            if nargin < 3, logFile = "log_n2f"; end
            if nargin < 4, executor = []; end
            obj.folder = string(folder);
            obj.filename = string(filename);
            obj.log_file = string(logFile);
            obj.executor = executor;
            obj.nwcheminput_fn = obj.filename + ".nw";
            obj.nwchemoutput_fn = obj.filename + ".nwout";
            obj.nwchemmovecs_fn = obj.filename + ".movecs";
        end

        function run(obj)
            commandArguments = [obj.nwcheminput_fn, obj.nwchemoutput_fn, ...
                obj.nwchemmovecs_fn];
            output = ...
                kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                invoke(obj.executor, obj.NWCHEM2FIESTA_cmd, ...
                commandArguments, obj.folder);
            path = ...
                kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                absolute_path(obj.folder, obj.log_file);
            kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                write_text(path, output);
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.fiesta", ...
                "x_class", "Nwchem2Fiesta", ...
                "filename", obj.filename, "folder", obj.folder);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.fiesta.Nwchem2Fiesta( ...
                value.folder, value.filename);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.fiesta. ...
                Nwchem2Fiesta.from_dict(value);
        end
    end
end
