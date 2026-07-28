classdef SpacegroupAnalyzer
    %SPACEGROUPANALYZER Analyze periodic symmetry using bundled spglib.

    properties (SetAccess = private)
        structure
        symprec (1,1) double
        angle_tolerance (1,1) double
    end

    properties (Access = private)
        rawDataset (1,1) struct
        typeNumbers (:,1) int32
        uniqueSpecies cell
        siteProperties (1,1) struct
    end

    methods
        function obj = SpacegroupAnalyzer( ...
                structure, symprec, angle_tolerance)
            if nargin < 2, symprec = 0.01; end
            if nargin < 3, angle_tolerance = 5; end
            if ~isa(structure, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:SpacegroupAnalyzer:Structure", ...
                    "structure must be a matgenlab periodic structure.");
            end
            if ~isscalar(symprec) || symprec <= 0 || ~isfinite(symprec)
                error("KSSOLV:Matgenlab:SpacegroupAnalyzer:Symprec", ...
                    "symprec must be a finite positive scalar.");
            end
            if ~isscalar(angle_tolerance) || ~isfinite(angle_tolerance)
                error("KSSOLV:Matgenlab:SpacegroupAnalyzer:AngleTolerance", ...
                    "angle_tolerance must be finite.");
            end
            obj.structure = structure;
            obj.symprec = double(symprec);
            obj.angle_tolerance = double(angle_tolerance);
            obj.siteProperties = structure.site_properties;

            keys = strings(1, structure.num_sites);
            obj.typeNumbers = zeros(structure.num_sites, 1, "int32");
            obj.uniqueSpecies = cell(1, 0);
            for siteIndex = 1:structure.num_sites
                keys(siteIndex) = ...
                    structure(siteIndex).species_string;
                prior = find(keys(1:siteIndex-1) == keys(siteIndex), 1);
                if isempty(prior)
                    obj.uniqueSpecies{end + 1} = ... %#ok<AGROW>
                        structure(siteIndex).species;
                    obj.typeNumbers(siteIndex) = ...
                        int32(numel(obj.uniqueSpecies));
                else
                    obj.typeNumbers(siteIndex) = obj.typeNumbers(prior);
                end
            end
            obj.rawDataset = ...
                kssolv.analysis.spglib.Spglib.getDataset( ...
                structure.lattice.matrix, structure.frac_coords, ...
                obj.typeNumbers, uint16(structure.num_sites), ...
                obj.symprec, obj.angle_tolerance);
            if obj.rawDataset.spacegroup_number == 0
                exception = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SymmetryUndeterminedError( ...
                    "Symmetry detection failed for structure with formula " + ...
                    structure.formula + ".");
                throwAsCaller(exception);
            end
        end

        function value = get_space_group_symbol(obj)
            value = string(obj.rawDataset.international_symbol);
        end

        function value = get_space_group_number(obj)
            value = double(obj.rawDataset.spacegroup_number);
        end

        function value = get_hall(obj)
            value = string(obj.rawDataset.hall_symbol);
        end

        function value = get_point_group_symbol(obj)
            value = string(obj.rawDataset.pointgroup_symbol);
        end

        function value = get_crystal_system(obj)
            number = obj.get_space_group_number();
            if number <= 2
                value = "triclinic";
            elseif number <= 15
                value = "monoclinic";
            elseif number <= 74
                value = "orthorhombic";
            elseif number <= 142
                value = "tetragonal";
            elseif number <= 167
                value = "trigonal";
            elseif number <= 194
                value = "hexagonal";
            else
                value = "cubic";
            end
        end

        function value = get_lattice_type(obj)
            number = obj.get_space_group_number();
            if ismember(number, [146, 148, 155, 160, 161, 166, 167])
                value = "rhombohedral";
            elseif obj.get_crystal_system() == "trigonal"
                value = "hexagonal";
            else
                value = obj.get_crystal_system();
            end
        end

        function value = get_pearson_symbol(obj)
            families = struct("triclinic", "a", "monoclinic", "m", ...
                "orthorhombic", "o", "tetragonal", "t", ...
                "trigonal", "h", "hexagonal", "h", "cubic", "c");
            family = families.(char(obj.get_crystal_system()));
            symbol = obj.get_space_group_symbol();
            centering = extractBetween(symbol, 1, 1);
            if any(centering == ["A", "B", "C", "S"])
                centering = "C";
            end
            value = family + centering + ...
                string(double(obj.rawDataset.n_std_atoms));
        end

        function value = get_symmetry_dataset(obj)
            source = obj.rawDataset;
            numberSites = obj.structure.num_sites;
            wyckoffs = reshape(string(char( ...
                double(source.wyckoffs(:)) + double('a'))), 1, []);
            siteSymbols = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer.parseSiteSymbols( ...
                source.site_symmetry_symbols, numberSites);
            value = struct( ...
                "number", double(source.spacegroup_number), ...
                "international", string(source.international_symbol), ...
                "hall_number", double(source.hall_number), ...
                "hall", string(source.hall_symbol), ...
                "choice", string(source.choice), ...
                "transformation_matrix", source.transformation_matrix, ...
                "origin_shift", reshape(source.origin_shift, 1, 3), ...
                "rotations", source.rotations, ...
                "translations", source.translations, ...
                "wyckoffs", wyckoffs, ...
                "site_symmetry_symbols", siteSymbols, ...
                "equivalent_atoms", ...
                reshape(double(source.equivalent_atoms), 1, []) + 1, ...
                "crystallographic_orbits", ...
                reshape(double(source.crystallographic_orbits), 1, []) + 1, ...
                "primitive_lattice", source.primitive_lattice, ...
                "mapping_to_primitive", ...
                reshape(double(source.mapping_to_primitive), 1, []) + 1, ...
                "std_lattice", source.std_lattice, ...
                "std_types", reshape(double(source.std_types), 1, []), ...
                "std_positions", source.std_positions, ...
                "std_rotation_matrix", source.std_rotation_matrix, ...
                "std_mapping_to_primitive", ...
                reshape(double(source.std_mapping_to_primitive), 1, []) + 1, ...
                "pointgroup", string(source.pointgroup_symbol), ...
                "index_base", 1);
        end

        function operations = get_symmetry_operations(obj, cartesian)
            if nargin < 2, cartesian = false; end
            rotations = obj.rawDataset.rotations;
            translations = obj.rawDataset.translations;
            numberOperations = size(rotations, 1);
            operations = cell(1, numberOperations);
            matrix = obj.structure.lattice.matrix.';
            for index = 1:numberOperations
                rotation = double(reshape(rotations(index, :, :), 3, 3));
                translation = reshape(translations(index, :), 1, 3);
                translation(abs(translation - round(translation)) < 1e-10) = ...
                    round(translation( ...
                    abs(translation - round(translation)) < 1e-10));
                translation = mod(translation, 1);
                if cartesian
                    rotation = (matrix * rotation) / matrix;
                    translation = obj.structure.lattice. ...
                        get_cartesian_coords(translation);
                end
                operations{index} = ...
                    kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_rotation_and_translation(rotation, translation);
            end
        end

        function operations = ...
                get_point_group_operations(obj, cartesian)
            if nargin < 2, cartesian = false; end
            spaceOperations = obj.get_symmetry_operations(cartesian);
            operations = cell(1, 0);
            for index = 1:numel(spaceOperations)
                operation = ...
                    kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_rotation_and_translation( ...
                    spaceOperations{index}.rotation_matrix, zeros(1, 3));
                if ~any(cellfun(@(candidate) ...
                        kssolv.analysis.matgenlab.symmetry.groups. ...
                        SymmetryGroup.operationsEqual(candidate, operation), ...
                        operations))
                    operations{end + 1} = operation; %#ok<AGROW>
                end
            end
        end

        function value = get_space_group_operations(obj)
            value = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupOperations(obj.get_space_group_symbol(), ...
                obj.get_space_group_number(), ...
                obj.get_symmetry_operations());
        end

        function value = get_symmetrized_structure(obj)
            dataset = obj.get_symmetry_dataset();
            value = ...
                kssolv.analysis.matgenlab.symmetry.structure. ...
                SymmetrizedStructure(obj.structure, ...
                obj.get_space_group_operations(), ...
                dataset.equivalent_atoms, dataset.wyckoffs);
        end

        function value = get_refined_structure(obj, keep_site_properties)
            if nargin < 2, keep_site_properties = false; end
            [lattice, positions, types, numberSites] = ...
                kssolv.analysis.spglib.Spglib.refineCell( ...
                obj.structure.lattice.matrix, obj.structure.frac_coords, ...
                obj.typeNumbers, int32(obj.structure.num_sites), ...
                obj.symprec, obj.angle_tolerance);
            value = obj.structureFromSpglib( ...
                lattice, positions, types, numberSites, ...
                keep_site_properties);
            value = value.get_sorted_structure();
        end

        function value = find_primitive(obj, keep_site_properties)
            if nargin < 2, keep_site_properties = false; end
            [lattice, positions, types, numberSites] = ...
                kssolv.analysis.spglib.Spglib.findPrimitive( ...
                obj.structure.lattice.matrix, obj.structure.frac_coords, ...
                obj.typeNumbers, int32(obj.structure.num_sites), ...
                obj.symprec, obj.angle_tolerance);
            value = obj.structureFromSpglib( ...
                lattice, positions, types, numberSites, ...
                keep_site_properties);
        end

        function [coordinates, mapping] = ...
                get_ir_reciprocal_mesh_map(obj, mesh, is_shift)
            if nargin < 2, mesh = [10, 10, 10]; end
            if nargin < 3, is_shift = [0, 0, 0]; end
            mesh = double(reshape(mesh, 1, 3));
            if any(mesh < 1) || any(mesh ~= fix(mesh))
                error("KSSOLV:Matgenlab:SpacegroupAnalyzer:Mesh", ...
                    "mesh must contain three positive integers.");
            end
            shift = double(logical(reshape(is_shift, 1, 3)));
            [first, second, third] = ndgrid( ...
                0:mesh(1)-1, 0:mesh(2)-1, 0:mesh(3)-1);
            addresses = [first(:), second(:), third(:)];
            for axis = 1:3
                wrap = addresses(:, axis) > mesh(axis) / 2;
                addresses(wrap, axis) = ...
                    addresses(wrap, axis) - mesh(axis);
            end
            coordinates = (addresses + 0.5 * shift) ./ mesh;
            numberPoints = size(coordinates, 1);
            mapping = zeros(numberPoints, 1);
            rotations = obj.get_point_group_operations(false);
            for pointIndex = 1:numberPoints
                if mapping(pointIndex) ~= 0, continue; end
                mapping(pointIndex) = pointIndex;
                point = coordinates(pointIndex, :);
                for operationIndex = 1:numel(rotations)
                    rotation = rotations{operationIndex}.rotation_matrix;
                    for timeReversal = [-1, 1]
                        transformed = timeReversal * (point / rotation);
                        difference = coordinates - transformed;
                        difference = difference - round(difference);
                        equivalent = all(abs(difference) <= 1e-8, 2);
                        unmapped = equivalent & mapping == 0;
                        mapping(unmapped) = pointIndex;
                    end
                end
            end
        end

        function values = get_ir_reciprocal_mesh(obj, mesh, is_shift)
            if nargin < 2, mesh = [10, 10, 10]; end
            if nargin < 3, is_shift = [0, 0, 0]; end
            [coordinates, mapping] = ...
                obj.get_ir_reciprocal_mesh_map(mesh, is_shift);
            representatives = unique(mapping, "stable");
            values = cell(1, numel(representatives));
            for index = 1:numel(representatives)
                representative = representatives(index);
                values{index} = {coordinates(representative, :), ...
                    sum(mapping == representative)};
            end
        end

        function matrix = ...
                get_conventional_to_primitive_transformation_matrix( ...
                obj, internationalMonoclinic)
            if nargin<2,internationalMonoclinic=[];end
            if ~isempty(internationalMonoclinic)
                validateattributes(internationalMonoclinic, ...
                    {'logical','numeric'},{"scalar"});
            end
            symbol = obj.get_space_group_symbol();
            centering = extractBetween(symbol, 1, 1);
            if centering == "P"
                matrix = eye(3);
            elseif centering == "R"
                matrix = [-1, 1, 1; 2, 1, 1; -1, -2, 1] / 3;
            elseif centering == "I"
                matrix = [-1, 1, 1; 1, -1, 1; 1, 1, -1] / 2;
            elseif centering == "F"
                matrix = [0, 1, 1; 1, 0, 1; 1, 1, 0] / 2;
            elseif any(centering == ["C", "A"])
                if obj.get_crystal_system() == "monoclinic"
                    matrix = [1, 1, 0; -1, 1, 0; 0, 0, 2] / 2;
                else
                    matrix = [1, -1, 0; 1, 1, 0; 0, 0, 2] / 2;
                end
            else
                error("KSSOLV:Matgenlab:SpacegroupAnalyzer:Centering", ...
                    "Unrecognized space-group centering '%s'.", centering);
            end
        end

        function value = get_primitive_standard_structure( ...
                obj, international_monoclinic, keep_site_properties)
            if nargin < 2, international_monoclinic = true; end
            if nargin < 3, keep_site_properties = false; end
            conventional = obj.conventionalStandard( ...
                international_monoclinic, keep_site_properties);
            if startsWith(obj.get_space_group_symbol(), "P")
                value = conventional;
                return
            end
            transform = ...
                obj.get_conventional_to_primitive_transformation_matrix( ...
                international_monoclinic);
            primitiveLattice = ...
                kssolv.analysis.matgenlab.core.Lattice( ...
                transform * conventional.lattice.matrix);
            value = primitiveFromConventional( ...
                conventional, primitiveLattice, keep_site_properties);
        end

        function value = get_conventional_standard_structure( ...
                obj, international_monoclinic, keep_site_properties)
            if nargin < 2, international_monoclinic = true; end
            if nargin < 3, keep_site_properties = false; end
            value = obj.conventionalStandard( ...
                international_monoclinic, keep_site_properties);
        end

        function tf = is_laue(obj)
            laue = ["-1", "2/m", "mmm", "4/m", "4/mmm", ...
                "-3", "-3m", "6/m", "6/mmm", "m-3", "m-3m"];
            tf = any(obj.get_point_group_symbol() == laue);
        end

        function weights = get_kpoint_weights(obj, kpoints, tolerance)
            if nargin < 3, tolerance = 1e-5; end
            kpoints = double(kpoints);
            mesh = ones(1, 3);
            shift = zeros(1, 3);
            for axis = 1:3
                nonzero = abs(kpoints(:, axis)) > 1e-5;
                if any(~nonzero)
                    if any(nonzero)
                        mesh(axis) = max(abs(round( ...
                            1 ./ kpoints(nonzero, axis))));
                    end
                else
                    mesh(axis) = max(abs(round( ...
                        0.5 ./ kpoints(:, axis))));
                    shift(axis) = 1;
                end
            end
            [grid, mapping] = ...
                obj.get_ir_reciprocal_mesh_map(mesh, shift);
            weights = zeros(size(kpoints, 1), 1);
            used = false(size(grid, 1), 1);
            for pointIndex = 1:size(kpoints, 1)
                difference = grid - kpoints(pointIndex, :);
                difference = difference - round(difference);
                match = find(all(abs(difference) <= tolerance, 2), 1);
                if isempty(match) || used(match)
                    error("KSSOLV:Matgenlab:SpacegroupAnalyzer:Kpoints", ...
                        "Unable to find one-to-one irreducible k-point mapping.");
                end
                used(match) = true;
                weights(pointIndex) = sum(mapping == mapping(match));
            end
            if numel(unique(mapping)) ~= size(kpoints, 1)
                error("KSSOLV:Matgenlab:SpacegroupAnalyzer:Kpoints", ...
                    "Input does not contain each irreducible point once.");
            end
            weights = weights / sum(weights);
        end
    end

    methods (Access = private)
        function value = conventionalStandard( ...
                obj, internationalMonoclinic, keepSiteProperties)
            refined = obj.get_refined_structure(keepSiteProperties);
            oldLattice = refined.lattice;
            latticeType = obj.get_lattice_type();
            lengths = oldLattice.lengths;
            transform = zeros(3);
            newLattice = oldLattice;
            if any(latticeType == ["orthorhombic", "cubic"])
                symbol = obj.get_space_group_symbol();
                if startsWith(symbol, "C")
                    transform(3, 3) = 1;
                    [inPlane, order] = sort(lengths(1:2));
                    transform(1, order(1)) = 1;
                    transform(2, order(2)) = 1;
                    target = [inPlane, lengths(3)];
                elseif startsWith(symbol, "A")
                    transform(3, 1) = 1;
                    [inPlane, order] = sort(lengths(2:3));
                    transform(1, order(1)+1) = 1;
                    transform(2, order(2)+1) = 1;
                    target = [inPlane, lengths(1)];
                else
                    [target, order] = sort(lengths);
                    for index = 1:3
                        transform(index, order(index)) = 1;
                    end
                end
                newLattice = ...
                    kssolv.analysis.matgenlab.core.Lattice. ...
                    orthorhombic(target(1), target(2), target(3));
            elseif latticeType == "tetragonal"
                [sortedLengths, order] = sort(lengths);
                for index = 1:3
                    transform(index, order(index)) = 1;
                end
                a = sortedLengths(1);
                c = sortedLengths(3);
                if abs(sortedLengths(2)-sortedLengths(3)) < 1e-5 && ...
                        abs(sortedLengths(1)-sortedLengths(3)) > 1e-5
                    a = sortedLengths(3);
                    c = sortedLengths(1);
                    transform = [0,0,1;0,1,0;1,0,0] * transform;
                end
                newLattice = ...
                    kssolv.analysis.matgenlab.core.Lattice.tetragonal(a,c);
            elseif any(latticeType == ["hexagonal", "rhombohedral"])
                [a, c, refined, transform] = ...
                    conventionalHexagonal(refined);
                newLattice = ...
                    kssolv.analysis.matgenlab.core.Lattice( ...
                    [a/2,-a*sqrt(3)/2,0; ...
                    a/2,a*sqrt(3)/2,0;0,0,c]);
            elseif latticeType == "monoclinic"
                [newLattice, transform] = conventionalMonoclinic( ...
                    oldLattice, obj.get_space_group_symbol(), ...
                    internationalMonoclinic);
            elseif latticeType == "triclinic"
                transform = eye(3);
            end
            coordinates = refined.frac_coords * transform.';
            properties = struct();
            if keepSiteProperties
                properties = refined.site_properties;
            end
            value = kssolv.analysis.matgenlab.core.Structure( ...
                newLattice, refined.species_and_occu, coordinates, ...
                to_unit_cell=true, site_properties=properties);
            value = value.get_sorted_structure();
        end

        function value = standardizedStructure( ...
                obj, primitive, keepSiteProperties)
            if primitive
                [lattice, positions, types, numberSites] = ...
                    kssolv.analysis.spglib.Spglib.findPrimitive( ...
                    obj.structure.lattice.matrix, ...
                    obj.structure.frac_coords, obj.typeNumbers, ...
                    int32(obj.structure.num_sites), obj.symprec, ...
                    obj.angle_tolerance);
            else
                [lattice, positions, types, numberSites] = ...
                    kssolv.analysis.spglib.Spglib.refineCell( ...
                    obj.structure.lattice.matrix, ...
                    obj.structure.frac_coords, obj.typeNumbers, ...
                    int32(obj.structure.num_sites), obj.symprec, ...
                    obj.angle_tolerance);
            end
            value = obj.structureFromSpglib( ...
                lattice, positions, types, numberSites, ...
                keepSiteProperties);
            value = value.get_sorted_structure();
        end

        function value = structureFromSpglib( ...
                obj, lattice, positions, types, numberSites, keepProperties)
            numberSites = double(numberSites);
            if numberSites <= 0
                error("KSSOLV:Matgenlab:SpacegroupAnalyzer:Standardize", ...
                    "spglib failed to produce a structure.");
            end
            positions = positions(1:numberSites, :);
            types = reshape(double(types(1:numberSites)), 1, []);
            species = cell(1, numberSites);
            for index = 1:numberSites
                species{index} = obj.uniqueSpecies{types(index)};
            end
            properties = struct();
            if keepProperties
                names = fieldnames(obj.siteProperties);
                originalTypes = reshape(double(obj.typeNumbers), 1, []);
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    source = obj.siteProperties.(name);
                    values = cell(1, numberSites);
                    for index = 1:numberSites
                        original = find(originalTypes == types(index), 1);
                        if iscell(source)
                            values{index} = source{original};
                        elseif isvector(source)
                            values{index} = source(original);
                        else
                            values{index} = source(original, :);
                        end
                    end
                    properties.(name) = values;
                end
            end
            value = kssolv.analysis.matgenlab.core.Structure( ...
                lattice.', species, positions, ...
                to_unit_cell = true, site_properties = properties);
        end
    end

    methods (Static, Access = private)
        function values = parseSiteSymbols(raw, numberSites)
            if isstring(raw)
                values = reshape(raw, 1, []);
            elseif iscell(raw)
                values = reshape(string(raw), 1, []);
            elseif ischar(raw) && numberSites == 1
                values = string(strtrim(raw));
            elseif ischar(raw)
                values = reshape(string(cellstr(raw)), 1, []);
            else
                values = repmat("", 1, numberSites);
            end
        end
    end
