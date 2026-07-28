classdef BoolTagContainer < kssolv.analysis.matgenlab.io.jdftx.TagContainer
    %BOOLTAGCONTAINER Container whose present subtag names imply true.
    methods
        function obj = BoolTagContainer(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.TagContainer(varargin{:});
        end

        function value = read(obj, ~, value_string)
            tokens = regexp(strtrim(string(value_string)), "\s+", "split");
            value = struct();
            for idx = 1:numel(obj.subtag_names)
                name = obj.subtag_names(idx);
                if any(tokens == name)
                    value.(matlab.lang.makeValidName(name)) = true;
                end
            end
        end
    end
end
