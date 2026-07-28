classdef FloatWithUnit < kssolv.analysis.matgenlab.util.MSONable
    %FLOATWITHUNIT Scalar numeric value carrying a physical Unit.

    properties (SetAccess = private)
        val (1,1) double
        unit (1,1) kssolv.analysis.matgenlab.core.Unit
        unit_type (1,1) string
    end

    properties (Dependent, SetAccess = private)
        as_base_units
        supported_units
    end

    methods
        function obj = FloatWithUnit(val, unit, unit_type)
            arguments
                val (1,1) {mustBeNumeric, mustBeFinite}
                unit
                unit_type = ""
            end
            unit = kssolv.analysis.matgenlab.core.Unit(unit);
            unit_type = string(unit_type);
            if ~isscalar(unit_type)
                error("KSSOLV:Matgenlab:FloatWithUnit:InvalidUnitType", ...
                    "unit_type must be scalar text.");
            end
            if unit_type ~= ""
                supported = ...
                    kssolv.analysis.matgenlab.core.Unit.supported_for_type( ...
                    unit_type);
                if ~ismember(string(unit), supported)
                    throw(kssolv.analysis.matgenlab.core.UnitError( ...
                        "%s is not a supported unit for %s", ...
                        char(unit), unit_type));
                end
            end
            obj.val = double(val);
            obj.unit = unit;
            obj.unit_type = unit_type;
        end

        function value = double(obj)
            value = obj.val;
        end

        function value = single(obj)
            value = single(obj.val);
        end

        function tf = eq(obj, other)
            if isa(other, "kssolv.analysis.matgenlab.core.FloatWithUnit")
                tf = obj.val == other.val;
            elseif isnumeric(other)
                tf = obj.val == other;
            else
                tf = false;
            end
        end

        function tf = ne(obj, other)
            tf = ~eq(obj, other);
        end

        function tf = lt(obj, other)
            tf = obj.val < kssolv.analysis.matgenlab.core.FloatWithUnit.raw(other);
        end

        function tf = le(obj, other)
            tf = obj.val <= kssolv.analysis.matgenlab.core.FloatWithUnit.raw(other);
        end

        function tf = gt(obj, other)
            tf = obj.val > kssolv.analysis.matgenlab.core.FloatWithUnit.raw(other);
        end

        function tf = ge(obj, other)
            tf = obj.val >= kssolv.analysis.matgenlab.core.FloatWithUnit.raw(other);
        end

        function result = plus(left, right)
            if isa(left, "kssolv.analysis.matgenlab.core.FloatWithUnit")
                result = left.addImpl(right, 1);
            else
                result = right.addImpl(left, 1);
            end
        end

        function result = minus(left, right)
            if isa(left, "kssolv.analysis.matgenlab.core.FloatWithUnit")
                result = left.addImpl(right, -1);
            else
                result = left - right.val;
            end
        end

        function result = times(left, right)
            result = kssolv.analysis.matgenlab.core.FloatWithUnit. ...
                multiplyImpl(left, right);
        end

        function result = mtimes(left, right)
            result = times(left, right);
        end

        function result = rdivide(left, right)
            FWU = "kssolv.analysis.matgenlab.core.FloatWithUnit";
            if isa(left, FWU) && isa(right, FWU)
                result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                    left.val / right.val, left.unit / right.unit);
            elseif isa(left, FWU)
                result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                    left.val / right, left.unit, left.unit_type);
            else
                result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                    left / right.val, right.unit ^ -1);
            end
        end

        function result = mrdivide(left, right)
            result = rdivide(left, right);
        end

        function result = power(obj, exponent)
            result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                obj.val .^ exponent, obj.unit ^ exponent);
        end

        function result = mpower(obj, exponent)
            result = power(obj, exponent);
        end

        function result = uminus(obj)
            result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                -obj.val, obj.unit, obj.unit_type);
        end

        function result = uplus(obj)
            result = obj;
        end

        function converted = to(obj, new_unit)
            newUnit = kssolv.analysis.matgenlab.core.Unit(new_unit);
            factor = obj.unit.get_conversion_factor(newUnit);
            converted = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                obj.val * factor, newUnit, obj.unit_type);
        end

        function result = get.as_base_units(obj)
            base = obj.unit.as_base_units;
            result = obj.to(kssolv.analysis.matgenlab.core.Unit(base.units));
        end

        function names = get.supported_units(obj)
            if obj.unit_type == ""
                error("KSSOLV:Matgenlab:FloatWithUnit:UnknownUnitType", ...
                    "Cannot get supported unit for unknown unit type.");
            end
            names = ...
                kssolv.analysis.matgenlab.core.Unit.supported_for_type( ...
                obj.unit_type);
        end

        function text = char(obj)
            text = sprintf("%.15g %s", obj.val, char(obj.unit));
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function disp(obj)
            fprintf("%s\n", char(obj));
        end

        function data = asDict(obj)
            data = struct( ...
                "x_module", "pymatgen.core.units", ...
                "x_class", "FloatWithUnit", ...
                "val", obj.val, ...
                "unit", string(obj.unit), ...
                "unit_type", obj.unit_type);
        end

        function data = as_dict(obj)
            data = obj.asDict();
        end
    end

    methods (Access = private)
        function result = addImpl(obj, other, sign)
            if ~isa(other, "kssolv.analysis.matgenlab.core.FloatWithUnit")
                result = obj.val + sign * other;
                return
            end
            if obj.unit_type ~= other.unit_type
                if sign == 1
                    message = "Adding different types of units is not allowed";
                else
                    message = "Subtracting different units is not allowed";
                end
                throw(kssolv.analysis.matgenlab.core.UnitError(message));
            end
            if obj.unit ~= other.unit
                other = other.to(obj.unit);
            end
            result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                obj.val + sign * other.val, obj.unit, obj.unit_type);
        end
    end

    methods (Static)
        function obj = from_str(text)
            arguments
                text (1,1) string
            end
            text = strtrim(text);
            match = regexp(char(text), ...
                '^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*(.+)$', ...
                'tokens', 'once');
            if isempty(match)
                error("KSSOLV:Matgenlab:FloatWithUnit:MissingUnit", ...
                    "Unit is missing in string %s", text);
            end
            value = str2double(match{1});
            unit = string(strtrim(match{2}));
            try
                unitType = ...
                    kssolv.analysis.matgenlab.core.Unit.type_for_name(unit);
            catch exception
                if exception.identifier == "KSSOLV:Matgenlab:UnitError"
                    unitType = "";
                else
                    rethrow(exception)
                end
            end
            obj = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                value, unit, unitType);
        end

        function obj = from_dict(data)
            if isfield(data, "unit_type")
                unitType = data.unit_type;
            else
                unitType = "";
            end
            obj = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                data.val, data.unit, unitType);
        end
    end

    methods (Static, Access = private)
        function value = raw(input)
            if isa(input, "kssolv.analysis.matgenlab.core.FloatWithUnit")
                value = input.val;
            else
                value = input;
            end
        end

        function result = multiplyImpl(left, right)
            FWU = "kssolv.analysis.matgenlab.core.FloatWithUnit";
            if isa(left, FWU) && isa(right, FWU)
                result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                    left.val .* right.val, left.unit * right.unit);
            elseif isa(left, FWU)
                result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                    left.val .* right, left.unit, left.unit_type);
            else
                result = kssolv.analysis.matgenlab.core.FloatWithUnit( ...
                    left .* right.val, right.unit, right.unit_type);
            end
        end
    end
end
