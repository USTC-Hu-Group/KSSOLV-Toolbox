classdef StringifyFixture < kssolv.analysis.matgenlab.util.Stringify
    properties
        Value (1,1) string
    end
    methods
        function obj = StringifyFixture(value, mode)
            obj.Value = string(value);
            if nargin > 1, obj.STRING_MODE = string(mode); end
        end
        function text = to_pretty_string(obj), text = obj.Value; end
        function text = string(obj), text = obj.Value; end
    end
end
