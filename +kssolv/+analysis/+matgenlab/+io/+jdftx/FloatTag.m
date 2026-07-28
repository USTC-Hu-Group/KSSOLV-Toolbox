classdef FloatTag < kssolv.analysis.matgenlab.io.jdftx.AbstractNumericTag
    %FLOATTAG Floating-point JDFTx tag.
    methods
        function obj = FloatTag(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.AbstractNumericTag(varargin{:});
        end

        function [tag, valid, fixed] = validate_value_type(~, tag, value, options)
            arguments
                ~
                tag
                value
                options.try_auto_type_fix (1, 1) logical = false
            end
            tag = string(tag);
            valid = isnumeric(value) && isscalar(value) && isfinite(value);
            fixed = double(value);
            if ~valid && options.try_auto_type_fix
                fixed = str2double(string(value));
                valid = isfinite(fixed);
            end
        end

        function value = read(~, tag, input)
            value = str2double(strtrim(string(input)));
            if ~isfinite(value)
                error("KSSOLV:Matgenlab:JDFTX:InvalidFloat", ...
                    "Value '%s' for '%s' is not numeric.", input, tag);
            end
        end

        function text = write(obj, tag, value)
            [~, valid] = obj.validate_value_type(tag, value);
            if ~valid
                error("KSSOLV:Matgenlab:JDFTX:InvalidFloat", ...
                    "Value for '%s' is not numeric.", tag);
            end
            text = write@kssolv.analysis.matgenlab.io.jdftx.AbstractTag( ...
                obj, tag, sprintf("%.16g", value));
        end
    end
end