end

function value=primitiveFromConventional( ...
        conventional,primitiveLattice,keepSiteProperties)
fractional=primitiveLattice.get_fractional_coords( ...
    conventional.cart_coords);
keep=false(1,conventional.num_sites);
keptCoordinates=zeros(0,3);
keptSpecies=strings(0,1);
for index=1:conventional.num_sites
    coordinate=mod(fractional(index,:),1);
    species=conventional(index).species_string;
    duplicate=false;
    for prior=1:size(keptCoordinates,1)
        if keptSpecies(prior)~=species,continue,end
        difference=coordinate-keptCoordinates(prior,:);
        difference=difference-round(difference);
        if norm(primitiveLattice.get_cartesian_coords(difference))<1e-5
            duplicate=true;
            break
        end
    end
    if ~duplicate
        keep(index)=true;
        keptCoordinates(end+1,:)=coordinate; %#ok<AGROW>
        keptSpecies(end+1,1)=species; %#ok<AGROW>
    end
end
properties=struct();
if keepSiteProperties
    properties=subsetSiteProperties( ...
        conventional.site_properties,find(keep));
end
value=kssolv.analysis.matgenlab.core.Structure( ...
    primitiveLattice,conventional.species_and_occu(keep), ...
    fractional(keep,:),to_unit_cell=true,site_properties=properties);
