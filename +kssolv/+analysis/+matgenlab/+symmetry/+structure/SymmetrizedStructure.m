classdef SymmetrizedStructure < kssolv.analysis.matgenlab.core.Structure
    %SYMMETRIZEDSTRUCTURE Structure grouped into symmetry-equivalent sites.

    properties (SetAccess = private)
        spacegroup
        site_labels
        equivalent_indices cell
        equivalent_sites cell
        wyckoff_letters string
        wyckoff_symbols string
    end

    methods
        function obj = SymmetrizedStructure( ...
                structure, spacegroup_operations, ...
                equivalent_indices, wyckoff_letters)
            arguments
                structure (1,1) kssolv.analysis.matgenlab.core.IStructure
                spacegroup_operations (1,1) ...
                    kssolv.analysis.matgenlab.symmetry.groups.SpacegroupOperations
                equivalent_indices
                wyckoff_letters
            end
            labels = reshape(double(equivalent_indices), 1, []);
            letters = reshape(string(wyckoff_letters), 1, []);
            if numel(labels) ~= structure.num_sites || ...
                    numel(letters) ~= structure.num_sites
                error("KSSOLV:Matgenlab:SymmetrizedStructure:Length", ...
                    "equivalent_indices and wyckoff_letters must contain " + ...
                    "one value per site.");
            end
            if any(~isfinite(labels)) || any(labels ~= fix(labels)) || ...
                    any(labels < 1)
                error("KSSOLV:Matgenlab:SymmetrizedStructure:Indices", ...
                    "Equivalent-site labels must be positive integer MATLAB indices.");
            end

            obj@kssolv.analysis.matgenlab.core.Structure( ...
                structure.lattice, structure.species_and_occu, ...
                structure.frac_coords, ...
                site_properties = structure.site_properties, ...
                labels = structure.labels, ...
                properties = structure.structure_properties);
            obj.spacegroup = spacegroup_operations;
            obj.site_labels = labels;
            obj.wyckoff_letters = letters;

            [uniqueLabels, ~, inverse] = unique(labels, "sorted");
            numberGroups = numel(uniqueLabels);
            obj.equivalent_indices = cell(1, numberGroups);
            obj.equivalent_sites = cell(1, numberGroups);
            obj.wyckoff_symbols = strings(1, numberGroups);
            for group = 1:numberGroups
                indices = reshape(find(inverse == group), 1, []);
                obj.equivalent_indices{group} = indices;
                obj.equivalent_sites{group} = obj.sites(indices);
                obj.wyckoff_symbols(group) = ...
                    string(numel(indices)) + letters(indices(1));
            end
        end

        function result = copy(obj)
            result = ...
                kssolv.analysis.matgenlab.symmetry.structure. ...
                SymmetrizedStructure(obj, obj.spacegroup, ...
                obj.site_labels, obj.wyckoff_letters);
        end

        function sites = find_equivalent_sites(obj, site)
            for group = 1:numel(obj.equivalent_sites)
                candidates = obj.equivalent_sites{group};
                if any(cellfun(@(candidate) candidate == site, candidates))
                    sites = candidates;
                    return
                end
            end
            error("KSSOLV:Matgenlab:SymmetrizedStructure:SiteNotFound", ...
                "Site not in structure.");
        end

        function sites = findEquivalentSites(obj, site)
            sites = obj.find_equivalent_sites(site);
        end

        function value = char(obj)
            lines = [
                "SymmetrizedStructure"
                "Full Formula (" + obj.formula + ")"
                "Reduced Formula: " + obj.reduced_formula
                sprintf("Spacegroup: %s (%d)", ...
                    obj.spacegroup.int_symbol, obj.spacegroup.int_number)
                "abc   : " + strjoin(compose("%10.6f", ...
                    obj.lattice.abc), " ")
                "angles: " + strjoin(compose("%10.6f", ...
                    obj.lattice.angles), " ")
                sprintf("Sites (%d)", obj.num_sites)
                ];
            for group = 1:numel(obj.equivalent_sites)
                site = obj.equivalent_sites{group}{1};
                lines(end + 1) = sprintf( ...
                    "%d %s %10.6f %10.6f %10.6f %s", ...
                    group, site.species_string, site.frac_coords, ...
                    obj.wyckoff_symbols(group)); %#ok<AGROW>
            end
            value = char(strjoin(lines, newline));
        end

        function value = string(obj), value = string(char(obj)); end

        function value = as_dict(obj)
            plain = kssolv.analysis.matgenlab.core.Structure( ...
                obj.lattice, obj.species_and_occu, obj.frac_coords, ...
                site_properties = obj.site_properties, ...
                labels = obj.labels, ...
                properties = obj.structure_properties);
            value = struct( ...
                "x_module", "pymatgen.symmetry.structure", ...
                "x_class", "SymmetrizedStructure", ...
                "structure", plain.as_dict(), ...
                "spacegroup", obj.spacegroup.as_dict(), ...
                "equivalent_positions", obj.site_labels, ...
                "index_base", 1, ...
                "wyckoff_letters", obj.wyckoff_letters);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            structure = ...
                kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                value.structure);
            spacegroup = ...
                kssolv.analysis.matgenlab.symmetry.groups. ...
                SpacegroupOperations.from_dict(value.spacegroup);
            indices = value.equivalent_positions;
            if isfield(value, "index_base") && value.index_base == 0
                indices = indices + 1;
            end
            obj = ...
                kssolv.analysis.matgenlab.symmetry.structure. ...
                SymmetrizedStructure(structure, spacegroup, ...
                indices, value.wyckoff_letters);
        end
    end
end
