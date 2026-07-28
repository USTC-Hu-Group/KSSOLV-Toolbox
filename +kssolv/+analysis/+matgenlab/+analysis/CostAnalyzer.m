classdef CostAnalyzer
    %COSTANALYZER Determine minimum-cost decompositions by convex hull.

    properties
        costdb
    end

    methods
        function obj = CostAnalyzer(costdb)
            obj.costdb = costdb;
        end

        function decomposition = get_lowest_decomposition(obj, composition)
            if ~isa(composition, ...
                    "kssolv.analysis.matgenlab.core.Composition")
                composition = ...
                    kssolv.analysis.matgenlab.core.Composition(composition);
            end
            elements = composition.elements;
            entries = {};
            for count = 1:numel(elements)
                combinations = nchoosek(1:numel(elements), count);
                for row = 1:size(combinations, 1)
                    selected = elements(combinations(row, :));
                    entries = [entries, obj.costdb.get_entries(selected)]; %#ok<AGROW>
                end
            end
            if isempty(entries)
                error("KSSOLV:Matgenlab:CostAnalyzer:MissingData", ...
                    "Cost data does not exist for this chemical system.");
            end
            try
                diagram = ...
                    kssolv.analysis.matgenlab.analysis.PhaseDiagram(entries);
                decomposition = diagram.get_decomposition(composition);
            catch exception
                error("KSSOLV:Matgenlab:CostAnalyzer:PhaseDiagram", ...
                    "Error during phase-diagram building; cost data may be missing.\n%s", ...
                    exception.message);
            end
        end

        function cost = get_cost_per_mol(obj, composition)
            if ~isa(composition, ...
                    "kssolv.analysis.matgenlab.core.Composition")
                composition = ...
                    kssolv.analysis.matgenlab.core.Composition(composition);
            end
            decomposition = obj.get_lowest_decomposition(composition);
            cost = 0;
            for index = 1:size(decomposition, 1)
                entry = decomposition{index, 1};
                amount = decomposition{index, 2};
                cost = cost + entry.energy_per_atom * amount * ...
                    composition.num_atoms;
            end
        end

        function cost = get_cost_per_kg(obj, composition)
            if ~isa(composition, ...
                    "kssolv.analysis.matgenlab.core.Composition")
                composition = ...
                    kssolv.analysis.matgenlab.core.Composition(composition);
            end
            cost = obj.get_cost_per_mol(composition) / ...
                (composition.weight / 1000);
        end
    end
end
