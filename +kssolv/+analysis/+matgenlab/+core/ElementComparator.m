classdef ElementComparator < ...
        kssolv.analysis.matgenlab.core.AbstractComparator
    methods
        function tf = are_equal(~, first, second)
            tf = first.element_composition == second.element_composition;
        end
        function value = get_hash(~, composition)
            value = composition.element_composition.fractional_composition;
        end
    end

end
