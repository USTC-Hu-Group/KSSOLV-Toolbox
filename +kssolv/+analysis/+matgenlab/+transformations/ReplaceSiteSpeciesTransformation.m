classdef ReplaceSiteSpeciesTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        indices_species_map cell
    end
    methods
        function obj = ReplaceSiteSpeciesTransformation(mapping)
            if iscell(mapping)&&isvector(mapping)&&numel(mapping)==2
                mapping=reshape(mapping,1,2);
            end
            if isa(mapping, "containers.Map")
                keys_ = mapping.keys();
                obj.indices_species_map = cell(numel(keys_), 2);
                for index = 1:numel(keys_)
                    obj.indices_species_map{index, 1} = str2double(keys_{index});
                    obj.indices_species_map{index, 2} = mapping(keys_{index});
                end
            elseif iscell(mapping) && size(mapping, 2) == 2
                obj.indices_species_map = mapping;
            elseif isstruct(mapping)
                names = fieldnames(mapping);
                obj.indices_species_map = cell(numel(names), 2);
                for index = 1:numel(names)
                    token = regexp(names{index}, '\d+', 'match', 'once');
                    obj.indices_species_map{index, 1} = str2double(token);
                    obj.indices_species_map{index, 2} = mapping.(names{index});
                end
            else
                error("KSSOLV:Matgenlab:ReplaceSites:Map", ...
                    "Use a two-column {index,species} cell array.");
            end
        end
        function result = apply_transformation(obj, structure, varargin)
            result = structure.copy();
            for index = 1:size(obj.indices_species_map, 1)
                siteIndex = double(obj.indices_species_map{index, 1});
                kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                    validateIndices(siteIndex, result.num_sites);
                result = result.replace(siteIndex, ...
                    obj.indices_species_map{index, 2});
            end
        end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                ReplaceSiteSpeciesTransformation(value.indices_species_map);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                ReplaceSiteSpeciesTransformation.from_dict(value); end
    end
end
