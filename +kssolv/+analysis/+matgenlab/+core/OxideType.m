classdef OxideType
    %OXIDETYPE Classify O-containing structures by short O-O/O-H bonds.

    properties (SetAccess = protected)
        structure
        relative_cutoff (1,1) double = 1.1
        oxide_type (1,1) string = "None"
        nbonds (1,1) double = 0
    end

    methods
        function obj = OxideType(structure, relativeCutoff)
            if nargin < 2, relativeCutoff = 1.1; end
            obj.structure = structure;
            obj.relative_cutoff = double(relativeCutoff);
            [obj.oxide_type, obj.nbonds] = obj.parse_oxide();
        end

        function [kind, numberBonds] = parse_oxide(obj)
            structure = obj.structure;
            composition = structure.composition.element_composition;
            if ~composition.contains("O") || composition.is_element
                kind = "None"; numberBonds = 0; return
            end
            oxygen = zeros(0, 3);
            hydrogen = zeros(0, 3);
            for index = 1:structure.num_sites
                site = structure.get_site(index);
                symbols = string(cellfun(@(item) item.symbol, ...
                    site.species.elements, "UniformOutput", false));
                if any(symbols == "O")
                    oxygen(end + 1, :) = site.frac_coords; %#ok<AGROW>
                end
                if any(symbols == "H")
                    hydrogen(end + 1, :) = site.frac_coords; %#ok<AGROW>
                end
            end
            if ~isempty(hydrogen)
                distances = structure.lattice.get_all_distances( ...
                    oxygen, hydrogen);
                mask = distances < obj.relative_cutoff * 0.93;
                if any(mask, "all")
                    kind = "hydroxide";
                    numberBonds = floor(numel(find(mask)) / 2);
                    return
                end
            end

            distances = structure.lattice.get_all_distances(oxygen, oxygen);
            distances(1:size(distances, 1) + 1:end) = 1000;
            superMask = distances < obj.relative_cutoff * 1.35;
            peroxideMask = distances < obj.relative_cutoff * 1.49;
            isSuperoxide = any(superMask, "all");
            isPeroxide = ~isSuperoxide && any(peroxideMask, "all");
            if isSuperoxide, [bondAtoms, ~] = find(superMask);
            elseif isPeroxide, [bondAtoms, ~] = find(peroxideMask);
            else, bondAtoms = zeros(0, 1);
            end
            isOzonide = isSuperoxide && ...
                numel(bondAtoms) > numel(unique(bondAtoms));
            if isOzonide, kind = "ozonide";
            elseif isSuperoxide, kind = "superoxide";
            elseif isPeroxide, kind = "peroxide";
            else, kind = "oxide";
            end
            numberBonds = numel(unique(bondAtoms));
            if kind == "oxide", numberBonds = composition("O"); end
        end
    end
end
