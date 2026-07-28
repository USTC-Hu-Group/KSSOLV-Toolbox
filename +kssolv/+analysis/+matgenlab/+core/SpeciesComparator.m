classdef SpeciesComparator < ...
        kssolv.analysis.matgenlab.core.AbstractComparator
    methods
        function tf = are_equal(~, first, second), tf = first == second; end
        function value = get_hash(~, composition)
            value = composition.fractional_composition;
        end
    end
end
