classdef InputVariable
    %#ok<*AGROW>
    %INPUTVARIABLE Formatting model for one ABINIT input variable.
    properties
        value
        valperline = 3
    end
    properties (Access = private)
        name_ = ""
        units_ = ""
    end
    properties (Dependent)
        name
        basename
        dataset
        units
    end
    methods
        function obj = InputVariable(name, value, units, valperline)
            if nargin == 0, return; end
            if nargin < 3, units = ""; end
            if nargin < 4, valperline = 3; end
            obj.name_ = string(name); obj.value = value;
            obj.units_ = string(units); obj.valperline = valperline;
            if obj.name_ == "bdgw", obj.valperline = 2; end
            if iscell(value) && ~isempty(value) && ...
                    any(string(value{end}) == ["bohr","angstrom","hartree","Ha","eV"])
                obj.units_ = string(value{end}); obj.value = value(1:end - 1);
            end
        end
        function value = get.name(obj), value = obj.name_; end
        function value = get.basename(obj)
            value = regexprep(obj.name_, "[0-9:+?]+$", "");
        end
        function value = get.dataset(obj)
            value = extractAfter(obj.name_, strlength(obj.basename));
        end
        function value = get.units(obj), value = obj.units_; end
        function value = get_value(obj)
            if strlength(obj.units) > 0 %#ok<ALIGN>
                if iscell(obj.value), value = [obj.value, {char(obj.units)}];
                else, value = {obj.value, char(obj.units)}; end
            else, value = obj.value; end
        end
        function text = char(obj)
            if isempty(obj.value), text = ""; return; end
            decimals = 0;
            if any(contains(obj.name, ["xred","xcart","rprim","qpt","kpt"]))
                decimals = 16;
            end
            if any(contains(obj.name, ["ngkpt","kptrlatt","ngqpt","ng2qpt"]))
                decimals = 0;
            end
            value = obj.value;
            if isnumeric(value) && ~isscalar(value)
                if ~isvector(value), body = obj.format_list2d(value, decimals);
                else, body = obj.format_list(value, decimals); end
            elseif iscell(value)
                nested = any(cellfun(@iscell, value));
                if nested, body = obj.format_list2d(value, decimals);
                else, body = obj.format_list(value, decimals); end
            else
                body = " " + string(value);
            end
            text = char(" " + obj.name + body + ...
                conditional(strlength(obj.units) > 0, " " + obj.units, ""));
        end
        function text = string(obj), text = string(char(obj)); end
        function text = format_list(obj, values, decimals)
            if nargin < 3, decimals = 0; end
            values = kssolv.analysis.matgenlab.io.abinit.flatten(values);
            pieces = strings(1, numel(values));
            for index = 1:numel(values)
                pieces(index) = obj.format_scalar(values(index), decimals);
            end
            rows = {};
            for first = 1:obj.valperline:numel(pieces)
                rows{end + 1} = " " + join(pieces(first:min(end, first + obj.valperline - 1)), " ");
            end
            if numel(rows) > 1, text = newline + join([rows{:}], newline);
            else, text = rows{1}; end
        end
    end
    methods (Static)
        function text = format_scalar(value, decimals)
            if nargin < 2, decimals = 0; end
            if iscell(value), value = value{1}; end
            if ~(isnumeric(value) || islogical(value))
                text = string(value); return
            end
            value = double(value);
            if decimals == 0 && value == fix(value), text = string(fix(value)); return; end
            if value == 0 || (abs(value) > 1e-3 && abs(value) < 1e4)
                text = string(sprintf("%.*f", min(max(decimals, 1), 10), value));
            else
                text = replace(string(sprintf("%.*e", min(max(decimals, 1), 10), value)), "e", "d");
            end
        end
        function text = format_list2d(values, decimals)
            if nargin < 2, decimals = 0; end
            if iscell(values), rows = values; else, rows = num2cell(values, 2); end
            output = strings(1, numel(rows));
            for row = 1:numel(rows)
                item = rows{row};
                if iscell(item)
                    tokens = cellfun(@(v) ...
                        kssolv.analysis.matgenlab.io.abinit.InputVariable.format_scalar(v, decimals), ...
                        item, "UniformOutput", false);
                else
                    tokens = arrayfun(@(v) ...
                        kssolv.analysis.matgenlab.io.abinit.InputVariable.format_scalar(v, decimals), ...
                        item, "UniformOutput", false);
                end
                output(row) = " " + join(string(tokens), " ");
            end
            text = newline + join(output, newline);
        end
    end
end

function value = conditional(condition, yes, no)
if condition, value = yes; else, value = no; end
end
