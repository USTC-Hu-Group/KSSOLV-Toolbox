classdef BoolTag < kssolv.analysis.matgenlab.io.jdftx.AbstractTag
    %BOOLTAG JDFTx yes/no tag.
    methods
        function obj = BoolTag(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.AbstractTag(varargin{:});
        end

        function [tag, valid, fixed] = validate_value_type(~, tag, value, options)
            arguments
                ~
                tag
                value
                options.try_auto_type_fix (1, 1) logical = false
            end
            tag = string(tag);
            valid = islogical(value) && isscalar(value);
            fixed = value;
            if ~valid && options.try_auto_type_fix
                try
                    fixed = kssolv.analysis.matgenlab.io.jdftx.BoolTag(). ...
                        read(tag, string(value));
                    valid = true;
                catch
                end
            end
        end

        function raise_value_error(~, tag, value)
            error("KSSOLV:Matgenlab:JDFTX:InvalidBoolean", ...
                "Value '%s' for tag '%s' is not boolean.", value, tag);
        end

        function value = read(obj, tag, input)
            input = lower(strtrim(string(input)));
            if ~obj.write_value && strlength(input) == 0
                input = "yes";
            end
            if input == "yes"
                value = true;
            elseif input == "no"
                value = false;
            else
                obj.raise_value_error(tag, input);
            end
        end

        function text = write(obj, tag, value)
            [~, valid] = obj.validate_value_type(tag, value);
            if ~valid
                obj.raise_value_error(tag, string(value));
            end
            if value
                encoded = "yes";
            else
                encoded = "no";
            end
            text = write@kssolv.analysis.matgenlab.io.jdftx.AbstractTag( ...
                obj, tag, encoded);
        end
    end
end
