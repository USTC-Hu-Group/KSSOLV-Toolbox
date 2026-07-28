classdef Control < handle
    %CONTROL Read, update, and write ShengBTE CONTROL namelists.
    properties (Constant)
        required_params = ["nelements", "natoms", "ngrid", "lattvec", ...
            "types", "elements", "positions", "scell"]
        data_keys = ["nelements", "natoms", "ngrid", "lattvec", ...
            "types", "elements", "positions", "scell"]
        allocations_keys = ["nelements", "natoms", "ngrid", ...
            "norientations"]
        crystal_keys = ["lfactor", "lattvec", "types", "elements", ...
            "positions", "masses", "gfactors", "epsilon", "born", ...
            "scell", "orientations"]
        params_keys = ["t", "t_min", "t_max", "t_step", "omega_max", ...
            "scalebroad", "rmin", "rmax", "dr", "maxiter", ...
            "nticks", "eps"]
        flags_keys = ["nonanalytic", "convergence", "isotopes", ...
            "autoisotopes", "nanowires", "onlyharmonic", "espresso"]
    end

    properties (Access = private)
        values
    end

    methods
        function obj = Control(ngrid, temperature, varargin)
            obj.values = containers.Map("KeyType", "char", ...
                "ValueType", "any");
            if nargin == 0, ngrid = []; temperature = 300; end
            if nargin < 1 || isempty(ngrid), ngrid = [25, 25, 25]; end
            if nargin < 2 || isempty(temperature), temperature = 300; end
            obj.values("ngrid") = reshape(double(ngrid), 1, []);
            if isnumeric(temperature) && isscalar(temperature)
                obj.values("t") = double(temperature);
            elseif isstruct(temperature) && ...
                    all(isfield(temperature, ["min", "max", "step"]))
                obj.values("t_min") = double(temperature.min);
                obj.values("t_max") = double(temperature.max);
                obj.values("t_step") = double(temperature.step);
            else
                error("KSSOLV:Matgenlab:ShengBTE:Temperature", ...
                    "Unsupported temperature type, must be float or struct");
            end
            obj.update(varargin{:});
        end

        function update(obj, varargin)
            if isempty(varargin), return; end
            if isscalar(varargin) && isa(varargin{1}, "containers.Map")
                source = varargin{1};
                names = reshape(string(source.keys), 1, []);
                for name = names
                    obj.values(char(name)) = source(char(name));
                end
                return
            elseif isscalar(varargin) && isstruct(varargin{1})
                source = varargin{1};
                names = reshape(string(fieldnames(source)), 1, []);
                for name = names
                    if ~any(name == ["x_module", "x_class", "x_version"])
                        obj.values(char(name)) = source.(char(name));
                    end
                end
                return
            end
            if mod(numel(varargin), 2) ~= 0
                error("KSSOLV:Matgenlab:ShengBTE:Arguments", ...
                    "Keyword arguments must occur in name-value pairs.");
            end
            for index = 1:2:numel(varargin)
                obj.values(char(string(varargin{index}))) = ...
                    varargin{index + 1};
            end
        end

        function value = get(obj, key)
            key = char(string(key));
            if ~isKey(obj.values, key)
                error("KSSOLV:Matgenlab:ShengBTE:MissingKey", ...
                    "Control has no parameter '%s'.", key);
            end
            value = obj.values(key);
        end

        function set(obj, key, value)
            obj.values(char(string(key))) = value;
        end

        function value = isKey(obj, key)
            value = isKey(obj.values, char(string(key)));
        end

        function value = keys(obj)
            value = string(obj.values.keys);
        end

        function value = length(obj), value = double(obj.values.Count); end
        function value = count(obj), value = double(obj.values.Count); end

        function value = as_dict(obj)
            value = struct();
            names = obj.values.keys;
            for index = 1:numel(names)
                value.(names{index}) = obj.values(names{index});
            end
        end

        function value = asDict(obj), value = obj.as_dict(); end

        function to_file(obj, filename)
            if nargin < 2 || isempty(filename), filename = "CONTROL"; end
            for parameter = obj.required_params
                if ~obj.isKey(parameter)
                    warning("KSSOLV:Matgenlab:ShengBTE:RequiredParameter", ...
                        "Required parameter '%s' not specified!", parameter);
                end
            end
            text = namelistSection("allocations", obj, ...
                obj.allocations_keys) + newline + ...
                namelistSection("crystal", obj, obj.crystal_keys) + ...
                newline + namelistSection("parameters", obj, ...
                obj.params_keys) + newline + ...
                namelistSection("flags", obj, obj.flags_keys) + newline;
            fileId = fopen(filename, "w", "n", "UTF-8");
            if fileId < 0
                error("KSSOLV:Matgenlab:ShengBTE:Open", ...
                    "Unable to open '%s' for writing.", string(filename));
            end
            cleanup = onCleanup(@() fclose(fileId));
            fwrite(fileId, char(text), "char");
            clear cleanup
        end

        function structure = get_structure(obj)
            required = ["lattvec", "types", "elements", "positions"];
            if ~all(arrayfun(@(name) obj.isKey(name), required))
                error("KSSOLV:Matgenlab:ShengBTE:StructureParameters", ...
                    ['All of [''lattvec'', ''types'', ''elements'', ' ...
                    '''positions''] must be in control object']);
            end
            elements = reshape(string(obj.get("elements")), 1, []);
            types = reshape(double(obj.get("types")), 1, []);
            species = elements(types);
            lattice = double(obj.get("lattvec"));
            if obj.isKey("lfactor")
                lattice = lattice * double(obj.get("lfactor")) * 10;
            end
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, cellstr(species), double(obj.get("positions")));
        end

        function tf = eq(obj, other)
            tf = isa(other, class(obj)) && ...
                kssolv.analysis.matgenlab.util.is_np_dict_equal( ...
                obj.as_dict(), other.as_dict());
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs) && ...
                    (ischar(reference(1).subs{1}) || ...
                    isstring(reference(1).subs{1}))
                value = obj.get(reference(1).subs{1});
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
                return
            end
            [varargout{1:nargout}] = builtin("subsref", obj, reference);
        end

        function obj = subsasgn(obj, reference, value)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs) && ...
                    (ischar(reference(1).subs{1}) || ...
                    isstring(reference(1).subs{1}))
                key = reference(1).subs{1};
                if numel(reference) > 1
                    current = obj.get(key);
                    current = builtin("subsasgn", current, ...
                        reference(2:end), value);
                    obj.set(key, current);
                else
                    obj.set(key, value);
                end
                return
            end
            obj = builtin("subsasgn", obj, reference, value);
        end
    end

    methods (Static)
        function obj = from_file(filepath)
            text = string(fileread(filepath));
            obj = kssolv.analysis.matgenlab.io.shengbte.Control. ...
                from_dict(parseNamelist(text));
        end

        function obj = from_dict(controlDict)
            if isa(controlDict, "containers.Map")
                source = controlDict;
                has = @(name) isKey(source, name);
                take = @(name) source(name);
            else
                source = controlDict;
                has = @(name) isfield(source, name);
                take = @(name) source.(name);
            end
            ngrid = [];
            if has("ngrid"), ngrid = take("ngrid"); end
            if has("t")
                temperature = take("t");
            elseif all([has("t_min"), has("t_max"), has("t_step")])
                temperature = struct("min", take("t_min"), ...
                    "max", take("t_max"), "step", take("t_step"));
            else
                temperature = 300;
            end
            obj = kssolv.analysis.matgenlab.io.shengbte.Control( ...
                ngrid, temperature, source);
        end

        function obj = from_structure(structure, reciprocalDensity, varargin)
            if nargin < 2, reciprocalDensity = 50000; end
            elements = structure.elements;
            if iscell(elements)
                elementNames = cellfun(@(item) string(item), elements);
            else
                elementNames = string(elements);
            end
            atomicNumbers = reshape(double(structure.atomic_numbers), 1, []);
            uniqueNumbers = unique(atomicNumbers);
            types = zeros(size(atomicNumbers));
            for index = 1:numel(uniqueNumbers)
                types(atomicNumbers == uniqueNumbers(index)) = index;
            end
            parameters = struct( ...
                "nelements", structure.n_elems, ...
                "natoms", structure.num_sites, ...
                "norientations", 0, "lfactor", .1, ...
                "lattvec", structure.lattice.matrix, ...
                "elements", elementNames, "types", types, ...
                "positions", structure.frac_coords);
            if ~isempty(reciprocalDensity) && reciprocalDensity ~= 0
                points = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    automatic_density(structure, reciprocalDensity);
                parameters.ngrid = points.kpts(1, :);
            end
            obj = kssolv.analysis.matgenlab.io.shengbte.Control( ...
                fieldOr(parameters, "ngrid", []), 300);
            obj.update(parameters);
            obj.update(varargin{:});
        end
    end
end

function text = namelistSection(name, control, fields)
lines = "&" + string(name);
present = fields(arrayfun(@(field) control.isKey(field), fields));
present = sort(present);
for field = present
    value = control.get(field);
    formatted = formatAssignment(field, value);
    lines = [lines; formatted(:)]; %#ok<AGROW>
end
lines(end + 1) = "/";
text = strjoin(lines, newline);
end

function lines = formatAssignment(name, value)
name = string(name);
if isnumeric(value) && ismatrix(value) && ...
        size(value, 1) > 1 && size(value, 2) > 1 && ...
        any(name == ["lattvec", "positions", "orientations"])
    lines = strings(size(value, 1), 1);
    for row = 1:size(value, 1)
        lines(row) = "    " + name + "(:," + row + ") = " + ...
            strjoin(arrayfun(@formatFloat, value(row, :)), ", ");
    end
elseif isnumeric(value) && ndims(value) == 3
    lines = strings(size(value, 1), 1);
    for index = 1:size(value, 1)
        slice = squeeze(value(index, :, :));
        numbers = reshape(slice.', 1, []);
        lines(index) = "    " + name + "(:,:," + index + ") = " + ...
            strjoin(arrayfun(@formatFloat, numbers), ", ");
    end
else
    lines = "    " + name + " = " + formatValue(name, value);
end
end

function text = formatValue(name, value)
if islogical(value)
    values = repmat(".false.", size(value));
    values(value) = ".true.";
    text = strjoin(values, ", ");
elseif ischar(value) || isstring(value) || iscellstr(value)
    values = reshape(string(value), 1, []);
    text = strjoin("'" + replace(values, "'", "''") + "'", ", ");
elseif isnumeric(value)
    integers = any(name == ["nelements", "natoms", "ngrid", ...
        "norientations", "types", "scell", "maxiter", "nticks", ...
        "t", "t_min", "t_max", "t_step"]);
    if integers
        values = arrayfun(@formatIntegerLike, ...
            reshape(value, 1, []));
    else
        values = arrayfun(@formatFloat, reshape(value, 1, []));
    end
    text = strjoin(values, ", ");
else
    error("KSSOLV:Matgenlab:ShengBTE:Value", ...
        "Unsupported namelist value for '%s'.", name);
end

function text = formatIntegerLike(number)
if number == fix(number)
    text = string(sprintf("%d", number));
else
    text = formatFloat(number);
end
end
end

function text = formatFloat(number)
if number == fix(number)
    text = string(sprintf("%.1f", number));
else
    text = string(sprintf("%.15g", number));
end
end

function value = parseNamelist(text)
lines = regexp(char(text), "\r\n|\n|\r", "split");
value = struct();
matrixRows = struct();
for index = 1:numel(lines)
    line = regexprep(lines{index}, "!.*$", "");
    token = regexp(line, ...
        "^\s*([A-Za-z_]\w*)\(:,(\d+)\)\s*=\s*(.*?)\s*$", ...
        "tokens", "once");
    if isempty(token)
        token = regexp(line, ...
            "^\s*([A-Za-z_]\w*)\s*=\s*(.*?)\s*$", ...
            "tokens", "once");
        if isempty(token), continue; end
        name = lower(token{1});
        row = "";
        rhs = token{2};
    else
        name = lower(token{1});
        row = token{2};
        rhs = token{3};
    end
    parsed = parseValue(rhs);
    if strlength(string(row)) == 0
        value.(name) = parsed;
    else
        if ~isfield(matrixRows, name), matrixRows.(name) = {}; end
        rows = matrixRows.(name);
        rows{str2double(row)} = reshape(double(parsed), 1, []);
        matrixRows.(name) = rows;
    end
end
names = fieldnames(matrixRows);
for index = 1:numel(names)
    value.(names{index}) = cell2mat(matrixRows.(names{index}).');
end
end

function value = parseValue(text)
tokens = regexp(text, ...
    "'(?:''|[^'])*'|""(?:""""|[^""])*""|[^,]+", "match");
values = cell(1, numel(tokens));
for index = 1:numel(tokens)
    token = strtrim(tokens{index});
    if startsWith(token, "'") || startsWith(token, '"')
        values{index} = string(token(2:end - 1));
    elseif any(strcmpi(token, {'.true.', 'true', 't'}))
        values{index} = true;
    elseif any(strcmpi(token, {'.false.', 'false', 'f'}))
        values{index} = false;
    else
        values{index} = str2double(replace(token, ...
            ["d", "D"], ["e", "E"]));
    end
end
if all(cellfun(@isnumeric, values))
    value = cell2mat(values);
elseif all(cellfun(@islogical, values))
    value = cell2mat(values);
else
    value = string(values);
    if isscalar(value), value = value(1); end
end
end

function value = fieldOr(input, field, fallback)
if isfield(input, field), value = input.(field);
else, value = fallback; end
end
