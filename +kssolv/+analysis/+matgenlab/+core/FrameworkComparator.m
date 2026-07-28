classdef FrameworkComparator < ...
        kssolv.analysis.matgenlab.core.AbstractComparator
    methods
        function tf = are_equal(~,~,~)
            % Upstream semantics intentionally ignore every species detail.
            tf = true;
        end
        function value = get_hash(~,~)
            value = 1;
        end
    end
end
