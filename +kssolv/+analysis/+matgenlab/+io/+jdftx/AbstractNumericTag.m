classdef AbstractNumericTag < kssolv.analysis.matgenlab.io.jdftx.AbstractTag
    %ABSTRACTNUMERICTAG Numeric JDFTx tag with bounds and tolerance.
    properties
        lb = []
        ub = []
        lb_incl (1, 1) logical = true
        ub_incl (1, 1) logical = true
        eq_atol (1, 1) double = 1e-8
        eq_rtol (1, 1) double = 1e-5
    end
    methods
        function obj = AbstractNumericTag(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.AbstractTag();
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
        end

        function value = val_is_within_bounds(obj, input)
            value = true;
            if ~isempty(obj.lb)
                value = value && ((obj.lb_incl && input >= obj.lb) || ...
                    (~obj.lb_incl && input > obj.lb));
            end
            if ~isempty(obj.ub)
                value = value && ((obj.ub_incl && input <= obj.ub) || ...
                    (~obj.ub_incl && input < obj.ub));
            end
        end

        function text = get_invalid_value_error_str(obj, tag, value)
            text = sprintf("Value '%g' for tag '%s' is outside bounds.", ...
                value, string(tag));
            if ~isempty(obj.lb) || ~isempty(obj.ub)
                text = text + " [" + string(obj.lb) + ", " + ...
                    string(obj.ub) + "]";
            end
        end

        function [valid, message] = validate_value_bounds(obj, tag, value)
            valid = obj.val_is_within_bounds(value);
            if valid
                message = "";
            else
                message = obj.get_invalid_value_error_str(tag, value);
            end
        end

        function value = is_equal_to(obj, val1, obj2, val2)
            value = isa(obj2, class(obj)) && ...
                abs(double(val1) - double(val2)) <= ...
                obj.eq_atol + obj.eq_rtol * abs(double(val2));
        end
    end
end
