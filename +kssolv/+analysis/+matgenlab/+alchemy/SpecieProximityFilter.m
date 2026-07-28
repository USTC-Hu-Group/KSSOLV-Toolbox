classdef SpecieProximityFilter < ...
        kssolv.analysis.matgenlab.alchemy.AbstractStructureFilter
    %SPECIEPROXIMITYFILTER Reject like species closer than configured limits.

    properties (SetAccess = private)
        species cell
        minimum_distances (1,:) double
    end

    methods
        function obj = SpecieProximityFilter(specieAndMinDist)
            [names, distances] = normalizeDistanceMap(specieAndMinDist);
            obj.species = cellfun(@(item) ...
                kssolv.analysis.matgenlab.core.getElSp(item), names, ...
                "UniformOutput", false);
            obj.minimum_distances = double(distances);
            if any(~isfinite(obj.minimum_distances) | ...
                    obj.minimum_distances < 0)
                error("KSSOLV:Matgenlab:SpecieProximityFilter:Distance", ...
                    "Minimum distances must be finite nonnegative values.");
            end
        end

        function accepted = test(obj, structure)
            accepted = true;
            for siteIndex = 1:structure.num_sites
                site = structure(siteIndex);
                for speciesIndex = 1:numel(obj.species)
                    query = obj.species{speciesIndex};
                    if ~site.species.contains(query), continue; end
                    neighbors = structure.get_neighbors( ...
                        site, obj.minimum_distances(speciesIndex));
                    for neighborIndex = 1:numel(neighbors)
                        neighbor = neighbors{neighborIndex};
                        if neighbor.species.contains(query) && ...
                                neighbor.nn_distance < ...
                                obj.minimum_distances(speciesIndex)
                            accepted = false;
                            return
                        end
                    end
                end
            end
        end

        function value = asDict(obj)
            mapping = containers.Map("KeyType", "char", "ValueType", "double");
            for index = 1:numel(obj.species)
                mapping(char(obj.species{index})) = ...
                    obj.minimum_distances(index);
            end
            value = struct( ...
                "x_module", "pymatgen.alchemy.filters", ...
                "x_class", "SpecieProximityFilter", ...
                "init_args", struct( ...
                "specie_and_min_dist_dict", mapping));
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.alchemy.SpecieProximityFilter( ...
                value.init_args.specie_and_min_dist_dict);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.alchemy. ...
                SpecieProximityFilter.from_dict(value);
        end
    end
end

function [names, distances] = normalizeDistanceMap(value)
if isa(value, "containers.Map")
    names = reshape(keys(value), 1, []);
    distances = cellfun(@(name) value(name), names);
elseif isstruct(value)
    names = reshape(fieldnames(value), 1, []);
    distances = cellfun(@(name) value.(name), names);
elseif iscell(value) && size(value, 2) == 2
    names = reshape(value(:, 1), 1, []);
    distances = cell2mat(reshape(value(:, 2), 1, []));
else
    error("KSSOLV:Matgenlab:SpecieProximityFilter:Mapping", ...
        "Species distances must be a map, struct, or two-column cell array.");
end
end
