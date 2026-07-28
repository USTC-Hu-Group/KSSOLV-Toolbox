classdef ClassPrintFormatter
    %CLASSPRINTFORMATTER Deterministic readable formatting for tag objects.
    methods
        function text = string(obj)
            names = sort(string(properties(obj)));
            lines = strings(numel(names) + 1, 1);
            lines(1) = string(class(obj));
            for idx = 1:numel(names)
                value = obj.(names(idx));
                lines(idx + 1) = names(idx) + " = " + ...
                    kssolv.analysis.matgenlab.io.jdftx.value_string(value);
            end
            text = join(lines, newline);
        end

        function text = char(obj)
            text = char(string(obj));
        end
    end
end
