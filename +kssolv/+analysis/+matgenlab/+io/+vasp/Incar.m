classdef Incar
    %INCAR Case-insensitive VASP INCAR mapping.
    %
    % Native MATLAB port of pymatgen-core v2026.7.24
    % pymatgen.io.vasp.inputs.Incar.

    properties (Access = private)
        data_
        keyOrder_ (1,:) string = strings(1, 0)
    end

    properties (Dependent, SetAccess = private)
        count
    end

    methods
        function obj = Incar(params)
            obj.data_ = containers.Map("KeyType", "char", "ValueType", "any");
            if nargin == 0 || isempty(params), return; end
            [names, values] = obj.mappingItems(params);
            normalized = upper(strtrim(names));
            duplicateNames = unique(normalized(histcounts( ...
                categorical(normalized), categorical(unique(normalized))) > 1));
            if ~isempty(duplicateNames)
                warning("KSSOLV:Matgenlab:BadIncarWarning", ...
                    "Duplicate keys found (case-insensitive): [%s]", ...
                    strjoin("'" + duplicateNames + "'", ", "));
            end
            for index = 1:numel(names)
                obj = obj.set(names(index), values{index});
            end
            if obj.contains("MAGMOM") && ...
                    (obj.truthy(obj.get("LSORBIT", false)) || ...
                    obj.truthy(obj.get("LNONCOLLINEAR", false)))
                moments = obj.get("MAGMOM");
                if isnumeric(moments) && isvector(moments) && ...
                        mod(numel(moments), 3) == 0
                    obj = obj.set("MAGMOM", reshape(moments, 3, []).');
                end
            end
        end

        function value = get.count(obj), value = obj.data_.Count; end

        function names = keys(obj), names = obj.keyOrder_; end

        function output = values(obj)
            output = cell(1, numel(obj.keyOrder_));
            for index = 1:numel(obj.keyOrder_)
                output{index} = obj.data_(char(obj.keyOrder_(index)));
            end
        end

        function tf = contains(obj, key)
            tf = isKey(obj.data_, obj.normalizeKey(key));
        end

        function value = get(obj, key, default)
            if nargin < 3, default = []; end
            normalized = obj.normalizeKey(key);
            if isKey(obj.data_, normalized), value = obj.data_(normalized);
            else, value = default;
            end
        end

        function obj = set(obj, key, value)
            normalized = obj.normalizeKey(key);
            if (ischar(value) || (isstring(value) && isscalar(value))) || ...
                    (isnumeric(value) && isscalar(value) && isreal(value))
                value = kssolv.analysis.matgenlab.io.vasp.Incar. ...
                    proc_val(normalized, char(string(value)));
            end
            if ~isKey(obj.data_, normalized)
                obj.keyOrder_(end + 1) = string(normalized);
            end
            obj.data_(normalized) = value;
        end

        function obj = remove(obj, key)
            normalized = obj.normalizeKey(key);
            if isKey(obj.data_, normalized)
                remove(obj.data_, normalized);
                obj.keyOrder_(obj.keyOrder_ == normalized) = [];
            end
        end

        function obj = update(obj, params)
            [names, values] = obj.mappingItems(params);
            for index = 1:numel(names)
                obj = obj.set(names(index), values{index});
            end
        end

        function [obj, value] = setdefault(obj, key, default)
            if obj.contains(key), value = obj.get(key);
            else
                obj = obj.set(key, default);
                value = obj.get(key);
            end
        end

        function [obj, value] = pop(obj, key, default)
            exists = obj.contains(key);
            if exists
                value = obj.get(key);
                obj = obj.remove(key);
            elseif nargin >= 3
                value = default;
            else
                error("KSSOLV:Matgenlab:Incar:MissingKey", ...
                    "INCAR key '%s' is not present.", key);
            end
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && isscalar(reference(1).subs)
                value = obj.get(reference(1).subs{1}, ...
                    kssolv.analysis.matgenlab.io.vasp.Incar.missingSentinel());
                if isstruct(value) && ...
                        isfield(value, "matgenlab_missing_")
                    error("KSSOLV:Matgenlab:Incar:MissingKey", ...
                        "INCAR key '%s' is not present.", ...
                        string(reference(1).subs{1}));
                end
                if numel(reference) > 1, value = builtin("subsref", value, reference(2:end)); end
                varargout{1} = value;
                return
            end
            [varargout{1:nargout}] = builtin("subsref", obj, reference);
        end

        function obj = subsasgn(obj, reference, value)
            if strcmp(reference(1).type, "()") && isscalar(reference(1).subs)
                if isscalar(reference)
                    obj = obj.set(reference(1).subs{1}, value);
                else
                    current = obj.get(reference(1).subs{1});
                    current = builtin("subsasgn", current, reference(2:end), value);
                    obj = obj.set(reference(1).subs{1}, current);
                end
                return
            end
            obj = builtin("subsasgn", obj, reference, value);
        end

        function tf = eq(obj, other)
            if ~isa(other, "kssolv.analysis.matgenlab.io.vasp.Incar")
                tf = false;
                return
            end
            if obj.count ~= other.count
                tf = false;
                return
            end
            tf = all(arrayfun(@(name) other.contains(name) && ...
                isequaln(obj.get(name), other.get(name)), obj.keyOrder_));
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end

        function output = plus(obj, other)
            if ~isa(other, "kssolv.analysis.matgenlab.io.vasp.Incar")
                error("KSSOLV:Matgenlab:Incar:AddType", ...
                    "Both operands must be Incar objects.");
            end
            output = obj.copy();
            for name = other.keyOrder_
                if output.contains(name) && ...
                        ~isequaln(output.get(name), other.get(name))
                    error("KSSOLV:Matgenlab:Incar:Conflict", ...
                        "INCARs have conflicting values for %s.", name);
                end
                output = output.set(name, other.get(name));
            end
        end

        function value = char(obj)
            value = char(obj.get_str(sort_keys = true, pretty = false));
        end

        function value = string(obj), value = string(char(obj)); end

        function output = get_str(obj, options)
            arguments
                obj
                options.sort_keys (1,1) logical = false
                options.pretty (1,1) logical = false
            end
            names = obj.keyOrder_;
            if options.sort_keys, names = sort(names); end
            rendered = strings(numel(names), 2);
            for index = 1:numel(names)
                rendered(index, 1) = names(index);
                rendered(index, 2) = obj.renderValue(names(index), ...
                    obj.get(names(index)));
            end
            if options.pretty
                width = max(strlength(rendered(:, 1)));
                lines = strings(numel(names), 1);
                for index = 1:numel(names)
                    lines(index) = pad(rendered(index, 1), width, "right") + ...
                        "  =  " + rendered(index, 2);
                end
                output = strjoin(lines, newline);
            else
                output = strjoin(rendered(:, 1) + " = " + ...
                    rendered(:, 2), newline);
                output = output + newline;
            end
        end

        function write_file(obj, filename)
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, char(obj));
        end

        function output = as_dict(obj)
            output = struct();
            for name = obj.keyOrder_
                output.(char(name)) = obj.get(name);
            end
            output.x_module = "pymatgen.io.vasp.inputs";
            output.x_class = "Incar";
        end

        function output = copy(obj)
            output = kssolv.analysis.matgenlab.io.vasp.Incar(obj);
        end

        function output = diff(obj, other)
            same = struct();
            different = struct();
            allNames = unique([obj.keyOrder_, other.keyOrder_], "stable");
            for name = allNames
                inFirst = obj.contains(name);
                inSecond = other.contains(name);
                if inFirst && inSecond && isequaln(obj.get(name), other.get(name))
                    same.(char(name)) = obj.get(name);
                else
                    entry = struct("INCAR1", [], "INCAR2", []);
                    if inFirst, entry.INCAR1 = obj.get(name); end
                    if inSecond, entry.INCAR2 = other.get(name); end
                    different.(char(name)) = entry;
                end
            end
            output = struct("Same", same, "Different", different);
        end

        function check_params(obj)
            parameters = ...
                kssolv.analysis.matgenlab.io.vasp.Incar.parameterDatabase();
            for name = obj.keyOrder_
                if ~isfield(parameters, char(name))
                    warning("KSSOLV:Matgenlab:BadIncarWarning", ...
                        "Cannot find %s in the list of INCAR tags", name);
                    continue
                end
                specification = parameters.(char(name));
                value = obj.get(name);
                if isfield(specification, "type") && ...
                        ~isempty(specification.type) && ...
                        ~obj.matchesType(value, string(specification.type))
                    warning("KSSOLV:Matgenlab:BadIncarWarning", ...
                        "%s: %s is not a %s", name, ...
                        obj.renderValue(name, value), string(specification.type));
                end
                if isfield(specification, "values") && ...
                        ~isempty(specification.values) && ...
                        ~obj.matchesAllowed(name, value, specification.values)
                    warning("KSSOLV:Matgenlab:BadIncarWarning", ...
                        "%s: Cannot find %s in the list of values", ...
                        name, obj.renderValue(name, value));
                end
            end
        end
    end

    methods (Static)
        function obj = from_str(contents)
            text = char(string(contents));
            lines = regexp(text, "\r\n|\n|\r", "split");
            for index = 1:numel(lines)
                lines{index} = regexprep(lines{index}, "[#!].*$", "");
                lines{index} = regexprep(lines{index}, "[ \t]+$", "");
            end
            text = strjoin(lines, newline);
            text = regexprep(text, "\\\s*\n", " ");
            expression = '(?ms)(\w+)\s*=\s*(".*?"|[^;\n]*)';
            tokens = regexp(text, expression, "tokens");
            names = strings(1, numel(tokens));
            values = cell(1, numel(tokens));
            for index = 1:numel(tokens)
                token = tokens{index};
                names(index) = string(token{1});
                raw = strtrim(token{2});
                if numel(raw) >= 2 && raw(1) == '"' && raw(end) == '"'
                    raw = regexprep(raw(2:end - 1), "[ \t]+$", "");
                end
                values{index} = ...
                    kssolv.analysis.matgenlab.io.vasp.Incar. ...
                    proc_val(upper(strtrim(names(index))), raw);
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Incar( ...
                struct("names", names, "values", {values}));
        end

        function obj = from_file(filename)
            obj = kssolv.analysis.matgenlab.io.vasp.Incar.from_str( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
        end

        function obj = from_dict(input)
            if isstruct(input)
                names = string(fieldnames(input)).';
                names(startsWith(names, "@") | ...
                    ismember(names, ["x_module", "x_class"])) = [];
                values = arrayfun(@(name) input.(char(name)), names, ...
                    "UniformOutput", false);
                obj = kssolv.analysis.matgenlab.io.vasp.Incar( ...
                    struct("names", names, "values", {values}));
            else
                obj = kssolv.analysis.matgenlab.io.vasp.Incar(input);
            end
        end

        function output = proc_val(key, val)
            key = upper(strtrim(string(key)));
            val = strtrim(char(string(val)));
            parameters = ...
                kssolv.analysis.matgenlab.io.vasp.Incar.parameterDatabase();
            types = strings(1, 0);
            if isfield(parameters, char(key)) && ...
                    isfield(parameters.(char(key)), "type")
                types = strtrim(split(string(parameters.(char(key)).type), "|")).';
            end
            if key == "ML_MODE", output = lower(string(val)); return; end
            if any(key == ["SYSTEM", "WANNIER90_WIN"])
                output = string(val);
                return
            end
            try
                if any(types == "list")
                    output = ...
                        kssolv.analysis.matgenlab.io.vasp.Incar.parseList(val);
                    if ~isempty(output), return; end
                end
                if any(types == "bool")
                    match = regexp(val, "^\.?([TtFf])[A-Za-z]*\.?", ...
                        "tokens", "once");
                    if ~isempty(match)
                        output = lower(string(match{1})) == "t";
                        return
                    end
                    if isscalar(types), error("InvalidBoolean"); end
                end
                if any(types == "float")
                    match = regexp(val, "^-?\d*\.?\d*(?:[eE][-+]?\d+)?", ...
                        "match", "once");
                    output = str2double(match);
                    if ~isnan(output), return; end
                end
                if any(types == "int")
                    match = regexp(val, "^-?[0-9]+", "match", "once");
                    if ~isempty(match), output = int64(str2double(match)); return; end
                end
            catch
            end
            integer = regexp(val, "^[+-]?\d+$", "match", "once");
            if ~isempty(integer), output = int64(str2double(integer)); return; end
            numeric = str2double(val);
            if ~isnan(numeric), output = numeric; return; end
            lowerValue = lower(string(val));
            if contains(lowerValue, "true"), output = true; return; end
            if contains(lowerValue, "false"), output = false; return; end
            output = string(lowerValue);
            if strlength(output) > 0
                output = upper(extractBefore(output, 2)) + extractAfter(output, 1);
            end
        end
    end

    methods (Access = private)
        function [names, values] = mappingItems(~, input)
            if isa(input, "kssolv.analysis.matgenlab.io.vasp.Incar")
                names = input.keys();
                values = input.values();
            elseif isa(input, "containers.Map")
                names = string(keys(input));
                values = input.values;
            elseif isstruct(input) && all(isfield(input, ["names", "values"]))
                names = reshape(string(input.names), 1, []);
                values = reshape(input.values, 1, []);
            elseif isstruct(input)
                names = string(fieldnames(input)).';
                values = arrayfun(@(name) input.(char(name)), names, ...
                    "UniformOutput", false);
            else
                error("KSSOLV:Matgenlab:Incar:Mapping", ...
                    "params must be an Incar, struct, or containers.Map.");
            end
        end

        function key = normalizeKey(~, input)
            key = char(upper(strtrim(string(input))));
            if isempty(key)
                error("KSSOLV:Matgenlab:Incar:Key", ...
                    "INCAR keys cannot be empty.");
            end
        end

        function output = renderValue(obj, key, value)
            if key == "MAGMOM" && isnumeric(value) && ~isempty(value)
                noncollinear = obj.truthy(obj.get("LSORBIT", false)) || ...
                    obj.truthy(obj.get("LNONCOLLINEAR", false));
                if size(value, 2) == 3 && noncollinear
                    output = strjoin(arrayfun(@obj.renderMagmomScalar, ...
                        reshape(value.', 1, [])), " ");
                    return
                end
                vector = reshape(value, 1, []);
                if noncollinear
                    output = obj.runLength(vector, true);
                else
                    output = obj.runLength(vector, false);
                end
            elseif iscell(value)
                output = strjoin(cellfun(@(item) obj.renderListScalar(item), ...
                    value, "UniformOutput", false), " ");
            elseif (isnumeric(value) || islogical(value)) && ~isscalar(value)
                output = strjoin(arrayfun(@obj.renderListScalar, ...
                    reshape(value, 1, [])), " ");
            else
                output = obj.renderScalar(value, false);
            end
        end

        function output = runLength(obj, values, triple)
            parts = strings(1, 0);
            start = 1;
            while start <= numel(values)
                finish = start;
                while finish < numel(values) && ...
                        isequaln(values(finish + 1), values(start))
                    finish = finish + 1;
                end
                runCount = finish - start + 1;
                if triple
                    parts(end + 1) = "3*" + runCount + "*" + ...
                        obj.renderMagmomScalar(values(start)); %#ok<AGROW>
                else
                    parts(end + 1) = runCount + "*" + ...
                        obj.renderMagmomScalar(values(start)); %#ok<AGROW>
                end
                start = finish + 1;
            end
            output = strjoin(parts, " ");
        end

        function output = renderListScalar(obj, value)
            output = obj.renderScalar(value, true);
        end

        function output = renderMagmomScalar(obj, value)
            if isa(value, "double") && isfinite(value) && value == fix(value)
                output = sprintf("%.1f", value);
            else
                output = obj.renderScalar(value, true);
            end
        end

        function output = renderScalar(~, value, listContext)
            if islogical(value)
                if value, output = "True"; else, output = "False"; end
            elseif isinteger(value)
                output = string(value);
            elseif isnumeric(value)
                if listContext && isfinite(value) && value == fix(value)
                    output = sprintf("%.0f", value);
                elseif isfinite(value) && value == fix(value)
                    output = sprintf("%.1f", value);
                else
                    output = string(sprintf("%.15g", value));
                end
            else
                output = string(value);
            end
        end

        function tf = truthy(~, value)
            tf = (islogical(value) || isnumeric(value)) && ...
                isscalar(value) && logical(value);
        end

        function tf = matchesType(~, value, typeText)
            pieces = strtrim(split(typeText, "|"));
            tf = false;
            for piece = pieces.'
                switch piece
                    case "bool", tf = tf || islogical(value);
                    case "float", tf = tf || isa(value, "double") && isscalar(value);
                    case "int", tf = tf || isinteger(value) && isscalar(value);
                    case "str", tf = tf || ischar(value) || isstring(value);
                    case "list", tf = tf || iscell(value) || ...
                            ((isnumeric(value) || islogical(value)) && ~isscalar(value));
                end
            end
        end

        function tf = matchesAllowed(~, key, value, allowed)
            if ~iscell(allowed), allowed = num2cell(allowed); end
            tf = false;
            for index = 1:numel(allowed)
                candidate = allowed{index};
                if ischar(candidate) || isstring(candidate)
                    candidate = ...
                        kssolv.analysis.matgenlab.io.vasp.Incar. ...
                        proc_val(key, candidate);
                end
                if isequaln(value, candidate), tf = true; return; end
                if (ischar(value) || isstring(value)) && ...
                        (ischar(candidate) || isstring(candidate)) && ...
                        strcmpi(string(value), string(candidate))
                    tf = true;
                    return
                end
            end
        end
    end

    methods (Static, Access = private)
        function output = parseList(text)
            expression = "(-?\d+\.?\d*(?:[eE][-+]?\d+)?|[\.A-Z]+)" + ...
                "\*?(-?\d+\.?\d*(?:[eE][-+]?\d+)?|[\.A-Z]+)?" + ...
                "\*?(-?\d+\.?\d*(?:[eE][-+]?\d+)?|[\.A-Z]+)?";
            tokens = regexp(text, expression, "tokens");
            parsed = cell(1, 0);
            for index = 1:numel(tokens)
                token = tokens{index};
                first = token{1};
                if numel(token) >= 3 && ~isempty(token{3})
                    item = ...
                        kssolv.analysis.matgenlab.io.vasp.Incar.smartScalar(token{3});
                    parsed = [parsed, repmat({item}, 1, ...
                        str2double(first) * str2double(token{2}))]; %#ok<AGROW>
                elseif numel(token) >= 2 && ~isempty(token{2})
                    item = ...
                        kssolv.analysis.matgenlab.io.vasp.Incar.smartScalar(token{2});
                    parsed = [parsed, repmat({item}, 1, ...
                        str2double(first))]; %#ok<AGROW>
                else
                    parsed{end + 1} = ...
                        kssolv.analysis.matgenlab.io.vasp.Incar. ...
                        smartScalar(first); %#ok<AGROW>
                end
            end
            if isempty(parsed), output = []; return; end
            if all(cellfun(@islogical, parsed))
                output = logical(cell2mat(parsed));
            elseif all(cellfun(@isinteger, parsed))
                output = int64(cell2mat(parsed));
            else
                output = cellfun(@double, parsed);
            end
        end

        function value = smartScalar(input)
            text = lower(string(input));
            if startsWith(text, [".t", "t"]), value = true;
            elseif startsWith(text, [".f", "f"]), value = false;
            elseif contains(text, [".", "e"]), value = str2double(text);
            else, value = int64(str2double(text));
            end
        end

        function database = parameterDatabase()
            persistent cached
            if isempty(cached)
                filename = fullfile(fileparts(mfilename("fullpath")), ...
                    "incar_parameters.json");
                cached = jsondecode(fileread(filename));
            end
            database = cached;
        end

        function value = missingSentinel()
            value = struct("matgenlab_missing_", true);
        end
    end
end
