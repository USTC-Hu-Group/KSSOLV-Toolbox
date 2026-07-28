classdef LobsterInteractionsHolder < ...
        kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERINTERACTIONSHOLDER Filtering operations for interaction data.
    methods
        function obj = LobsterInteractionsHolder(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end

        function indices = get_interaction_indices_by_properties(obj, options)
            arguments
                obj
                options.indices = []
                options.centers = {}
                options.cells = {}
                options.orbitals = []
                options.length = []
            end
            masks = {};
            count = numel(obj.interactions);
            if ~isempty(options.indices)
                masks{end + 1} = cellfun(@(x) any(x.index == options.indices), ...
                    obj.interactions);
            end
            if ~isempty(options.centers)
                requested = string(options.centers);
                masks{end + 1} = cellfun(@(x) all(arrayfun(@(needle) ...
                    sum(contains(string(x.centers), needle)) >= ...
                    sum(requested == needle), unique(requested))), obj.interactions);
            end
            if ~isempty(options.cells)
                requested = options.cells;
                masks{end + 1} = cellfun(@(x) all(cellfun(@(needle) ...
                    any(cellfun(@(cellValue) isequal(cellValue, needle), x.cells)), ...
                    requested)), obj.interactions);
            end
            if ~isequal(options.orbitals, [])
                requested = string(options.orbitals);
                if isempty(requested)
                    masks{end + 1} = cellfun(@(x) all(cellfun(@isempty, x.orbitals)), ...
                        obj.interactions);
                else
                    masks{end + 1} = cellfun(@(x) all(arrayfun(@(needle) ...
                        sum(contains(string(x.orbitals), needle)) >= ...
                        sum(requested == needle), unique(requested))), ...
                        obj.interactions);
                end
            end
            if ~isempty(options.length)
                masks{end + 1} = cellfun(@(x) ~isempty(x.length) && ...
                    x.length >= options.length(1) && x.length <= options.length(2), ...
                    obj.interactions);
            end
            if isempty(masks)
                indices = [];
            else
                mask = true(1, count);
                for index = 1:numel(masks), mask = mask & masks{index}; end
                indices = find(mask) - 1;
            end
        end

        function values = get_interactions_by_properties(obj, varargin)
            indices = obj.get_interaction_indices_by_properties(varargin{:});
            values = obj.interactions(indices + 1);
        end

        function process_data_into_interactions(~)
            error("KSSOLV:Matgenlab:Lobster:AbstractInteractions", ...
                "Concrete interaction readers must implement this operation.");
        end
    end

    methods (Static)
        function label = get_label_from_interaction(interaction, options)
            arguments
                interaction
                options.include_centers (1,1) logical = true
                options.include_orbitals (1,1) logical = true
                options.include_cells (1,1) logical = false
                options.include_length (1,1) logical = false
            end
            parts = strings(1, numel(interaction.centers));
            for index = 1:numel(parts)
                if options.include_centers
                    parts(index) = string(interaction.centers{index});
                end
                if options.include_cells && ~isempty(interaction.cells{index})
                    parts(index) = parts(index) + "[" + ...
                        strjoin(string(interaction.cells{index}), " ") + "]";
                end
                if options.include_orbitals && ~isempty(interaction.orbitals{index})
                    parts(index) = parts(index) + "[" + ...
                        string(interaction.orbitals{index}) + "]";
                end
            end
            if isempty(parts)
                error("KSSOLV:Matgenlab:Lobster:InteractionLabel", ...
                    "Cannot label an empty interaction.");
            end
            if options.include_length && ~isempty(interaction.length)
                parts(end) = parts(end) + compose("(%.3f)", interaction.length);
            end
            label = char(strjoin(parts, "->"));
        end

        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                from_dict(value);
        end
    end
end
