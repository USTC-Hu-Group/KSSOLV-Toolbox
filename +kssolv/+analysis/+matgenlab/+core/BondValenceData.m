classdef BondValenceData
    %BONDVALENCEDATA Frozen O'Keeffe-Brese and ICSD parameter tables.

    methods (Static)
        function map = parameters()
            persistent cached
            if isempty(cached)
                rows = kssolv.analysis.matgenlab.core.BondValenceData. ...
                    readRows("bond_valence_parameters.json");
                cached = containers.Map("KeyType", "char", "ValueType", "any");
                for index = 1:numel(rows)
                    row = rows{index};
                    cached(char(string(row{1}))) = ...
                        struct("r", double(row{2}), "c", double(row{3}));
                end
            end
            map = cached;
        end

        function [data, occurrence] = icsd()
            persistent cachedData cachedOccurrence
            if isempty(cachedData)
                rows = kssolv.analysis.matgenlab.core.BondValenceData. ...
                    readRows("bond_valence_icsd.json");
                cachedData = containers.Map("KeyType", "char", ...
                    "ValueType", "any");
                for index = 1:numel(rows)
                    row = rows{index};
                    cachedData(char(string(row{1}))) = struct( ...
                        "mean", double(row{2}), "std", double(row{3}), ...
                        "n_data_pts", double(row{4}));
                end
                rows = kssolv.analysis.matgenlab.core.BondValenceData. ...
                    readRows("oxidation_state_occurrence.json");
                cachedOccurrence = containers.Map("KeyType", "char", ...
                    "ValueType", "double");
                for index = 1:numel(rows)
                    row = rows{index};
                    cachedOccurrence(char(string(row{1}))) = double(row{2});
                end
            end
            data = cachedData;
            occurrence = cachedOccurrence;
        end
    end

    methods (Static, Access = private)
        function rows = readRows(name)
            here = fileparts(mfilename("fullpath"));
            rows = jsondecode(fileread(fullfile(here, "+data", name)));
        end
    end
end
