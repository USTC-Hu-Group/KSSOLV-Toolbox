classdef ICOXXLIST < ...
        kssolv.analysis.matgenlab.io.lobster.future.LobsterInteractionsHolder
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %ICOXXLIST Parser for integrated COHP, COOP and COBI lists.
    properties
        icoxxlist_type (1,1) string = "COXX"
        is_lcfo (1,1) logical = false
    end
    methods
        function obj = ICOXXLIST(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future. ...
                LobsterInteractionsHolder(varargin{:});
        end
        function parse_file_legacy(obj), obj.parse_file(); end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            obj.interactions = {};
            obj.spins = {};
            currentSpin = 0;
            counter = 0;
            combinedSpins = false;
            for lineIndex = 1:numel(linesValue)
                line = linesValue{lineIndex};
                if isempty(line), continue; end
                spinTokens = regexp(line, "(?i)for spin\s+(\d)", "tokens");
                if ~isempty(spinTokens)
                    numbers = cellfun(@(x) str2double(x{1}), spinTokens);
                    combinedSpins = numel(numbers) == 2;
                    if any(numbers == 1) && ~any(string(obj.spins) == "up")
                        obj.spins{end + 1} = "up";
                    end
                    if any(numbers == 2) && ~any(string(obj.spins) == "down")
                        obj.spins{end + 1} = "down";
                    end
                    currentSpin = numbers(1);
                    if currentSpin == 2, counter = 0; end
                    continue
                end
                values = regexp(strtrim(line), "\s+", "split");
                if numel(values) < 5 || isnan(str2double(values{1})), continue; end
                index = str2double(values{1});
                first = values{2};
                second = values{3};
                firstOrbital = kssolv.analysis.matgenlab.io.lobster.future. ...
                    utils.parse_orbital_from_text(first);
                secondOrbital = kssolv.analysis.matgenlab.io.lobster.future. ...
                    utils.parse_orbital_from_text(second);
                firstCenter = obj.remove_orbital(first, firstOrbital);
                secondCenter = obj.remove_orbital(second, secondOrbital);
                tail = str2double(values(5:end));
                hasTranslation = numel(tail) >= 4 && ...
                    all(mod(tail(1:3), 1) == 0);
                cells = {[], []};
                if hasTranslation
                    cells = {[0, 0, 0], tail(1:3)};
                    tail = tail(4:end);
                end
                valueUp = tail(1);
                if currentSpin == 2
                    counter = counter + 1;
                    value = obj.interactions{counter};
                    value.icoxx.down = valueUp;
                    obj.interactions{counter} = value;
                else
                    value = struct("index", index, ...
                        "centers", {{firstCenter, secondCenter}}, ...
                        "cells", {cells}, ...
                        "orbitals", {{firstOrbital, secondOrbital}}, ...
                        "length", str2double(values{4}), ...
                        "icoxx", struct("up", valueUp));
                    if combinedSpins && numel(tail) >= 2
                        value.icoxx.down = tail(2);
                        if ~any(string(obj.spins) == "down")
                            obj.spins{end + 1} = "down";
                        end
                    end
                    obj.interactions{end + 1} = value;
                end
            end
            if isempty(obj.spins), obj.spins = {"up"}; end
            obj.data = nan(numel(obj.interactions), numel(obj.spins));
            obj.process_data_into_interactions(false);
        end
        function values = get_data_by_properties(obj, options)
            arguments
                obj
                options.indices = []
                options.centers = {}
                options.cells = {}
                options.orbitals = []
                options.length = []
                options.spins = []
            end
            rows = obj.get_interaction_indices_by_properties( ...
                indices = options.indices, centers = options.centers, ...
                cells = options.cells, orbitals = options.orbitals, ...
                length = options.length) + 1;
            if isempty(options.spins), spinNames = string(obj.spins);
            else, spinNames = lower(string(options.spins)); end
            spinNames(spinNames == "1") = "up";
            spinNames(spinNames == "-1") = "down";
            columns = arrayfun(@(name) find(string(obj.spins) == name, 1), spinNames);
            values = obj.data(rows, columns);
        end
        function process_data_into_interactions(obj, preserve)
            if nargin < 2, preserve = true; end
            for index = 1:numel(obj.interactions)
                value = obj.interactions{index};
                if preserve
                    value.icoxx = struct();
                    for spin = 1:numel(obj.spins)
                        value.icoxx.(obj.spins{spin}) = obj.data(index, spin);
                    end
                else
                    for spin = 1:numel(obj.spins)
                        name = obj.spins{spin};
                        if isfield(value.icoxx, name)
                            obj.data(index, spin) = value.icoxx.(name);
                        end
                    end
                end
                obj.interactions{index} = value;
            end
        end
        function name = get_default_filename(~), name = "ICOXXLIST.lobster"; end
    end
    methods (Static, Access = private)
        function center = remove_orbital(center, orbital)
            center = string(center);
            if ~isempty(orbital)
                suffix = "_" + string(orbital);
                if endsWith(center, suffix)
                    center = extractBefore(center, strlength(center) - ...
                        strlength(suffix) + 1);
                end
            end
            center = char(center);
        end
    end
end
