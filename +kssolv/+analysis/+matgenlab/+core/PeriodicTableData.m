classdef PeriodicTableData
    %PERIODICTABLEDATA Lazy MATLAB-only access to pymatgen's periodic table.
    %
    % The data file is copied verbatim from pymatgen-core v2026.7.24.  This
    % class deliberately centralizes JSON field-name normalization because
    % jsondecode converts keys such as "Atomic mass" to valid MATLAB names.

    methods (Static)
        function data = all()
            persistent cachedData
            if isempty(cachedData)
                here = fileparts(mfilename("fullpath"));
                path = fullfile(here, "+data", "periodic_table.json");
                if ~isfile(path)
                    error("KSSOLV:Matgenlab:PeriodicTableData:MissingData", ...
                        "Periodic-table data file is missing: %s", path);
                end
                cachedData = jsondecode(fileread(path));
            end
            data = cachedData;
        end

        function record = element(symbol)
            symbol = char(string(symbol));
            data = kssolv.analysis.matgenlab.core.PeriodicTableData.all();
            field = kssolv.analysis.matgenlab.core.PeriodicTableData.fieldName(symbol);
            if ~isfield(data, field)
                error("KSSOLV:Matgenlab:Element:InvalidSymbol", ...
                    "'%s' is not a valid Element", symbol);
            end
            record = data.(field);

            % Named isotopes contain only their isotope-specific overrides.
            if kssolv.analysis.matgenlab.core.PeriodicTableData.rawField( ...
                    record, "Is named isotope", false)
                z = kssolv.analysis.matgenlab.core.PeriodicTableData.rawField( ...
                    record, "Atomic no", NaN);
                names = fieldnames(data);
                for idx = 1:numel(names)
                    candidate = data.(names{idx});
                    if kssolv.analysis.matgenlab.core.PeriodicTableData.rawField( ...
                            candidate, "Atomic no", NaN) == z && ...
                            ~kssolv.analysis.matgenlab.core.PeriodicTableData.rawField( ...
                            candidate, "Is named isotope", false)
                        record = kssolv.analysis.matgenlab.core. ...
                            PeriodicTableData.merge(candidate, record);
                        break
                    end
                end
            end
        end

        function tf = isValidSymbol(symbol)
            symbol = char(string(symbol));
            data = kssolv.analysis.matgenlab.core.PeriodicTableData.all();
            tf = isfield(data, kssolv.analysis.matgenlab.core. ...
                PeriodicTableData.fieldName(symbol)) && symbol ~= "_unit";
        end

        function symbols = symbols(includeIsotopes)
            arguments
                includeIsotopes (1,1) logical = false
            end
            persistent allSymbols regularSymbols
            if isempty(allSymbols)
                data = kssolv.analysis.matgenlab.core.PeriodicTableData.all();
                names = fieldnames(data);
                names(strcmp(names, kssolv.analysis.matgenlab.core. ...
                    PeriodicTableData.fieldName("_unit"))) = [];
                tmpAll = strings(0, 1);
                tmpRegular = strings(0, 1);
                for idx = 1:numel(names)
                    % Element JSON keys are valid symbols except for _unit.
                    sym = string(names{idx});
                    if ismember(sym, ["D", "T"])
                        tmpAll(end + 1, 1) = sym; %#ok<AGROW>
                    else
                        tmpAll(end + 1, 1) = sym; %#ok<AGROW>
                        tmpRegular(end + 1, 1) = sym; %#ok<AGROW>
                    end
                end
                % jsondecode preserves valid symbol keys, but explicitly use
                % atomic number to guarantee pymatgen iteration order.
                allSymbols = kssolv.analysis.matgenlab.core. ...
                    PeriodicTableData.sortSymbols(tmpAll);
                regularSymbols = kssolv.analysis.matgenlab.core. ...
                    PeriodicTableData.sortSymbols(tmpRegular);
            end
            if includeIsotopes
                symbols = allSymbols;
            else
                symbols = regularSymbols;
            end
        end

        function value = rawField(record, key, default)
            if nargin < 3
                default = [];
            end
            field = kssolv.analysis.matgenlab.core.PeriodicTableData.fieldName(key);
            if isstruct(record) && isfield(record, field)
                value = record.(field);
            else
                value = default;
            end
        end

        function value = numericField(record, number, default)
            if nargin < 3
                default = [];
            end
            candidates = [
                string(number)
                compose("%g", number)
                compose("%.1f", number)
            ];
            value = default;
            for idx = 1:numel(candidates)
                field = kssolv.analysis.matgenlab.core. ...
                    PeriodicTableData.fieldName(candidates(idx));
                if isstruct(record) && isfield(record, field)
                    value = record.(field);
                    return
                end
            end
        end

        function name = fieldName(key)
            name = matlab.lang.makeValidName(char(string(key)));
        end
    end

    methods (Static, Access = private)
        function result = merge(base, overrides)
            result = base;
            names = fieldnames(overrides);
            for idx = 1:numel(names)
                result.(names{idx}) = overrides.(names{idx});
            end
        end

        function result = sortSymbols(symbols)
            z = zeros(numel(symbols), 1);
            isotope = false(numel(symbols), 1);
            for idx = 1:numel(symbols)
                rec = kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                    element(symbols(idx));
                z(idx) = kssolv.analysis.matgenlab.core.PeriodicTableData. ...
                    rawField(rec, "Atomic no", Inf);
                isotope(idx) = ismember(symbols(idx), ["D", "T"]);
            end
            [~, order] = sortrows([z, isotope, (1:numel(z)).'], [1, 2, 3]);
            result = symbols(order);
        end
    end
end
