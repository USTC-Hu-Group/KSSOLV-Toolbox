classdef CostDBCSV < kssolv.analysis.matgenlab.analysis.CostDB
    %COSTDBCSV Cost database stored as formula,cost/kg,name,|BibTeX|.

    properties (Access = protected)
        chemsys_entries
    end

    methods
        function obj = CostDBCSV(filename)
            filename = string(filename);
            if ~isfile(filename)
                local = fullfile(fileparts(mfilename("fullpath")), filename);
                if isfile(local)
                    filename = local;
                else
                    error("KSSOLV:Matgenlab:CostDBCSV:MissingFile", ...
                        "Cost database does not exist: %s", filename);
                end
            end
            obj.chemsys_entries = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            rows = readlines(filename);
            for index = 1:numel(rows)
                line = strip(rows(index));
                if strlength(line) == 0
                    continue
                end
                raw = char(line);
                commas = strfind(raw, ",");
                if numel(commas) < 3
                    error("KSSOLV:Matgenlab:CostDBCSV:InvalidRow", ...
                        "Malformed cost database row %d.", index);
                end
                formula = string(raw(1:commas(1) - 1));
                costPerKg = str2double(raw( ...
                    commas(1) + 1:commas(2) - 1));
                name = string(raw(commas(2) + 1:commas(3) - 1));
                reference = string(raw(commas(3) + 1:end));
                if startsWith(reference, "|") && endsWith(reference, "|")
                    reference = extractBetween(reference, 2, strlength(reference) - 1);
                end
                composition = ...
                    kssolv.analysis.matgenlab.core.Composition(formula);
                % atomic masses are numerically grams per mole.  Convert to
                % kilograms per mole before multiplying by cost per kg.
                costPerMol = costPerKg * composition.weight / 1000;
                entry = kssolv.analysis.matgenlab.analysis.CostEntry( ...
                    composition, costPerMol, name, reference);
                key = kssolv.analysis.matgenlab.analysis.CostDBCSV. ...
                    chemicalSystem(entry.elements);
                if isKey(obj.chemsys_entries, key)
                    values = obj.chemsys_entries(key);
                    values{end + 1} = entry; %#ok<AGROW>
                else
                    values = {entry};
                end
                obj.chemsys_entries(key) = values;
            end
        end

        function entries = get_entries(obj, chemsys)
            key = kssolv.analysis.matgenlab.analysis.CostDBCSV. ...
                chemicalSystem(chemsys);
            if isKey(obj.chemsys_entries, key)
                entries = obj.chemsys_entries(key);
            else
                entries = {};
            end
        end
    end

    methods (Static, Access = private)
        function key = chemicalSystem(elements)
            if ~iscell(elements)
                elements = num2cell(elements);
            end
            symbols = strings(1, numel(elements));
            for index = 1:numel(elements)
                element = elements{index};
                if ischar(element) || isstring(element)
                    symbols(index) = string(element);
                else
                    symbols(index) = string(element.symbol);
                end
            end
            key = char(strjoin(sort(symbols), "-"));
        end
    end
end
