classdef RemoveSitesTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        indices_to_remove double
    end
    methods
        function obj = RemoveSitesTransformation(indices)
            obj.indices_to_remove = reshape(double(indices), 1, []);
        end
        function result = apply_transformation(obj, structure, varargin)
            kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                validateIndices(obj.indices_to_remove, structure.num_sites);
            result = structure.copy();
            result = result.remove_sites(obj.indices_to_remove);
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                RemoveSitesTransformation(value.indices_to_remove);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                RemoveSitesTransformation.from_dict(value); end
    end
end
