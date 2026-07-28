classdef OrderDisorderElementComparator < ...
        kssolv.analysis.matgenlab.core.AbstractComparator
    methods
        function tf = are_equal(~, first, second)
            firstNames = fieldnames(first.element_composition.get_el_amt_dict());
            secondNames = fieldnames(second.element_composition.get_el_amt_dict());
            tf = all(ismember(firstNames, secondNames)) || ...
                all(ismember(secondNames, firstNames));
        end
        function value = get_hash(~, composition)
            value = composition.fractional_composition;
        end
    end
end
