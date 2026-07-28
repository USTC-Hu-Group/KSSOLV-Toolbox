classdef SolidAngleError < kssolv.analysis.matgenlab.analysis.chemenv.utils.AbstractChemenvError
    %SOLIDANGLEERROR Invalid-cosine error description.
    properties
        cosinus (1,1) double
    end
    methods
        function obj=SolidAngleError(cosinus),obj.cosinus=cosinus;end
        function value=char(obj)
            value=sprintf(["Value of cosinus (%g) from which an angle should be " ...
                "retrieved is not between -1.0 and 1.0"],obj.cosinus);
        end
    end
end
