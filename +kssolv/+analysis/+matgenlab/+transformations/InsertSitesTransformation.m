classdef InsertSitesTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        species
        coords double
        coords_are_cartesian (1,1) logical
        validate_proximity (1,1) logical
    end
    methods
        function obj = InsertSitesTransformation( ...
                species, coords, coordsAreCartesian, validateProximity)
            if nargin < 3, coordsAreCartesian = false; end
            if nargin < 4, validateProximity = true; end
            if ~iscell(species), species = cellstr(string(species)); end
            if isvector(coords)&&numel(coords)==3
                coords=reshape(coords,1,3);
            end
            if numel(species) ~= size(coords, 1)
                error("KSSOLV:Matgenlab:InsertSites:Length", ...
                    "Species and coordinates must have equal lengths.");
            end
            obj.species = reshape(species, 1, []);
            obj.coords = double(coords);
            obj.coords_are_cartesian = logical(coordsAreCartesian);
            obj.validate_proximity = logical(validateProximity);
        end
        function result = apply_transformation(obj, structure, varargin)
            result = structure.copy();
            for index = 1:numel(obj.species)
                result = result.append(obj.species{index}, ...
                    obj.coords(index, :), ...
                    coords_are_cartesian = obj.coords_are_cartesian, ...
                    validate_proximity = obj.validate_proximity);
            end
            result = result.get_sorted_structure();
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                InsertSitesTransformation(value.species, value.coords, ...
                value.coords_are_cartesian, value.validate_proximity);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                InsertSitesTransformation.from_dict(value); end
    end
end
