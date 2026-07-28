classdef InitMagMomTag < kssolv.analysis.matgenlab.io.jdftx.AbstractTag
    %INITMAGMOMTAG Initial magnetic moments encoded as one token sequence.
    methods
        function obj = InitMagMomTag(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.AbstractTag(varargin{:});
        end

        function [tag, valid, fixed] = validate_value_type(~, tag, value, varargin)
            tag = string(tag);
            valid = ischar(value) || isstring(value);
            fixed = string(value);
        end

        function value = read(~, ~, input)
            value = strtrim(string(input));
        end

        function text = write(obj, tag, value)
            text = write@kssolv.analysis.matgenlab.io.jdftx.AbstractTag( ...
                obj, tag, strtrim(string(value)));
        end
    end
end
