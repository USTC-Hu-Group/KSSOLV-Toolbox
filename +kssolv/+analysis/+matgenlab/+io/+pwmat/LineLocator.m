classdef LineLocator < kssolv.analysis.matgenlab.util.MSONable
    %LINELOCATOR Locate matching one-based line numbers in a text file.

    methods (Static)
        function indices = locate_all_lines(filename, content, exclusion)
            if nargin < 3, exclusion = ""; end
            lines = splitlines( ...
                kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(filename));
            indices = find(matches(lines, content, exclusion));
            indices = reshape(indices, 1, []);
        end

        function obj = from_dict(varargin)
            obj = kssolv.analysis.matgenlab.io.pwmat.LineLocator();
        end

        function obj = fromDict(varargin)
            obj = kssolv.analysis.matgenlab.io.pwmat.LineLocator. ...
                from_dict(varargin{:});
        end
    end

    methods
        function value = asDict(~)
            value = struct("x_module", "pymatgen.io.pwmat.inputs", ...
                "x_class", "LineLocator");
        end
    end
end

function selected = matches(lines, content, exclusion)
content = upper(string(content));
exclusion = upper(string(exclusion));
selected = contains(upper(lines), content);
if strlength(exclusion) > 0
    selected = selected & ~contains(upper(lines), exclusion);
end
end
