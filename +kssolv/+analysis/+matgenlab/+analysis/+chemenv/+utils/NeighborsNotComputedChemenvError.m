classdef NeighborsNotComputedChemenvError < kssolv.analysis.matgenlab.analysis.chemenv.utils.AbstractChemenvError
    %NEIGHBORSNOTCOMPUTEDCHEMENVERROR Missing-neighbor error description.
    properties
        site
    end
    methods
        function obj=NeighborsNotComputedChemenvError(site),obj.site=site;end
        function value=char(obj)
            value=sprintf("The neighbors were not computed for the following site : \\n%s", ...
                string(obj.site));
        end
    end
end
