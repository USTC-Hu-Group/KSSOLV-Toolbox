classdef OccupancyComparator < ...
        kssolv.analysis.matgenlab.core.AbstractComparator
    methods
        function tf = are_equal(~, first, second)
            firstValues = unique(first.element_composition.values());
            secondValues = unique(second.element_composition.values());
            tf = numel(firstValues) == numel(secondValues) && ...
                all(abs(firstValues - secondValues) <= 1e-8);
        end
        function value = get_hash(~,~)
            value = 1;
        end
    end
end
