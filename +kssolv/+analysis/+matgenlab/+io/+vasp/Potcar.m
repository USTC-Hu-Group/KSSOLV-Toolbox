classdef Potcar
    %POTCAR Ordered collection of PotcarSingle datasets.

    properties
        functional (1,1) string = "PBE"
    end

    properties (Access = private)
        items_ (1,:) cell = cell(1, 0)
    end

    properties (Dependent)
        symbols
    end

    properties (Dependent, SetAccess = private)
        spec
        count
    end

    methods
        function obj = Potcar(symbols, functional, sym_potcar_map)
            if nargin >= 2 && ~isempty(functional)
                obj.functional = string(functional);
            else
                configured = getenv("PMG_DEFAULT_FUNCTIONAL");
                if ~isempty(configured), obj.functional = string(configured); end
            end
            if nargin >= 1 && ~isempty(symbols)
                if nargin < 3, sym_potcar_map = []; end
                obj = obj.set_symbols(symbols, obj.functional, sym_potcar_map);
            end
        end

        function value = get.count(obj), value = numel(obj.items_); end

        function value = get.symbols(obj)
            value = strings(1, obj.count);
            for index = 1:obj.count
                value(index) = obj.items_{index}.symbol;
            end
        end

        function obj = set.symbols(obj, value)
            obj = obj.set_symbols(value, obj.functional);
        end

        function value = get.spec(obj)
            value = cell(1, obj.count);
            for index = 1:obj.count
                value{index} = obj.items_{index}.spec("symbol");
            end
        end

        function output = char(obj)
            if obj.count == 0, output = newline; return; end
            sections = strings(1, obj.count);
            for index = 1:obj.count
                sections(index) = strip(string(obj.items_{index}), newline);
            end
            output = char(strjoin(sections, newline) + newline);
        end

        function output = string(obj), output = string(char(obj)); end

        function obj = set_symbols(obj, symbols, functional, sym_potcar_map)
            if nargin < 3 || isempty(functional), functional = obj.functional; end
            if nargin < 4, sym_potcar_map = []; end
            symbols = reshape(string(symbols), 1, []);
            obj.items_ = cell(1, numel(symbols));
            for index = 1:numel(symbols)
                if isempty(sym_potcar_map)
                    obj.items_{index} = ...
                        kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                        from_symbol_and_functional(symbols(index), functional);
                else
                    raw = obj.mapValue(sym_potcar_map, symbols(index));
                    obj.items_{index} = ...
                        kssolv.analysis.matgenlab.io.vasp.PotcarSingle(raw);
                end
            end
            obj.functional = string(functional);
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && isscalar(reference(1).subs)
                value = obj.items_{reference(1).subs{1}};
                if numel(reference) > 1
                    [varargout{1:nargout}] = builtin( ...
                        "subsref", value, reference(2:end));
                    return
                end
                varargout{1} = value;
                return
            end
            [varargout{1:nargout}] = builtin("subsref", obj, reference);
        end

        function value = length(obj), value = obj.count; end
        function value = numel(obj, varargin) %#ok<INUSD>
            value = 1;
        end

        function write_file(obj, filename)
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, char(obj));
        end

        function write_potcar_spec(obj, filename)
            if nargin < 2, filename = "POTCAR.spec.json.gz"; end
            text = jsonencode(obj.spec, PrettyPrint = true);
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, text);
        end

        function output = as_dict(obj)
            output = struct();
            output.functional = obj.functional;
            output.symbols = obj.symbols;
            output.x_module = "pymatgen.io.vasp.inputs";
            output.x_class = "Potcar";
        end
    end

    methods (Static)
        function obj = from_str(data)
            pieces = split(string(data), "End of Dataset");
            singles = cell(1, 0);
            functions = strings(1, 0);
            previous = warning("off", ...
                "KSSOLV:Matgenlab:UnknownPotcarWarning");
            cleanup = onCleanup(@() warning(previous));
            for piece = pieces.'
                if strlength(strtrim(piece)) == 0, continue; end
                single = kssolv.analysis.matgenlab.io.vasp.PotcarSingle( ...
                    strtrim(piece) + newline + "End of Dataset" + newline);
                singles{end + 1} = single; %#ok<AGROW>
                functions(end + 1) = string(single.functional); %#ok<AGROW>
            end
            clear cleanup
            if numel(unique(functions)) > 1
                error("KSSOLV:Matgenlab:Potcar:IncompatibleFunctionals", ...
                    "File contains incompatible functionals.");
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Potcar();
            obj.items_ = singles;
            if ~isempty(functions), obj.functional = functions(1); end
        end

        function obj = from_file(filename)
            obj = kssolv.analysis.matgenlab.io.vasp.Potcar.from_str( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
        end

        function obj = from_dict(input)
            obj = kssolv.analysis.matgenlab.io.vasp.Potcar( ...
                input.symbols, input.functional);
        end

        function obj = from_spec(specification, functionals)
            if nargin < 2 || isempty(functionals)
                functionals = string(fieldnames( ...
                    kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                    functionalDirectories())).';
            end
            for functional = reshape(string(functionals), 1, [])
                singles = cell(1, 0);
                matched = true;
                for index = 1:numel(specification)
                    entry = specification{index};
                    [availableFunctions, symbols] = ...
                        kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                        identifySpec(entry);
                    location = find(availableFunctions == functional, 1);
                    if isempty(location), matched = false; break; end
                    singles{end + 1} = ...
                        kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                        from_symbol_and_functional( ...
                        symbols(location), functional); %#ok<AGROW>
                end
                if matched
                    obj = kssolv.analysis.matgenlab.io.vasp.Potcar();
                    obj.items_ = singles;
                    obj.functional = functional;
                    return
                end
            end
            error("KSSOLV:Matgenlab:Potcar:SpecMismatch", ...
                "Cannot match the POTCAR spec to one functional.");
        end
    end

    methods (Access = private)
        function value = mapValue(~, map, key)
            if isa(map, "containers.Map"), value = map(char(key));
            elseif isstruct(map)
                field = matlab.lang.makeValidName(key);
                if ~isfield(map, field)
                    error("KSSOLV:Matgenlab:Potcar:SymbolMap", ...
                        "POTCAR map does not contain '%s'.", key);
                end
                value = map.(field);
            else
                error("KSSOLV:Matgenlab:Potcar:SymbolMap", ...
                    "sym_potcar_map must be a struct or containers.Map.");
            end
        end
    end

    methods (Static, Access = private)
        function [functionals, symbols] = identifySpec(entry)
            title = string(entry.titel);
            field = matlab.lang.makeValidName(erase(title, " "));
            database = ...
                kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                statsDatabase();
            functionals = strings(1, 0);
            symbols = strings(1, 0);
            names = string(fieldnames(database)).';
            for name = names
                group = database.(char(name));
                if ~isfield(group, field), continue; end
                candidates = group.(field);
                if isstruct(candidates), candidates = num2cell(candidates); end
                if ~iscell(candidates), candidates = {candidates}; end
                for index = 1:numel(candidates)
                    candidate = candidates{index};
                    if kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                            compare_potcar_stats(entry.summary_stats, candidate)
                        functionals(end + 1) = name; %#ok<AGROW>
                        symbols(end + 1) = string(candidate.symbol); %#ok<AGROW>
                    end
                end
            end
        end
    end
end
