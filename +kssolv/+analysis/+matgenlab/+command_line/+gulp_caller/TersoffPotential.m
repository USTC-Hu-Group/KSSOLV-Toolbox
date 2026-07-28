classdef TersoffPotential
    %TERSOFFPOTENTIAL Parse oxide Tersoff parameter records.

    properties (SetAccess = private)
        data
    end

    methods
        function obj = TersoffPotential(pot_file)
            if nargin < 1 || strlength(string(pot_file)) == 0
                folder = fileparts(mfilename("fullpath"));
                pot_file = fullfile(folder, "+data", ...
                    "OxideTersoffPotentials");
            end
            if ~isfile(pot_file)
                error("KSSOLV:Matgenlab:GULP:PotentialFile", ...
                    "Potential file '%s' does not exist.", string(pot_file));
            end
            obj.data = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            lines = splitlines(string(fileread(pot_file)));
            for index = 1:numel(lines)
                row = strtrim(lines(index));
                if strlength(row) == 0 || startsWith(row, "#"), continue; end
                closing = strfind(char(row), ")");
                if isempty(closing)
                    error("KSSOLV:Matgenlab:GULP:TersoffRecord", ...
                        "Malformed Tersoff potential record at line %d.", index);
                end
                key = char(extractBefore(row, closing(1) + 1));
                obj.data(key) = char(extractAfter(row, closing(1)));
            end
        end
    end
end
