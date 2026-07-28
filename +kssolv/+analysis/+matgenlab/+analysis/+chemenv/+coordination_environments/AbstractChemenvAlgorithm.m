classdef (Abstract) AbstractChemenvAlgorithm < handle
    %ABSTRACTCHEMENVALGORITHM Base descriptor for ChemEnv permutation algorithms.
    properties (SetAccess=protected)
        algorithm_type (1,1) string=""
    end
    methods
        function obj=AbstractChemenvAlgorithm(algorithmType)
            if nargin>0,obj.algorithm_type=string(algorithmType);end
        end
    end
    methods (Abstract)
        value=as_dict(obj)
    end
end
