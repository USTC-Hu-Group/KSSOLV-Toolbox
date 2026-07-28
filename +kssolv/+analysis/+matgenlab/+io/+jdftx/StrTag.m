classdef StrTag < kssolv.analysis.matgenlab.io.jdftx.AbstractTag
    %STRTAG String-valued JDFTx tag with optional allowed values.
    properties
        options = []
    end
    methods
        function obj = StrTag(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.AbstractTag();
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
        end

        function [tag, valid, fixed] = validate_value_type(obj, tag, value, options)
            arguments
                obj
                tag
                value
                options.try_auto_type_fix (1, 1) logical = false
            end
            tag = string(tag);
            valid = ischar(value) || (isstring(value) && isscalar(value));
            fixed = value;
            if ~valid && options.try_auto_type_fix
                fixed = string(value);
                valid = isscalar(fixed);
            end
            if valid && ~isempty(obj.options)
                valid = any(string(fixed) == string(obj.options));
            end
        end

        function value = read(obj, tag, input)
            value = strtrim(string(input));
            if contains(value, " ")
                error("KSSOLV:Matgenlab:JDFTX:InvalidString", ...
                    "Value for '%s' must be one token.", tag);
            end
            [~, valid] = obj.validate_value_type(tag, value);
            if ~valid
                error("KSSOLV:Matgenlab:JDFTX:InvalidStringOption", ...
                    "Value '%s' is not valid for '%s'.", value, tag);
            end
        end

        function text = write(obj, tag, value)
            value = obj.read(tag, value);
            text = write@kssolv.analysis.matgenlab.io.jdftx.AbstractTag( ...
                obj, tag, value);
        end
    end
end
