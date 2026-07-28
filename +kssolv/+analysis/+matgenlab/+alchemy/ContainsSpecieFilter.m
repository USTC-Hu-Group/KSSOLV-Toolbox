classdef ContainsSpecieFilter < ...
        kssolv.analysis.matgenlab.alchemy.AbstractStructureFilter
    %CONTAINSSPECIEFILTER Retain structures containing selected species.

    properties (SetAccess = private)
        species cell
        strict_compare (1,1) logical
        AND (1,1) logical
        exclude (1,1) logical
    end

    methods
        function obj = ContainsSpecieFilter(species, strictCompare, AND, exclude)
            if nargin < 2, strictCompare = false; end
            if nargin < 3, AND = true; end
            if nargin < 4, exclude = false; end
            if ischar(species) || (isstring(species) && isscalar(species)) || ...
                    isa(species, "kssolv.analysis.matgenlab.core.Element") || ...
                    isa(species, "kssolv.analysis.matgenlab.core.Species")
                species = {species};
            elseif isstring(species)
                species = cellstr(species);
            elseif ~iscell(species)
                species = num2cell(species);
            end
            obj.species = cellfun(@(item) ...
                kssolv.analysis.matgenlab.core.getElSp(item), ...
                reshape(species, 1, []), "UniformOutput", false);
            obj.strict_compare = logical(strictCompare);
            obj.AND = logical(AND);
            obj.exclude = logical(exclude);
        end

        function accepted = test(obj, structure)
            structureSpecies = structure.types_of_species;
            matches = false(1, numel(obj.species));
            for filterIndex = 1:numel(obj.species)
                query = obj.species{filterIndex};
                for structureIndex = 1:numel(structureSpecies)
                    candidate = structureSpecies{structureIndex};
                    if obj.strict_compare
                        matches(filterIndex) = candidate == query;
                    else
                        matches(filterIndex) = candidate.Z == query.Z;
                    end
                    if matches(filterIndex), break; end
                end
            end
            if obj.AND
                contains = all(matches);
            else
                contains = any(matches);
            end
            accepted = xor(contains, obj.exclude);
        end

        function value = asDict(obj)
            names = cellfun(@char, obj.species, "UniformOutput", false);
            value = struct( ...
                "x_module", "pymatgen.alchemy.filters", ...
                "x_class", "ContainsSpecieFilter", ...
                "init_args", struct("species", {names}, ...
                "strict_compare", obj.strict_compare, ...
                "AND", obj.AND, "exclude", obj.exclude));
        end
    end

    methods (Static)
        function obj = from_dict(value)
            args = value.init_args;
            obj = kssolv.analysis.matgenlab.alchemy.ContainsSpecieFilter( ...
                args.species, args.strict_compare, args.AND, args.exclude);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.alchemy. ...
                ContainsSpecieFilter.from_dict(value);
        end
    end
end
