classdef CostDBElements < kssolv.analysis.matgenlab.analysis.CostDBCSV
    %COSTDBELEMENTS Built-in elemental cost database.
    methods
        function obj = CostDBElements()
            path = fullfile(fileparts(mfilename("fullpath")), ...
                "+data", "costdb_elements.csv");
            obj@kssolv.analysis.matgenlab.analysis.CostDBCSV(path);
        end
    end
end
