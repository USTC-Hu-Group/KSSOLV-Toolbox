classdef IntTag < kssolv.analysis.matgenlab.io.jdftx.AbstractNumericTag
    %INTTAG Integer-valued JDFTx tag.
    methods
        function obj = IntTag(varargin)
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
            valid = isnumeric(value) && isscalar(value) && ...
                isfinite(value) && value == fix(value);
            fixed = value;
            if ~valid && options.try_auto_type_fix
                fixed = str2double(string(value));
                valid = isfinite(fixed) && fixed == fix(fixed);
            end
        end

        function value = read(~, tag, input)
            value = str2double(strtrim(string(input)));
            if ~isfinite(value) || value ~= fix(value)
                error("KSSOLV:Matgenlab:JDFTX:InvalidInteger", ...
                    "Value '%s' for '%s' is not an integer.", input, tag);
            end
        end

        function text = write(obj, tag, value)
            [~, valid] = obj.validate_value_type(tag, value);
            if ~valid
                error("KSSOLV:Matgenlab:JDFTX:InvalidInteger", ...
                    "Value for '%s' is not an integer.", tag);
            end
            text = write@kssolv.analysis.matgenlab.io.jdftx.AbstractTag( ...
                obj, tag, sprintf("%d", value));
        end
    end
end
