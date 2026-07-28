classdef CifWriter
    %CIFWRITER Serialize matgenlab Structures as CIF or magCIF.
    %
    % Compatible with pymatgen-core v2026.7.24, pymatgen.io.cif.CifWriter.

    properties (Access = private)
        cf kssolv.analysis.matgenlab.io.cif.CifFile
    end

    properties (Dependent, SetAccess = private)
        cif_file
    end

    methods
        function obj = CifWriter(structure, options)
            arguments
                structure
                options.symprec = []
                options.write_magmoms (1,1) logical = false
                options.significant_figures (1,1) double ...
                    {mustBeInteger, mustBeNonnegative} = 8
                options.angle_tolerance (1,1) double = 5
                options.refine_struct (1,1) logical = true
                options.write_site_properties (1,1) logical = false
            end
            symprec = options.symprec;
            if options.write_magmoms && ~isempty(symprec)
                warning("KSSOLV:Matgenlab:CifWriter:MagneticSymmetry", ...
                    "Magnetic symmetry detection is disabled when writing magCIF.");
                symprec = [];
            end
            if ~isempty(symprec) && (~isscalar(symprec) || symprec <= 0)
                error("KSSOLV:Matgenlab:CifWriter:Symprec", ...
                    "symprec must be empty or a positive scalar.");
            end

            symmetry = [];
            if ~isempty(symprec)
                if options.refine_struct
                    structure = obj.refineStructure( ...
                        structure, symprec, options.angle_tolerance);
                end
                symmetry = obj.symmetryData( ...
                    structure, symprec, options.angle_tolerance);
            end

            lattice = structure.lattice;
            composition = structure.composition;
            elementComposition = composition.element_composition;
            format = sprintf("%%.%df", options.significant_figures);
            pairs = cell(0, 2);
            if isempty(symmetry)
                groupSymbol = "P 1";
                groupNumber = 1;
            else
                groupSymbol = obj.datasetField(symmetry, ...
                    ["international_symbol", "international"], "P 1");
                groupNumber = double(obj.datasetField(symmetry, ...
                    "spacegroup_number", 1));
            end
            pairs(end + 1, :) = {"_symmetry_space_group_name_H-M", char(groupSymbol)};
            pairs(end + 1, :) = {"_cell_length_a", sprintf(format, lattice.a)};
            pairs(end + 1, :) = {"_cell_length_b", sprintf(format, lattice.b)};
            pairs(end + 1, :) = {"_cell_length_c", sprintf(format, lattice.c)};
            pairs(end + 1, :) = {"_cell_angle_alpha", sprintf(format, lattice.alpha)};
            pairs(end + 1, :) = {"_cell_angle_beta", sprintf(format, lattice.beta)};
            pairs(end + 1, :) = {"_cell_angle_gamma", sprintf(format, lattice.gamma)};
            pairs(end + 1, :) = {"_symmetry_Int_Tables_number", groupNumber};
            pairs(end + 1, :) = {"_chemical_formula_structural", ...
                char(elementComposition.reduced_formula)};
            pairs(end + 1, :) = {"_chemical_formula_sum", ...
                char(elementComposition.formula)};
            pairs(end + 1, :) = {"_cell_volume", sprintf(format, lattice.volume)};
            [~, formulaUnits] = ...
                elementComposition.get_reduced_composition_and_factor();
            pairs(end + 1, :) = {"_cell_formula_units_Z", ...
                sprintf("%d", fix(formulaUnits))};

            if isempty(symmetry)
                operationIds = {"1"};
                operationStrings = {"x, y, z"};
            else
                count = double(symmetry.n_operations);
                operationIds = arrayfun(@(x) sprintf("%d", x), ...
                    1:count, "UniformOutput", false);
                operationStrings = cell(1, count);
                for index = 1:count
                    rotation = squeeze(symmetry.rotations(index, :, :));
                    operation = kssolv.analysis.matgenlab.core.SymmOp. ...
                        from_rotation_and_translation( ...
                        double(rotation), symmetry.translations(index, :));
                    operationStrings{index} = char(operation.as_xyz_str());
                end
            end
            pairs(end + 1, :) = {"_symmetry_equiv_pos_site_id", operationIds};
            pairs(end + 1, :) = {"_symmetry_equiv_pos_as_xyz", operationStrings};
            loops = {{
                "_symmetry_equiv_pos_site_id"
                "_symmetry_equiv_pos_as_xyz"
                }};

            [typeSymbols, oxidationNumbers, hasOxidationTable] = ...
                obj.oxidationTable(composition);
            if hasOxidationTable
                pairs(end + 1, :) = {"_atom_type_symbol", typeSymbols};
                pairs(end + 1, :) = { ...
                    "_atom_type_oxidation_number", oxidationNumbers};
                loops{end + 1} = {
                    "_atom_type_symbol"
                    "_atom_type_oxidation_number"
                    };
            end

            if isempty(symmetry)
                representatives = 1:structure.num_sites;
                multiplicities = ones(1, structure.num_sites);
            else
                [representatives, multiplicities] = ...
                    obj.asymmetricRepresentatives(structure, symmetry);
            end

            atomType = cell(1, 0);
            atomMultiplicity = cell(1, 0);
            atomX = cell(1, 0);
            atomY = cell(1, 0);
            atomZ = cell(1, 0);
            atomLabel = cell(1, 0);
            atomOccupancy = cell(1, 0);
            momentLabel = cell(1, 0);
            momentX = cell(1, 0);
            momentY = cell(1, 0);
            momentZ = cell(1, 0);
            propertyData = containers.Map("KeyType", "char", "ValueType", "any");
            count = 0;
            for representativeIndex = 1:numel(representatives)
                site = structure.get_site(representatives(representativeIndex));
                [species, occupancies] = site.species.items();
                [~, order] = sort(string(cellfun(@char, species, ...
                    "UniformOutput", false)));
                for speciesIndex = reshape(order, 1, [])
                    specie = species{speciesIndex};
                    occupancy = occupancies(speciesIndex);
                    atomType{end + 1} = char(string(specie)); %#ok<AGROW>
                    atomMultiplicity{end + 1} = ...
                        sprintf("%d", multiplicities(representativeIndex)); %#ok<AGROW>
                    atomX{end + 1} = sprintf(format, site.a); %#ok<AGROW>
                    atomY{end + 1} = sprintf(format, site.b); %#ok<AGROW>
                    atomZ{end + 1} = sprintf(format, site.c); %#ok<AGROW>
                    if options.write_magmoms && occupancy == fix(occupancy)
                        atomOccupancy{end + 1} = sprintf("%.1f", occupancy); %#ok<AGROW>
                    else
                        atomOccupancy{end + 1} = sprintf("%.12g", occupancy); %#ok<AGROW>
                    end
                    generatedLabel = string(specie.symbol) + string(count);
                    [magneticMoment, magneticMomentDefined] = ...
                        obj.siteMagmom(site, specie);
                    if isempty(symmetry) && ~magneticMomentDefined && ...
                            site.label ~= site.species_string
                        label = site.label;
                    else
                        label = generatedLabel;
                    end
                    atomLabel{end + 1} = char(label); %#ok<AGROW>

                    if options.write_magmoms && norm(magneticMoment) > 0
                        momentCrystal = obj.momentRelativeToCrystalAxes( ...
                            magneticMoment, lattice);
                        momentLabel{end + 1} = char(generatedLabel); %#ok<AGROW>
                        momentX{end + 1} = sprintf(format, momentCrystal(1)); %#ok<AGROW>
                        momentY{end + 1} = sprintf(format, momentCrystal(2)); %#ok<AGROW>
                        momentZ{end + 1} = sprintf(format, momentCrystal(3)); %#ok<AGROW>
                    end
                    if options.write_site_properties
                        names = fieldnames(site.site_properties);
                        for nameIndex = 1:numel(names)
                            name = names{nameIndex};
                            if strcmp(name, "magmom") && options.write_magmoms
                                continue
                            end
                            if isKey(propertyData, name)
                                values = propertyData(name);
                            else
                                values = cell(1, count);
                                values(:) = {"."};
                            end
                            value = site.site_properties.(name);
                            if isnumeric(value) && isscalar(value)
                                values{end + 1} = sprintf(format, value); %#ok<AGROW>
                            elseif islogical(value) && isscalar(value)
                                values{end + 1} = sprintf("%d", value); %#ok<AGROW>
                            elseif ischar(value) || ...
                                    (isstring(value) && isscalar(value))
                                values{end + 1} = char(string(value)); %#ok<AGROW>
                            else
                                error("KSSOLV:Matgenlab:CifWriter:SiteProperty", ...
                                    "Site property '%s' must be scalar or text.", name);
                            end
                            propertyData(name) = values;
                        end
                        % Ensure properties absent from this site retain loop
                        % cardinality.
                        propertyNames = keys(propertyData);
                        for propertyIndex = 1:numel(propertyNames)
                            name = propertyNames{propertyIndex};
                            values = propertyData(name);
                            if numel(values) < count + 1
                                values{end + 1} = "."; %#ok<AGROW>
                                propertyData(name) = values;
                            end
                        end
                    end
                    count = count + 1;
                end
            end
            if numel(unique(string(atomLabel))) ~= numel(atomLabel)
                warning("KSSOLV:Matgenlab:CifWriter:DuplicateLabels", ...
                    "Site labels are not unique, which is not CIF compliant.");
            end
            pairs(end + 1, :) = {"_atom_site_type_symbol", atomType};
            pairs(end + 1, :) = {"_atom_site_label", atomLabel};
            pairs(end + 1, :) = {"_atom_site_symmetry_multiplicity", atomMultiplicity};
            pairs(end + 1, :) = {"_atom_site_fract_x", atomX};
            pairs(end + 1, :) = {"_atom_site_fract_y", atomY};
            pairs(end + 1, :) = {"_atom_site_fract_z", atomZ};
            pairs(end + 1, :) = {"_atom_site_occupancy", atomOccupancy};
            siteLoop = {
                "_atom_site_type_symbol"
                "_atom_site_label"
                "_atom_site_symmetry_multiplicity"
                "_atom_site_fract_x"
                "_atom_site_fract_y"
                "_atom_site_fract_z"
                "_atom_site_occupancy"
                };
            if options.write_site_properties
                names = keys(propertyData);
                for index = 1:numel(names)
                    tag = "_atom_site_" + string(names{index});
                    pairs(end + 1, :) = {char(tag), propertyData(names{index})}; %#ok<AGROW>
                    siteLoop{end + 1} = char(tag); %#ok<AGROW>
                end
            end
            loops{end + 1} = siteLoop;
            if options.write_magmoms
                pairs(end + 1, :) = {"_atom_site_moment_label", momentLabel};
                pairs(end + 1, :) = {"_atom_site_moment_crystalaxis_x", momentX};
                pairs(end + 1, :) = {"_atom_site_moment_crystalaxis_y", momentY};
                pairs(end + 1, :) = {"_atom_site_moment_crystalaxis_z", momentZ};
                loops{end + 1} = {
                    "_atom_site_moment_label"
                    "_atom_site_moment_crystalaxis_x"
                    "_atom_site_moment_crystalaxis_y"
                    "_atom_site_moment_crystalaxis_z"
                    };
            end

            header = string(composition.reduced_formula);
            block = kssolv.analysis.matgenlab.io.cif.CifBlock( ...
                pairs, loops, header);
            obj.cf = kssolv.analysis.matgenlab.io.cif.CifFile( ...
                {char(header), block});
        end

        function value = get.cif_file(obj), value = obj.cf; end
        function value = char(obj), value = char(obj.cf); end
        function value = string(obj), value = string(char(obj)); end

        function write_file(obj, filename, mode)
            if nargin < 3, mode = "wt"; end
            mode = string(mode);
            if ~ismember(mode, ["wt", "at"])
                error("KSSOLV:Matgenlab:CifWriter:Mode", ...
                    "mode must be 'wt' or 'at'.");
            end
            filename = string(filename);
            compressed = endsWith(lower(filename), [".gz", ".bz2"]);
            if any(compressed)
                existing = "";
                if mode == "at" && isfile(filename)
                    existingFile = ...
                        kssolv.analysis.matgenlab.io.cif.CifFile.from_file(filename);
                    existing = string(existingFile.orig_string);
                end
                temporaryDirectory = string(tempname);
                mkdir(temporaryDirectory);
                cleanup = onCleanup(@() rmdir(temporaryDirectory, "s"));
                payload = fullfile(temporaryDirectory, "payload.cif");
                obj.writeText(payload, existing + string(obj), "w");
                if endsWith(lower(filename), ".gz")
                    archives = gzip(payload, temporaryDirectory);
                else
                    archives = bzip2(payload, temporaryDirectory);
                end
                movefile(archives{1}, filename, "f");
                clear cleanup
                return
            end
            if mode == "wt", matlabMode = "w"; else, matlabMode = "a"; end
            obj.writeText(filename, string(obj), matlabMode);
        end

        function writeFile(obj, filename, varargin)
            obj.write_file(filename, varargin{:});
        end
    end

    methods (Access = private)
        function writeText(~, filename, value, matlabMode)
            fid = fopen(filename, matlabMode, "n", "UTF-8");
            if fid < 0
                error("KSSOLV:Matgenlab:CifWriter:Open", ...
                    "Cannot open '%s' for writing.", filename);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, char(value), "char");
            clear cleanup
        end
        function data = symmetryData(~, structure, symprec, angleTolerance)
            [types, ~] = ...
                kssolv.analysis.matgenlab.io.cif.CifWriter. ...
                structureTypes(structure);
            data = kssolv.analysis.spglib.Spglib.getDataset( ...
                structure.lattice.matrix, structure.frac_coords, types, ...
                uint16(structure.num_sites), symprec, angleTolerance);
        end

        function output = refineStructure(~, structure, symprec, angleTolerance)
            [types, representatives] = ...
                kssolv.analysis.matgenlab.io.cif.CifWriter. ...
                structureTypes(structure);
            [lattice, positions, refinedTypes, count] = ...
                kssolv.analysis.spglib.Spglib.refineCell( ...
                structure.lattice.matrix, structure.frac_coords, types, ...
                int32(structure.num_sites), symprec, angleTolerance);
            count = double(count);
            positions = positions(1:count, :);
            refinedTypes = refinedTypes(1:count);
            species = cell(1, count);
            labels = strings(1, count);
            names = fieldnames(structure.site_properties);
            properties = struct();
            for nameIndex = 1:numel(names)
                name = names{nameIndex};
                old = structure.site_properties.(name);
                if iscell(old), properties.(name) = cell(1, count);
                elseif isvector(old), properties.(name) = zeros(1, count);
                else, properties.(name) = zeros(count, size(old, 2));
                end
            end
            for index = 1:count
                source = representatives(refinedTypes(index));
                site = structure.get_site(source);
                species{index} = site.species;
                labels(index) = site.label;
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    value = site.site_properties.(name);
                    if iscell(properties.(name))
                        properties.(name){index} = value;
                    elseif isvector(properties.(name))
                        properties.(name)(index) = value;
                    else
                        properties.(name)(index, :) = value;
                    end
                end
            end
            output = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice(lattice), ...
                species, positions, site_properties = properties, labels = labels);
        end

        function [representatives, multiplicities] = ...
                asymmetricRepresentatives(~, structure, symmetry)
            equivalent = double(symmetry.equivalent_atoms(:).');
            groups = unique(equivalent, "stable");
            representatives = zeros(1, numel(groups));
            multiplicities = zeros(1, numel(groups));
            for index = 1:numel(groups)
                locations = find(equivalent == groups(index));
                multiplicities(index) = numel(locations);
                coordinates = abs(structure.frac_coords(locations, :));
                [~, local] = sortrows(coordinates, [1,2,3]);
                representatives(index) = locations(local(1));
            end
            % Deterministic pymatgen-like order: species electronegativity,
            % descending multiplicity, then fractional coordinates.
            electronegativity = zeros(numel(groups), 1);
            names = strings(numel(groups), 1);
            coordinates = zeros(numel(groups), 3);
            for index = 1:numel(groups)
                site = structure.get_site(representatives(index));
                electronegativity(index) = site.species.average_electroneg;
                if isnan(electronegativity(index)), electronegativity(index) = Inf; end
                names(index) = site.species_string;
                coordinates(index, :) = site.frac_coords;
            end
            ranking = table(electronegativity, -multiplicities(:), ...
                coordinates(:,1), coordinates(:,2), coordinates(:,3), names);
            [~, order] = sortrows(ranking, 1:6);
            representatives = representatives(order);
            multiplicities = multiplicities(order);
        end

        function [symbols, states, available] = oxidationTable(~, composition)
            elements = composition.elements;
            names = strings(1, numel(elements));
            values = zeros(1, numel(elements));
            available = true;
            for index = 1:numel(elements)
                names(index) = string(elements{index});
                if isa(elements{index}, "kssolv.analysis.matgenlab.core.Species") && ...
                        ~isnan(elements{index}.oxi_state)
                    values(index) = elements{index}.oxi_state;
                else
                    available = false;
                end
            end
            [names, order] = sort(names);
            values = values(order);
            symbols = cellstr(names);
            states = cell(1, numel(values));
            for index = 1:numel(values)
                if values(index) == fix(values(index))
                    states{index} = sprintf("%.1f", values(index));
                else
                    states{index} = sprintf("%.12g", values(index));
                end
            end
        end

        function [moment, defined] = siteMagmom(~, site, specie)
            if isfield(site.site_properties, "magmom")
                value = site.site_properties.magmom;
                defined = true;
            elseif isa(specie, "kssolv.analysis.matgenlab.core.Species") && ...
                    ~isnan(specie.spin)
                value = specie.spin;
                defined = true;
            else
                value = 0;
                defined = false;
            end
            if isscalar(value), moment = [0, 0, double(value)];
            elseif isnumeric(value) && numel(value) == 3
                moment = reshape(double(value), 1, 3);
            else
                error("KSSOLV:Matgenlab:CifWriter:Magmom", ...
                    "magmom must be a scalar or three-component vector.");
            end
        end

        function relative = momentRelativeToCrystalAxes(~, moment, lattice)
            unitAxes = lattice.matrix ./ vecnorm(lattice.matrix, 2, 2);
            relative = moment / unitAxes;
        end

        function value = datasetField(~, dataset, candidates, fallback)
            value = fallback;
            for candidate = reshape(string(candidates), 1, [])
                if isfield(dataset, char(candidate))
                    value = dataset.(char(candidate));
                    return
                end
            end
        end
    end

    methods (Static, Access = private)
        function [types, representatives] = structureTypes(structure)
            names = strings(1, structure.num_sites);
            for index = 1:structure.num_sites
                names(index) = structure.get_site(index).species_string;
            end
            uniqueNames = unique(names, "stable");
            types = zeros(structure.num_sites, 1, "int32");
            representatives = zeros(1, numel(uniqueNames));
            for index = 1:numel(uniqueNames)
                locations = find(names == uniqueNames(index));
                types(locations) = int32(index);
                representatives(index) = locations(1);
            end
        end
    end
end
