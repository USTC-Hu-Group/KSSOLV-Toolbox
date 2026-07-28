classdef JMinSettings
    %JMINSETTINGS Parsed minimization settings with deterministic display.
    properties
        params struct = struct()
    end
    methods
        function obj = JMinSettings(params)
            if nargin > 0 && ~isempty(params)
                obj.params = params;
            end
        end

        function text = string(obj)
            names = sort(string(fieldnames(obj.params)));
            lines = strings(numel(names), 1);
            for idx = 1:numel(names)
                lines(idx) = names(idx) + " = " + ...
                    kssolv.analysis.matgenlab.io.jdftx. ...
                    value_string(obj.params.(names(idx)));
            end
            text = join(lines, newline);
        end

        function text = char(obj)
            text = char(string(obj));
        end
    end
end
