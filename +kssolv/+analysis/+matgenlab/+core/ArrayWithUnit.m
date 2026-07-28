classdef ArrayWithUnit < kssolv.analysis.matgenlab.util.MSONable
    %ARRAYWITHUNIT Numeric array carrying a physical Unit.

    properties (SetAccess = private)
        data double
        unit
        unit_type (1,1) string
    end

    properties (Dependent, SetAccess = private)
        as_base_units
        supported_units
    end

    methods
        function obj = ArrayWithUnit(input_array, unit, unit_type)
            arguments
                input_array {mustBeNumeric}
                unit = []
                unit_type = ""
            end
            obj.data = double(input_array);
            if isempty(unit)
                obj.unit = [];
            else
                obj.unit = kssolv.analysis.matgenlab.core.Unit(unit);
            end
            obj.unit_type = string(unit_type);
            if obj.unit_type ~= "" && ~isempty(obj.unit)
                supported = ...
                    kssolv.analysis.matgenlab.core.Unit.supported_for_type( ...
                    obj.unit_type);
                if ~ismember(string(obj.unit), supported)
                    throw(kssolv.analysis.matgenlab.core.UnitError( ...
                        "%s is not a supported unit for %s", ...
                        char(obj.unit), obj.unit_type));
                end
            end
        end

        function value = double(obj)
            value = obj.data;
        end

        function varargout = size(obj, varargin)
            [varargout{1:nargout}] = size(obj.data, varargin{:});
        end

        function n = length(obj)
            n = length(obj.data);
        end

        function ind = end(obj, k, n)
            sizes = size(obj.data);
            if k < n
                ind = sizes(k);
            else
                ind = prod(sizes(k:end));
            end
        end

        function result = plus(left, right)
            [leftData, rightData, commonUnit, unitType] = ...
                kssolv.analysis.matgenlab.core.ArrayWithUnit. ...
                additiveOperands(left, right, "Adding");
            result = kssolv.analysis.matgenlab.core.ArrayWithUnit( ...
                leftData + rightData, commonUnit, unitType);
        end

        function result = minus(left, right)
            [leftData, rightData, commonUnit, unitType] = ...
                kssolv.analysis.matgenlab.core.ArrayWithUnit. ...
                additiveOperands(left, right, "Subtracting");
            result = kssolv.analysis.matgenlab.core.ArrayWithUnit( ...
                leftData - rightData, commonUnit, unitType);
        end

        function result = times(left, right)
            result = kssolv.analysis.matgenlab.core.ArrayWithUnit. ...
                multiplicativeOperands(left, right, false);
        end

        function result = mtimes(left, right)
            result = times(left, right);
        end

        function result = rdivide(left, right)
            result = kssolv.analysis.matgenlab.core.ArrayWithUnit. ...
                multiplicativeOperands(left, right, true);
        end

        function result = mrdivide(left, right)
            result = rdivide(left, right);
        end

        function result = uminus(obj)
            result = kssolv.analysis.matgenlab.core.ArrayWithUnit( ...
                -obj.data, obj.unit, obj.unit_type);
        end

        function tf = eq(left, right)
            tf = double(left) == double(right);
        end

        function tf = ne(left, right)
            tf = ~(left == right);
        end

        function converted = to(obj, new_unit)
            newUnit = kssolv.analysis.matgenlab.core.Unit(new_unit);
            factor = obj.unit.get_conversion_factor(newUnit);
            converted = kssolv.analysis.matgenlab.core.ArrayWithUnit( ...
                obj.data * factor, newUnit, obj.unit_type);
        end

        function result = get.as_base_units(obj)
            base = obj.unit.as_base_units;
            result = obj.to(kssolv.analysis.matgenlab.core.Unit(base.units));
        end

        function names = get.supported_units(obj)
            if obj.unit_type == ""
                error("KSSOLV:Matgenlab:ArrayWithUnit:UnknownUnitType", ...
                    "Cannot get supported unit for unknown unit_type.");
            end
            names = ...
                kssolv.analysis.matgenlab.core.Unit.supported_for_type( ...
                obj.unit_type);
        end

        function text = conversions(obj)
            names = obj.supported_units;
            lines = strings(size(names));
            for index = 1:numel(names)
                lines(index) = string(obj.to(names(index)));
            end
            text = strjoin(lines, newline);
        end

        function text = char(obj)
            numericText = strtrim(evalc("disp(obj.data)"));
            text = sprintf("%s %s", numericText, char(obj.unit));
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function disp(obj)
            fprintf("%s\n", char(obj));
        end

        function result = subsref(obj, subscript)
            if subscript(1).type == "()"
                result = obj.data(subscript(1).subs{:});
                if numel(subscript) > 1
                    result = builtin("subsref", result, subscript(2:end));
                end
            else
                result = builtin("subsref", obj, subscript);
            end
        end

        function obj = subsasgn(obj, subscript, value)
            if subscript(1).type == "()"
                if isa(value, "kssolv.analysis.matgenlab.core.ArrayWithUnit")
                    value = value.to(obj.unit).data;
                end
                obj.data = builtin("subsasgn", obj.data, subscript, value);
            else
                obj = builtin("subsasgn", obj, subscript, value);
            end
        end

        function data = asDict(obj)
            data = struct( ...
                "x_module", "pymatgen.core.units", ...
                "x_class", "ArrayWithUnit", ...
                "input_array", obj.data, ...
                "unit", string(obj.unit), ...
                "unit_type", obj.unit_type);
        end

        function data = as_dict(obj)
            data = obj.asDict();
        end
    end

    methods (Static)
        function obj = from_dict(data)
            if isfield(data, "unit_type")
                unitType = data.unit_type;
            else
                unitType = "";
            end
            obj = kssolv.analysis.matgenlab.core.ArrayWithUnit( ...
                data.input_array, data.unit, unitType);
        end
    end

    methods (Static, Access = private)
        function [leftData, rightData, unit, unitType] = ...
                additiveOperands(left, right, operation)
            AWU = "kssolv.analysis.matgenlab.core.ArrayWithUnit";
            if isa(left, AWU)
                leftData = left.data;
                unit = left.unit;
                unitType = left.unit_type;
                if isa(right, AWU)
                    if right.unit_type ~= unitType
                        throw(kssolv.analysis.matgenlab.core.UnitError( ...
                            "%s different types of units is not allowed", ...
                            operation));
                    end
                    if right.unit ~= unit
                        right = right.to(unit);
                    end
                    rightData = right.data;
                else
                    rightData = right;
                end
            else
                leftData = left;
                rightData = right.data;
                unit = right.unit;
                unitType = right.unit_type;
            end
        end

        function result = multiplicativeOperands(left, right, divide)
            AWU = "kssolv.analysis.matgenlab.core.ArrayWithUnit";
            leftHasUnit = isa(left, AWU);
            rightHasUnit = isa(right, AWU);
            if leftHasUnit
                leftData = left.data;
            else
                leftData = left;
            end
            if rightHasUnit
                rightData = right.data;
            else
                rightData = right;
            end
            if divide
                data = leftData ./ rightData;
            else
                data = leftData .* rightData;
            end
            if leftHasUnit && rightHasUnit
                if divide
                    unit = left.unit / right.unit;
                else
                    unit = left.unit * right.unit;
                end
                unitType = "";
            elseif leftHasUnit
                unit = left.unit;
                unitType = left.unit_type;
            elseif rightHasUnit
                if divide
                    unit = right.unit ^ -1;
                    unitType = "";
                else
                    unit = right.unit;
                    unitType = right.unit_type;
                end
            else
                result = data;
                return
            end
            result = kssolv.analysis.matgenlab.core.ArrayWithUnit( ...
                data, unit, unitType);
        end
    end
end