value=value.get_sorted_structure();
end

function [a,c,structure,transform]=conventionalHexagonal(structure)
lengths=structure.lattice.lengths;
angles=structure.lattice.angles;
if max(abs(lengths-lengths(1)))<1e-3 && ...
        max(abs(angles-angles(1)))<1e-2
    structure=structure.make_supercell([1,-1,0;0,1,-1;1,1,1]);
    lengths=sort(structure.lattice.lengths);
else
    lengths=structure.lattice.lengths;
end
a=lengths(1);c=lengths(3);
if abs(lengths(2)-lengths(3))<1e-3
    a=lengths(3);c=lengths(1);
end
transform=eye(3);
end

function [lattice,transform]= ...
        conventionalMonoclinic(oldLattice,symbol,international)
matrix=oldLattice.matrix;
lengths=oldLattice.lengths;
transform=zeros(3);
newMatrix=[];
if startsWith(symbol,"C")
    transform(3,3)=1;
    permutations=[1,2;2,1];
    for index=1:2
        order=permutations(index,:);
        trial=kssolv.analysis.matgenlab.core.Lattice( ...
            matrix([order,3],:));
        alpha=trial.angles(1);
        if abs(alpha-90)<1e-10,continue,end
        signs=[1,1];
        if alpha>90,signs=[-1,-1];alpha=180-alpha;end
        a=lengths(order(1));b=lengths(order(2));c=lengths(3);
        transform(1,order(1))=signs(1);
        transform(2,order(2))=signs(2);
        alpha=deg2rad(alpha);
        newMatrix=[a,0,0;0,b,0; ...
            0,c*cos(alpha),c*sin(alpha)];
    end
    if isempty(newMatrix)
        [inPlane,order]=sort(lengths(1:2));
        transform(1,order(1))=1;transform(2,order(2))=1;
        newMatrix=diag([inPlane,lengths(3)]);
    end
