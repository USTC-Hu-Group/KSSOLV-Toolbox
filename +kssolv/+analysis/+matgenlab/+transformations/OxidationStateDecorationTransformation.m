classdef OxidationStateDecorationTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        oxidation_states
    end
    methods
        function obj = OxidationStateDecorationTransformation(states)
            obj.oxidation_states = states;
        end
        function result = apply_transformation(obj, structure, varargin)
            result = structure.copy();
            result = result.add_oxidation_state_by_element( ...
                obj.oxidation_states);
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                OxidationStateDecorationTransformation( ...
                value.oxidation_states);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                OxidationStateDecorationTransformation.from_dict(value); end
    end
end
