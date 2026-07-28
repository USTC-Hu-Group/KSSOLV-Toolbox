classdef OxidationStateRemovalTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    methods
        function result = apply_transformation(~, structure, varargin)
            result = structure.copy();
            result = result.remove_oxidation_states();
        end
    end
    methods (Static)
        function obj = from_dict(varargin)
            obj = kssolv.analysis.matgenlab.transformations. ...
                OxidationStateRemovalTransformation();
        end
        function obj = fromDict(varargin), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                OxidationStateRemovalTransformation.from_dict(varargin{:}); end
    end
end
