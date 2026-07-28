classdef ListLocator < kssolv.analysis.matgenlab.util.MSONable
    %LISTLOCATOR Locate matching zero-based entries in a list of strings.

    methods (Static)
        function indices = locate_all_lines(lines, content, exclusion)
            if nargin < 3, exclusion = ""; end
            lines = reshape(string(lines), 1, []);
            content = upper(string(content));
            exclusion = upper(string(exclusion));
            selected = contains(upper(lines), content);
            if strlength(exclusion) > 0
                selected = selected & ...
                    ~contains(upper(lines), exclusion);
            end
            indices = reshape(find(selected) - 1, 1, []);
        end

        function obj = from_dict(varargin)
            obj = kssolv.analysis.matgenlab.io.pwmat.ListLocator();
        end

        function obj = fromDict(varargin)
            obj = kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                from_dict(varargin{:});
        end
    end

    methods
        function value = asDict(~)
            value = struct("x_module", "pymatgen.io.pwmat.inputs", ...
                "x_class", "ListLocator");
        end
    end
end
