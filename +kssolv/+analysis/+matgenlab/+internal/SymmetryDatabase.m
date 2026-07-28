classdef SymmetryDatabase
    %SYMMETRYDATABASE Cached access to spglib's 530 Hall settings.

    methods (Static)
        function records = all()
            persistent cachedRecords
            if isempty(cachedRecords)
                template = struct( ...
                    "number", 0, "short", "", "full", "", ...
                    "international", "", "hall_number", 0, ...
                    "hall_symbol", "", "choice", "", ...
                    "point_group", "", "schoenflies", "");
                cachedRecords = repmat(template, 1, 530);
                for hall = 1:530
                    item = kssolv.analysis.spglib.Spglib. ...
                        getSpacegroupType(int32(hall));
                    cachedRecords(hall) = struct( ...
                        "number", double(item.number), ...
                        "short", string(item.international_short), ...
                        "full", string(item.international_full), ...
                        "international", string(item.international), ...
                        "hall_number", double(item.hall_number), ...
                        "hall_symbol", string(item.hall_symbol), ...
                        "choice", string(item.choice), ...
                        "point_group", ...
                        string(item.pointgroup_international), ...
                        "schoenflies", ...
                        string(item.pointgroup_schoenflies));
                end
            end
            records = cachedRecords;
        end

        function record = resolve(symbol, hexagonal)
            if nargin < 2, hexagonal = true; end
            query = kssolv.analysis.matgenlab.internal. ...
                SymmetryDatabase.normalizeSymbol(symbol);
            requestedChoice = "";
            colon = strfind(query, ":");
            if ~isempty(colon)
                requestedChoice = extractAfter(query, colon(end));
                query = extractBefore(query, colon(end));
            elseif endsWith(query, "H") && startsWith(query, "R")
                requestedChoice = "H";
                query = extractBefore(query, strlength(query));
            elseif endsWith(query, "R") && startsWith(query, "R")
                requestedChoice = "R";
                query = extractBefore(query, strlength(query));
            end

            records = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase.all();
            matches = false(1, numel(records));
            for index = 1:numel(records)
                aliases = [
                    records(index).short
                    records(index).full
                    records(index).international
                    ];
                aliases = arrayfun(@(value) ...
                    kssolv.analysis.matgenlab.internal. ...
                    SymmetryDatabase.normalizeSymbol(value), aliases);
                matches(index) = any(aliases == query);
            end
            candidates = records(matches);
            if isempty(candidates)
                error("KSSOLV:Matgenlab:SpaceGroup:Symbol", ...
                    "Bad international symbol '%s'.", symbol);
            end
            if requestedChoice ~= ""
                choiceMatches = arrayfun(@(item) ...
                    kssolv.analysis.matgenlab.internal. ...
                    SymmetryDatabase.choiceMatches( ...
                    item.choice, requestedChoice), candidates);
                if ~any(choiceMatches)
                    error("KSSOLV:Matgenlab:SpaceGroup:Setting", ...
                        "Setting '%s' is not available for '%s'.", ...
                        requestedChoice, symbol);
                end
                candidates = candidates(choiceMatches);
            elseif startsWith(query, "R")
                wanted = "H";
                if ~hexagonal, wanted = "R"; end
                choiceMatches = arrayfun(@(item) ...
                    strcmpi(item.choice, wanted), candidates);
                if any(choiceMatches), candidates = candidates(choiceMatches); end
            end
            record = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase. ...
                preferred(candidates);
        end

        function record = fromNumber(number, hexagonal)
            if nargin < 2, hexagonal = true; end
            if ~isscalar(number) || number < 1 || number > 230 || ...
                    number ~= fix(number)
                error("KSSOLV:Matgenlab:SpaceGroup:Number", ...
                    "International number must be between 1 and 230.");
            end
            records = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase.all();
            candidates = records([records.number] == number);
            if ismember(number, [146, 148, 155, 160, 161, 166, 167])
                wanted = "H";
                if ~hexagonal, wanted = "R"; end
                matches = arrayfun(@(item) ...
                    strcmpi(item.choice, wanted), candidates);
                if any(matches), candidates = candidates(matches); end
            end
            record = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase. ...
                preferred(candidates);
        end

        function operations = operations(hallNumber)
            [rotations, translations] = ...
                kssolv.analysis.spglib.Spglib.getSymmetryFromDatabase( ...
                int32(hallNumber));
            numberOperations = size(rotations, 1);
            operations = cell(1, numberOperations);
            for index = 1:numberOperations
                rotation = double(reshape(rotations(index, :, :), 3, 3));
                translation = reshape(translations(index, :), 1, 3);
                operations{index} = ...
                    kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_rotation_and_translation(rotation, translation);
            end
        end

        function value = normalizePointGroup(value)
            value = replace(string(value), " ", "");
            keys = ["2/m2/m2/m", "4/m2/m2/m", "-32/m", ...
                "6/m2/m2/m", "2/m-3", "4/m-32/m", ...
                "m2m", "2mm", "-4m2", "-62m", ...
                "312", "31m", "-31m"];
            mapped = ["mmm", "4/mmm", "-3m", "6/mmm", ...
                "m-3", "m-3m", "mm2", "mm2", "-42m", ...
                "-6m2", "32", "3m", "-3m"];
            location = find(keys == value, 1);
            if ~isempty(location), value = mapped(location); end
        end

        function value = normalizeSymbol(value)
            value = replace(string(value), " ", "");
            value = replace(value, ...
                ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"], ...
                ["_0", "_1", "_2", "_3", "_4", "_5", ...
                "_6", "_7", "_8", "_9"]);
            % pymatgen accepts both P4_1 and the common compact P41
            % notation.  Comparing without the optional underscore also
            % makes spglib's full and short spellings interoperate.
            value = replace(value, "_", "");
        end
    end

    methods (Static, Access = private)
        function tf = choiceMatches(actual, requested)
            actual = string(actual);
            requested = string(requested);
            tf = strcmpi(actual, requested);
            if tf, return; end
            % spglib appends the axis transformation to origin choices
            % (for example "1cab"). pymatgen exposes that setting as ":1".
            if ismember(requested, ["1", "2"])
                tf = startsWith(actual, requested, ...
                    "IgnoreCase", true);
            end
        end

        function record = preferred(candidates)
            if isscalar(candidates)
                record = candidates;
                return
            end
            priorities = strings(1, numel(candidates));
            for index = 1:numel(candidates)
                choice = candidates(index).choice;
                if choice == ""
                    priorities(index) = "00";
                elseif choice == "H"
                    priorities(index) = "01";
                elseif choice == "1"
                    priorities(index) = "02";
                elseif choice == "b1"
                    priorities(index) = "03";
                else
                    priorities(index) = "10" + choice;
                end
            end
            [~, order] = sort(priorities);
            record = candidates(order(1));
        end
    end
end
