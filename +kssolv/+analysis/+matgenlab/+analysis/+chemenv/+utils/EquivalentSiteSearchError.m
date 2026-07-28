classdef EquivalentSiteSearchError < kssolv.analysis.matgenlab.analysis.chemenv.utils.AbstractChemenvError
    %EQUIVALENTSITESEARCHERROR Missing equivalent-site error description.
    properties
        site
    end
    methods
        function obj=EquivalentSiteSearchError(site),obj.site=site;end
        function value=char(obj)
            value=sprintf("Equivalent site could not be found for the following site : %s", ...
                string(obj.site));
        end
    end
end
