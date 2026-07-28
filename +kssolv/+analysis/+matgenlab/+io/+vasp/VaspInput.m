classdef VaspInput
    %VASPINPUT Complete set of standard and optional VASP input files.

    properties (Access = private)
        files_
        order_ (1,:) string = strings(1, 0)
        potcarFilename_ (1,1) string = "POTCAR"
    end

    properties (Dependent, SetAccess = private)
        incar
        kpoints
        poscar
        potcar
    end

    methods
        function obj = VaspInput(incar, kpoints, poscar, potcar, varargin)
            options = struct("potcar_spec",false, ...
                "optional_files",struct());
            additional = struct();
            if mod(numel(varargin), 2) ~= 0
                error("KSSOLV:Matgenlab:VaspInput:Options", ...
                    "Options must be supplied as name/value pairs.");
            end
            for index = 1:2:numel(varargin)
                name = string(varargin{index});
                if name == "potcar_spec"
                    options.potcar_spec = logical(varargin{index + 1});
                elseif name == "optional_files"
                    options.optional_files = varargin{index + 1};
                else
                    fieldName = char(name);
                    if ~isvarname(fieldName)
                        error("KSSOLV:Matgenlab:VaspInput:OptionalName", ...
                            "Optional input name '%s' is not a MATLAB field name.", ...
                            name);
                    end
                    additional.(fieldName) = varargin{index + 1};
                end
            end
            obj.files_ = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            if isa(incar, "kssolv.analysis.matgenlab.io.vasp.Incar")
                incarObject = incar.copy();
            else
                incarObject = ...
                    kssolv.analysis.matgenlab.io.vasp.Incar(incar);
            end
            if options.potcar_spec, obj.potcarFilename_ = "POTCAR.spec"; end
            obj = obj.setFile("INCAR", incarObject);
            obj = obj.setFile("KPOINTS", kpoints);
            obj = obj.setFile("POSCAR", poscar);
            obj = obj.setFile(obj.potcarFilename_, potcar);
            [names, values] = obj.mappingItems(options.optional_files);
            for index = 1:numel(names)
                obj = obj.setFile(names(index), values{index});
            end
            [names, values] = obj.mappingItems(additional);
            for index = 1:numel(names)
                obj = obj.setFile(names(index), values{index});
            end
        end

        function value = get.incar(obj), value = obj.getFile("INCAR"); end
        function value = get.kpoints(obj), value = obj.getFile("KPOINTS"); end
        function value = get.poscar(obj), value = obj.getFile("POSCAR"); end
        function value = get.potcar(obj), value = obj.getFile(obj.potcarFilename_); end

        function value = keys(obj), value = obj.order_; end

        function value = get(obj, name, default)
            if nargin < 3, default = []; end
            name = char(string(name));
            if isKey(obj.files_, name), value = obj.files_(name);
            else, value = default;
            end
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && isscalar(reference(1).subs)
                value = obj.getFile(reference(1).subs{1});
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
                return
            end
            [varargout{1:nargout}] = builtin("subsref", obj, reference);
        end

        function output = char(obj)
            lines = strings(0, 1);
            for name = obj.order_
                value = obj.getFile(name);
                lines(end + 1) = name; %#ok<AGROW>
                if isempty(value), rendered = "None";
                elseif isobject(value), rendered = string(char(value));
                else, rendered = string(value);
                end
                lines(end + 1) = rendered; %#ok<AGROW>
                lines(end + 1) = ""; %#ok<AGROW>
            end
            output = char(strjoin(lines, newline));
        end

        function output = string(obj), output = string(char(obj)); end

        function output = as_dict(obj)
            output = struct();
            for name = obj.order_
                value = obj.getFile(name);
                fieldName = name;
                if name == "POTCAR.spec", fieldName = "POTCAR_spec"; end
                if isobject(value) && ismethod(value, "as_dict")
                    output.(char(fieldName)) = value.as_dict();
                else
                    output.(char(fieldName)) = value;
                end
            end
            output.x_module = "pymatgen.io.vasp.inputs";
            output.x_class = "VaspInput";
        end

        function write_input(obj, options)
            arguments
                obj
                options.output_dir (1,1) string = "."
                options.make_dir_if_not_present (1,1) logical = true
                options.cif_name = []
                options.zip_name = []
                options.files_to_transfer = struct()
            end
            outputDirectory = options.output_dir;
            if ~isfolder(outputDirectory)
                if options.make_dir_if_not_present, mkdir(outputDirectory);
                else
                    error("KSSOLV:Matgenlab:VaspInput:Directory", ...
                        "Output directory '%s' does not exist.", outputDirectory);
                end
            end
            written = strings(1, 0);
            for name = obj.order_
                value = obj.getFile(name);
                if isempty(value), continue; end
                filename = fullfile(outputDirectory, name);
                if isobject(value) && ismethod(value, "write_file")
                    value.write_file(filename);
                else
                    kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                        writeText(filename, string(value));
                end
                written(end + 1) = name; %#ok<AGROW>
            end
            if ~isempty(options.cif_name)
                cifPath = fullfile(outputDirectory, string(options.cif_name));
                writer = kssolv.analysis.matgenlab.io.cif.CifWriter( ...
                    obj.poscar.structure);
                writer.write_file(cifPath);
                written(end + 1) = string(options.cif_name);
            end
            [transferNames, transferPaths] = ...
                obj.mappingItems(options.files_to_transfer);
            for index = 1:numel(transferNames)
                copyfile(string(transferPaths{index}), ...
                    fullfile(outputDirectory, transferNames(index)), "f");
            end
            if ~isempty(options.zip_name)
                archive = fullfile(outputDirectory, string(options.zip_name));
                sources = arrayfun(@(name) fullfile(outputDirectory, name), ...
                    written);
                zip(archive, sources);
                for source = sources
                    if isfile(source), delete(source); end
                end
            end
        end

        function output = copy(obj, deep)
            if nargin < 2, deep = true; end
            if deep
                output = ...
                    kssolv.analysis.matgenlab.io.vasp.VaspInput. ...
                    from_dict(obj.as_dict());
            else
                optional = struct();
                for name = obj.order_
                    if any(name == ["INCAR","KPOINTS","POSCAR",obj.potcarFilename_])
                        continue
                    end
                    optional.(char(name)) = obj.getFile(name);
                end
                output = kssolv.analysis.matgenlab.io.vasp.VaspInput( ...
                    obj.incar, obj.kpoints, obj.poscar, obj.potcar, ...
                    potcar_spec = obj.potcarFilename_ == "POTCAR.spec", ...
                    optional_files = optional);
            end
        end

        function run_vasp(obj, options)
            arguments
                obj
                options.run_dir (1,1) string = "."
                options.vasp_cmd = []
                options.output_file (1,1) string = "vasp.out"
                options.err_file (1,1) string = "vasp.err"
            end
            obj.write_input(output_dir = options.run_dir);
            command = options.vasp_cmd;
            if isempty(command)
                command = string(getenv("PMG_VASP_EXE"));
            end
            if isempty(command) || all(string(command) == "")
                error("KSSOLV:Matgenlab:VaspInput:Executable", ...
                    "No VASP executable specified.");
            end
            command = reshape(string(command), 1, []);
            quoted = arrayfun(@(token) "'" + ...
                replace(token, "'", "'\''") + "'", command);
            shell = "cd '" + replace(options.run_dir, "'", "'\''") + ...
                "' && " + strjoin(quoted, " ") + " > '" + ...
                replace(options.output_file, "'", "'\''") + "' 2> '" + ...
                replace(options.err_file, "'", "'\''") + "'";
            status = system(shell);
            if status ~= 0
                error("KSSOLV:Matgenlab:VaspInput:RunFailed", ...
                    "VASP exited with status %d.", status);
            end
        end
    end

    methods (Static)
        function obj = from_directory(input_dir, optional_files)
            if nargin < 2, optional_files = struct(); end
            base = string(input_dir);
            incar = kssolv.analysis.matgenlab.io.vasp.Incar. ...
                from_file(fullfile(base, "INCAR"));
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                from_file(fullfile(base, "POSCAR"));
            if isfile(fullfile(base, "KPOINTS"))
                kpoints = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    from_file(fullfile(base, "KPOINTS"));
            else, kpoints = [];
            end
            if isfile(fullfile(base, "POTCAR"))
                potcar = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                    from_file(fullfile(base, "POTCAR"));
                spec = false;
            elseif isfile(fullfile(base, "POTCAR.spec"))
                potcar = strtrim(fileread(fullfile(base, "POTCAR.spec")));
                spec = true;
            else, potcar = []; spec = false;
            end
            names = string(fieldnames(optional_files)).';
            parsed = struct();
            for name = names
                type = optional_files.(char(name));
                parsed.(char(name)) = type.from_file(fullfile(base, name));
            end
            obj = kssolv.analysis.matgenlab.io.vasp.VaspInput( ...
                incar, kpoints, poscar, potcar, potcar_spec = spec, ...
                optional_files = parsed);
        end

        function obj = from_dict(input)
            incar = kssolv.analysis.matgenlab.io.vasp.Incar. ...
                from_dict(input.INCAR);
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                from_dict(input.POSCAR);
            if isfield(input, "KPOINTS") && ~isempty(input.KPOINTS)
                kpoints = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    from_dict(input.KPOINTS);
            else, kpoints = [];
            end
            if isfield(input, "POTCAR")
                potcar = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                    from_dict(input.POTCAR);
                spec = false;
            elseif isfield(input, "POTCAR_spec")
                potcar = input.POTCAR_spec;
                spec = true;
            else, potcar = []; spec = false;
            end
            standard = ["INCAR","KPOINTS","POSCAR","POTCAR", ...
                "POTCAR.spec","POTCAR_spec","@module","@class", ...
                "x_module","x_class"];
            names = string(fieldnames(input)).';
            names(ismember(names, standard)) = [];
            optional = struct();
            for name = names, optional.(char(name)) = input.(char(name)); end
            obj = kssolv.analysis.matgenlab.io.vasp.VaspInput( ...
                incar, kpoints, poscar, potcar, potcar_spec = spec, ...
                optional_files = optional);
        end
    end

    methods (Access = private)
        function obj = setFile(obj, name, value)
            name = char(string(name));
            if ~isKey(obj.files_, name), obj.order_(end + 1) = string(name); end
            obj.files_(name) = value;
        end

        function value = getFile(obj, name)
            name = char(string(name));
            if ~isKey(obj.files_, name)
                error("KSSOLV:Matgenlab:VaspInput:MissingFile", ...
                    "Input file '%s' is absent.", name);
            end
            value = obj.files_(name);
        end

        function [names, values] = mappingItems(~, input)
            if isempty(input)
                names = strings(1, 0);
                values = cell(1, 0);
            elseif isa(input, "containers.Map")
                names = string(keys(input));
                values = input.values;
            elseif isstruct(input)
                names = string(fieldnames(input)).';
                values = arrayfun(@(name) input.(char(name)), names, ...
                    "UniformOutput", false);
            else
                error("KSSOLV:Matgenlab:VaspInput:Mapping", ...
                    "Optional files must be a struct or containers.Map.");
            end
        end
    end
end
