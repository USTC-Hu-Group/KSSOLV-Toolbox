classdef COXXCAR < ...
        kssolv.analysis.matgenlab.io.lobster.future.LobsterInteractionsHolder
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %COXXCAR Parser for energy-resolved COHP, COOP and COBI tables.
    properties (Dependent, SetAccess = private)
        energies
    end
    methods
        function obj = COXXCAR(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future. ...
                LobsterInteractionsHolder(varargin{:});
        end
        function value = get.energies(obj)
            if isempty(obj.data), value = []; else, value = obj.data(:, 1); end
        end
        function parse_header(obj)
            linesValue = obj.iterate_lines();
            if numel(linesValue) < 2
                error("KSSOLV:Matgenlab:Lobster:COXXHeader", ...
                    "COXXCAR header is incomplete.");
            end
            values = sscanf(linesValue{2}, "%f").';
            obj.num_bonds = values(1);
            obj.num_data = values(3);
            obj.efermi_value = values(end);
            obj.spins = {"up"};
            if values(2) == 2, obj.spins{end + 1} = "down"; end
        end
        function parse_bonds(obj)
            obj.parse_header();
            linesValue = obj.iterate_lines();
            obj.interactions = cell(1, obj.num_bonds);
            pattern = "(?i)([a-z]+\d*(?:_\d+)?)" + ...
                "(?:\[(-?\d+\s+-?\d+\s+-?\d+)\])?" + ...
                "(?:\[([^\]\s]*)\])?(?:\(([^)]*)\))?";
            for index = 1:obj.num_bonds
                line = linesValue{index + 2};
                if contains(line, "Average")
                    obj.interactions{index} = struct("index", 0, ...
                        "centers", {{"Average"}}, "orbitals", {{}}, ...
                        "cells", {{{[]}}}, "length", []);
                    continue
                end
                number = regexp(line, "No\.(\d+)", "tokens", "once");
                parts = split(string(extractAfter(line, ":")), "->");
                centers = cell(1, numel(parts));
                cells = cell(1, numel(parts));
                orbitals = cell(1, numel(parts));
                length = [];
                for part = 1:numel(parts)
                    token = regexp(char(parts(part)), pattern, "tokens", "once");
                    if isempty(token)
                        error("KSSOLV:Matgenlab:Lobster:COXXBond", ...
                            "Cannot parse interaction line '%s'.", line);
                    end
                    centers{part} = token{1};
                    if numel(token) >= 2 && ~isempty(token{2})
                        cells{part} = sscanf(token{2}, "%d").';
                    else, cells{part} = []; end
                    if numel(token) >= 3 && ~isempty(token{3})
                        orbitals{part} = token{3};
                    else, orbitals{part} = []; end
                    if numel(token) >= 4 && ~isempty(token{4})
                        length = str2double(token{4});
                    end
                end
                obj.interactions{index} = struct( ...
                    "index", str2double(number{1}), "centers", {centers}, ...
                    "cells", {cells}, "orbitals", {orbitals}, ...
                    "length", length);
            end
        end
        function parse_data(obj)
            linesValue = obj.iterate_lines();
            rows = linesValue(obj.num_bonds + 3:end);
            rows = rows(~cellfun(@isempty, rows));
            width = obj.num_bonds * 2 * numel(obj.spins) + 1;
            table = zeros(numel(rows), width);
            for index = 1:numel(rows)
                values = sscanf(rows{index}, "%f").';
                if numel(values) ~= width
                    error("KSSOLV:Matgenlab:Lobster:COXXShape", ...
                        "COXXCAR row width does not match its header.");
                end
                table(index, :) = values;
            end
            if size(table, 1) ~= obj.num_data
                error("KSSOLV:Matgenlab:Lobster:COXXShape", ...
                    "COXXCAR data length does not match its header.");
            end
            obj.data = table;
            obj.process_data_into_interactions();
        end
        function parse_file(obj)
            obj.parse_bonds();
            obj.parse_data();
        end
        function process_data_into_interactions(obj)
            for index = 0:numel(obj.interactions) - 1
                columns = obj.interaction_indices_to_data_indices_mapping( ...
                    index, obj.spins, []);
                value = obj.interactions{index + 1};
                value.coxx = struct("up", obj.data(:, columns(1) + 1));
                value.icoxx = struct("up", obj.data(:, columns(2) + 1));
                if numel(obj.spins) == 2
                    value.coxx.down = obj.data(:, columns(3) + 1);
                    value.icoxx.down = obj.data(:, columns(4) + 1);
                end
                obj.interactions{index + 1} = value;
            end
        end
        function columns = get_data_indices_by_properties(obj, options)
            arguments
                obj
                options.indices = []
                options.centers = {}
                options.cells = {}
                options.orbitals = []
                options.length = []
                options.spins = []
                options.data_type = []
            end
            indices = obj.get_interaction_indices_by_properties( ...
                indices = options.indices, centers = options.centers, ...
                cells = options.cells, orbitals = options.orbitals, ...
                length = options.length);
            columns = obj.interaction_indices_to_data_indices_mapping( ...
                indices, options.spins, options.data_type);
        end
        function values = get_data_by_properties(obj, varargin)
            columns = obj.get_data_indices_by_properties(varargin{:});
            values = obj.data(:, columns + 1);
        end
        function columns = interaction_indices_to_data_indices_mapping( ...
                obj, interaction_indices, spins, data_type)
            if nargin < 3 || isempty(spins), spins = obj.spins; end
            if nargin < 4, data_type = []; end
            if isnumeric(spins)
                spins = arrayfun(@(x) string(x), spins, "UniformOutput", false);
            end
            spinNames = lower(string(spins));
            spinNames(spinNames == "1") = "up";
            spinNames(spinNames == "-1") = "down";
            if any(~ismember(spinNames, string(obj.spins)))
                error("KSSOLV:Matgenlab:Lobster:Spin", ...
                    "Requested spin channel is not present.");
            end
            columns = [];
            for index = reshape(interaction_indices, 1, [])
                local = [2 * index + 1, 2 * index + 2];
                if any(spinNames == "down")
                    local = [local, 2 * (obj.num_bonds + index) + 1, ...
                        2 * (obj.num_bonds + index) + 2];
                end
                columns = [columns, local];
            end
            if ~isempty(data_type)
                if lower(string(data_type)) == "coxx"
                    columns = columns(mod(columns, 2) == 1);
                elseif lower(string(data_type)) == "icoxx"
                    columns = columns(mod(columns, 2) == 0);
                end
            end
            columns = unique(columns, "sorted");
        end
        function name = get_default_filename(~), name = "COXXCAR.lobster"; end
    end
end
