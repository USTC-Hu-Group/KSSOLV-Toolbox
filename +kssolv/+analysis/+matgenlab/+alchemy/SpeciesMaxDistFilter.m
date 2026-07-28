classdef SpeciesMaxDistFilter < ...
        kssolv.analysis.matgenlab.alchemy.AbstractStructureFilter
    %SPECIESMAXDISTFILTER Require each sp1 site to neighbor at least one sp2.

    properties (SetAccess = private)
        sp1
        sp2
        max_dist (1,1) double
    end

    methods
        function obj = SpeciesMaxDistFilter(sp1, sp2, maxDist)
            obj.sp1 = kssolv.analysis.matgenlab.core.getElSp(sp1);
            obj.sp2 = kssolv.analysis.matgenlab.core.getElSp(sp2);
            if ~isscalar(maxDist) || ~isfinite(maxDist) || maxDist < 0
                error("KSSOLV:Matgenlab:SpeciesMaxDistFilter:Distance", ...
                    "max_dist must be a finite nonnegative scalar.");
            end
            obj.max_dist = double(maxDist);
        end

        function accepted = test(obj, structure)
            first = zeros(1, 0);
            second = zeros(1, 0);
            for index = 1:structure.num_sites
                site = structure(index);
                if site.is_ordered && site.specie == obj.sp1
                    first(end + 1) = index; %#ok<AGROW>
                end
                if site.is_ordered && site.specie == obj.sp2
                    second(end + 1) = index; %#ok<AGROW>
                end
            end
            distances = structure.lattice.get_all_distances( ...
                structure.frac_coords(first, :), ...
                structure.frac_coords(second, :));
            accepted = all(any(distances < obj.max_dist, 2));
        end

        function value = asDict(obj)
            value = struct( ...
                "x_module", "pymatgen.alchemy.filters", ...
                "x_class", "SpeciesMaxDistFilter", "x_version", [], ...
                "sp1", obj.sp1.as_dict(), "sp2", obj.sp2.as_dict(), ...
                "max_dist", obj.max_dist);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.alchemy.SpeciesMaxDistFilter( ...
                value.sp1, value.sp2, value.max_dist);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.alchemy. ...
                SpeciesMaxDistFilter.from_dict(value);
        end
    end
end