else
    permutations=perms(1:3);
    for index=1:size(permutations,1)
        order=permutations(index,:);
        trial=kssolv.analysis.matgenlab.core.Lattice(matrix(order,:));
        trialLengths=trial.lengths;
        alpha=trial.angles(1);
        if abs(alpha-90)<1e-10||trialLengths(2)>=trialLengths(3)
            continue
        end
        signs=[1,1];
        if alpha>90,signs=[-1,-1];alpha=180-alpha;end
        transform=zeros(3);
        transform(1,order(1))=signs(1);
        transform(2,order(2))=signs(2);
        transform(3,order(3))=1;
        alpha=deg2rad(alpha);
        newMatrix=[trialLengths(1),0,0;0,trialLengths(2),0; ...
            0,trialLengths(3)*cos(alpha), ...
            trialLengths(3)*sin(alpha)];
    end
    if isempty(newMatrix)
        [~,order]=sort(lengths);
        transform=zeros(3);
        for index=1:3,transform(index,order(index))=1;end
        newMatrix=matrix(order,:);
    end
end
if international
    operation=[0,1,0;1,0,0;0,0,-1];
    transform=operation*transform;
    newMatrix=operation*newMatrix;
    trial=kssolv.analysis.matgenlab.core.Lattice(newMatrix);
    if trial.angles(2)<90
        operation=diag([-1,-1,1]);
        transform=operation*transform;
        newMatrix=operation*newMatrix;
    end
end
lattice=kssolv.analysis.matgenlab.core.Lattice(newMatrix);
end

function value=subsetSiteProperties(properties,indices)
value=struct();
names=fieldnames(properties);
for nameIndex=1:numel(names)
    name=names{nameIndex};
    source=properties.(name);
    if iscell(source)
        value.(name)=source(indices);
    elseif isvector(source)
        value.(name)=source(indices);
    else
        value.(name)=source(indices,:);
    end
end
end
