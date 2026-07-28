classdef TranslateSitesTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        indices_to_move double
        translation_vector double
        vector_in_frac_coords (1,1) logical
    end
    methods
        function obj = TranslateSitesTransformation( ...
                indices, vector, vectorInFracCoords)
            if nargin < 3, vectorInFracCoords = true; end
            obj.indices_to_move = reshape(double(indices), 1, []);
            if isvector(vector) && numel(vector) == 3
                vector = reshape(vector, 1, 3);
            end
            obj.translation_vector = double(vector);
            obj.vector_in_frac_coords = logical(vectorInFracCoords);
            if ~(isequal(size(obj.translation_vector), [1,3]) || ...
                    isequal(size(obj.translation_vector), ...
                    [numel(obj.indices_to_move),3]))
                error("KSSOLV:Matgenlab:TranslateSites:Vector", ...
                    "Translation must be 1-by-3 or one row per site.");
            end
        end
        function result = apply_transformation(obj, structure, varargin)
            kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                validateIndices(obj.indices_to_move, structure.num_sites);
            result = structure.copy();
            if size(obj.translation_vector, 1) == numel(obj.indices_to_move) ...
                    && numel(obj.indices_to_move) > 1
                for index = 1:numel(obj.indices_to_move)
                    result = result.translate_sites( ...
                        obj.indices_to_move(index), ...
                        obj.translation_vector(index, :), ...
                        frac_coords = obj.vector_in_frac_coords);
                end
            else
                result = result.translate_sites(obj.indices_to_move, ...
                    obj.translation_vector(1, :), ...
                    frac_coords = obj.vector_in_frac_coords);
            end
        end
    end
    methods (Access = protected)
        function value = inverseTransformation(obj)
            value = kssolv.analysis.matgenlab.transformations. ...
                TranslateSitesTransformation(obj.indices_to_move, ...
                -obj.translation_vector, obj.vector_in_frac_coords);
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                TranslateSitesTransformation(value.indices_to_move, ...
                value.translation_vector, value.vector_in_frac_coords);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                TranslateSitesTransformation.from_dict(value); end
    end
end
