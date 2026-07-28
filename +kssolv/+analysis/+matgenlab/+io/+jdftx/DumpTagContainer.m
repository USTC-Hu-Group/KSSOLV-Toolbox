classdef DumpTagContainer < kssolv.analysis.matgenlab.io.jdftx.TagContainer
    %DUMPTAGCONTAINER Parser for "dump frequency variable..." directives.
    methods
        function obj = DumpTagContainer(varargin)
            obj@kssolv.analysis.matgenlab.io.jdftx.TagContainer(varargin{:});
            obj.can_repeat = true;
        end

        function value = read(~, ~, value_string)
            tokens = regexp(strtrim(string(value_string)), "\s+", "split");
            value = struct();
            if isempty(tokens) || strlength(tokens(1)) == 0
                return
            end
            frequency = matlab.lang.makeValidName(tokens(1));
            flags = struct();
            for idx = 2:numel(tokens)
                flags.(matlab.lang.makeValidName(tokens(idx))) = true;
            end
            value.(frequency) = flags;
        end
    end
end
