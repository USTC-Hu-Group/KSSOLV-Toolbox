classdef PointGroupAnalyzer
    %POINTGROUPANALYZER Determine the finite point group of a molecule.

    properties (SetAccess = private)
        molecule
        centered_mol
        tolerance (1,1) double
        eigen_tolerance (1,1) double
        matrix_tolerance (1,1) double
        sch_symbol (1,1) string
        symmops cell
    end

    methods
        function obj = PointGroupAnalyzer( ...
                molecule, tolerance, eigen_tolerance, matrix_tolerance)
            if nargin < 2, tolerance = 0.3; end
            if nargin < 3, eigen_tolerance = 0.01; end
            if nargin < 4, matrix_tolerance = 0.1; end
            if ~isa(molecule, ...
                    "kssolv.analysis.matgenlab.core.IMolecule")
                error("KSSOLV:Matgenlab:PointGroupAnalyzer:Molecule", ...
                    "molecule must be a matgenlab Molecule or IMolecule.");
            end
            obj.molecule = molecule;
            obj.centered_mol = molecule.get_centered_molecule();
            obj.tolerance = tolerance;
            obj.eigen_tolerance = eigen_tolerance;
            obj.matrix_tolerance = matrix_tolerance;
            [obj.symmops, obj.sch_symbol] = obj.analyzeFiniteGroup();
        end

        function value = get_pointgroup(obj)
            value = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                PointGroupOperations(obj.sch_symbol, ...
                obj.symmops, obj.matrix_tolerance);
        end

        function value = get_symmetry_operations(obj)
            value = obj.symmops;
        end

        function value = get_rotational_symmetry_number(obj)
            if obj.sch_symbol == "D*h"
                % The finite operation seed for an infinite linear group is
                % {E, i}; by convention its rotational symmetry number is 2.
                value = 2;
                return
            end
            value = sum(cellfun(@(operation) ...
                det(operation.rotation_matrix) > 0, obj.symmops));
        end

        function tf = is_valid_op(obj, operation)
            tf = obj.operationMapsMolecule(operation);
        end

        function result = get_equivalent_atoms(obj)
            numberSites = obj.centered_mol.num_sites;
            parent = 1:numberSites;
            operationMap = cell(numberSites);
            for operationIndex = 1:numel(obj.symmops)
                operation = obj.symmops{operationIndex};
                mapping = obj.siteMapping(operation);
                if isempty(mapping), continue; end
                for siteIndex = 1:numberSites
                    parent = unionSets(parent, siteIndex, mapping(siteIndex));
                    operationMap{siteIndex, mapping(siteIndex)} = operation;
                end
            end
            for index = 1:numberSites
                parent(index) = findRoot(parent, index);
            end
            representatives = unique(parent, "stable");
            equivalentSets = cell(1, numel(representatives));
            symmetryOperations = cell(1, numel(representatives));
            for index = 1:numel(representatives)
                sites = find(parent == representatives(index));
                equivalentSets{index} = sites;
                operations = cell(1, numel(sites));
                operations{1} = ...
                    kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_rotation_and_translation(eye(3), zeros(1, 3));
                for siteIndex = 2:numel(sites)
                    operations{siteIndex} = ...
                        operationMap{sites(1), sites(siteIndex)};
                end
                symmetryOperations{index} = operations;
            end
            result = struct("eq_sets", {equivalentSets}, ...
                "sym_ops", {symmetryOperations}, "index_base", 1);

            function root = findRoot(values, item)
                root = item;
                while values(root) ~= root, root = values(root); end
            end
            function values = unionSets(values, first, second)
                firstRoot = findRoot(values, first);
                secondRoot = findRoot(values, second);
                values(secondRoot) = firstRoot;
            end
        end

        function result = symmetrize_molecule(obj)
            equivalent = obj.get_equivalent_atoms();
            coordinates = obj.centered_mol.cart_coords;
            for groupIndex = 1:numel(equivalent.eq_sets)
                sites = equivalent.eq_sets{groupIndex};
                operations = equivalent.sym_ops{groupIndex};
                aligned = zeros(numel(sites), 3);
                for siteIndex = 1:numel(sites)
                    aligned(siteIndex, :) = ...
                        operations{siteIndex}.inverse.operate( ...
                        coordinates(sites(siteIndex), :));
                end
                representative = mean(aligned, 1);
                for siteIndex = 1:numel(sites)
                    coordinates(sites(siteIndex), :) = ...
                        operations{siteIndex}.operate(representative);
                end
            end
            species = cell(1, obj.centered_mol.num_sites);
            for index = 1:numel(species)
                species{index} = obj.centered_mol(index).species;
            end
            symmetrized = kssolv.analysis.matgenlab.core.Molecule( ...
                species, coordinates, charge = obj.centered_mol.charge, ...
                spin_multiplicity = obj.centered_mol.spin_multiplicity, ...
                charge_spin_check = false);
            result = struct("sym_mol", symmetrized, ...
                "eq_sets", {equivalent.eq_sets}, ...
                "sym_ops", {equivalent.sym_ops}, "index_base", 1);
        end
    end

    methods (Access = private)
        function [operations, symbol] = analyzeFiniteGroup(obj)
            coordinates = obj.centered_mol.cart_coords;
            % Treat deviations below the positional matching tolerance as
            % numerical distortion of the ideal molecular dimension.
            rankValue = rank(coordinates, max(1e-8, obj.tolerance * 0.5));
            identity = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(eye(3), zeros(1, 3));
            if rankValue == 0
                operations = {identity};
                symbol = "Kh";
                return
            end
            if rankValue == 1
                inversion = ...
                    kssolv.analysis.matgenlab.core.SymmOp.inversion();
                operations = {identity};
                if obj.operationMapsMolecule(inversion)
                    operations{end + 1} = inversion;
                    symbol = "D*h";
                else
                    symbol = "C*v";
                end
                return
            end

            species = strings(1, obj.centered_mol.num_sites);
            for index = 1:numel(species)
                species(index) = ...
                    obj.centered_mol(index).species_string;
            end
            source = obj.independentSourceBasis(coordinates, rankValue);
            sourceSpecies = species(source);
            operations = {identity};
            candidates = cell(1, numel(source));
            sourceRadii = vecnorm(coordinates(source, :), 2, 2);
            allRadii = vecnorm(coordinates, 2, 2);
            for basisIndex = 1:numel(source)
                candidates{basisIndex} = find( ...
                    species == sourceSpecies(basisIndex) & ...
                    abs(allRadii.' - sourceRadii(basisIndex)) <= ...
                    obj.tolerance);
            end
            sourceDistances = squareformLocal( ...
                coordinates(source, :));

            if rankValue == 3
                for first = candidates{1}
                    for second = candidates{2}
                        if first == second || abs(norm( ...
                                coordinates(first, :) - ...
                                coordinates(second, :)) - ...
                                sourceDistances(1, 2)) > 2 * obj.tolerance
                            continue
                        end
                        for third = candidates{3}
                            targetIndices = [first, second, third];
                            if numel(unique(targetIndices)) < 3, continue; end
                            if abs(norm(coordinates(first, :) - ...
                                    coordinates(third, :)) - ...
                                    sourceDistances(1, 3)) > ...
                                    2 * obj.tolerance || ...
                                    abs(norm(coordinates(second, :) - ...
                                    coordinates(third, :)) - ...
                                    sourceDistances(2, 3)) > ...
                                    2 * obj.tolerance
                                continue
                            end
                            sourceMatrix = coordinates(source, :);
                            targetMatrix = coordinates(targetIndices, :);
                            rotation = (sourceMatrix \ targetMatrix).';
                            operations = obj.tryAddRotation( ...
                                operations, rotation);
                        end
                    end
                end
            else
                sourceMatrix = coordinates(source, :);
                sourceNormal = cross(sourceMatrix(1, :), sourceMatrix(2, :));
                sourceNormal = sourceNormal / norm(sourceNormal);
                augmentedSource = [sourceMatrix; sourceNormal];
                for first = candidates{1}
                    for second = candidates{2}
                        if first == second, continue; end
                        if abs(norm(coordinates(first, :) - ...
                                coordinates(second, :)) - ...
                                sourceDistances(1, 2)) > 2 * obj.tolerance
                            continue
                        end
                        targetMatrix = coordinates([first, second], :);
                        targetNormal = cross( ...
                            targetMatrix(1, :), targetMatrix(2, :));
                        if norm(targetNormal) <= 1e-12, continue; end
                        targetNormal = targetNormal / norm(targetNormal);
                        for normalSign = [-1, 1]
                            augmentedTarget = ...
                                [targetMatrix; normalSign * targetNormal];
                            rotation = ...
                                (augmentedSource \ augmentedTarget).';
                            operations = obj.tryAddRotation( ...
                                operations, rotation);
                        end
                    end
                end
            end
            inversion = ...
                kssolv.analysis.matgenlab.core.SymmOp.inversion();
            if obj.operationMapsMolecule(inversion) && ...
                    ~any(cellfun(@(candidate) all(abs( ...
                    candidate.affine_matrix - inversion.affine_matrix) <= ...
                    obj.matrix_tolerance, "all"), operations))
                operations{end + 1} = inversion;
            end
            symbol = obj.classifyOperations(operations);

            function distances = squareformLocal(points)
                numberPoints = size(points, 1);
                distances = zeros(numberPoints);
                for firstPoint = 1:numberPoints
                    for secondPoint = firstPoint + 1:numberPoints
                        value = norm(points(firstPoint, :) - ...
                            points(secondPoint, :));
                        distances(firstPoint, secondPoint) = value;
                        distances(secondPoint, firstPoint) = value;
                    end
                end
            end
        end

        function indices = independentSourceBasis(obj, coordinates, rankValue)
            eligible = find(vecnorm(coordinates, 2, 2) > obj.tolerance);
            if numel(eligible) < rankValue
                eligible = 1:size(coordinates, 1);
            end
            if rankValue == 3
                combinations = nchoosek(eligible, 3);
                for index = 1:size(combinations, 1)
                    matrix = coordinates(combinations(index, :), :);
                    if abs(det(matrix)) > max(1e-10, obj.tolerance^3)
                        indices = combinations(index, :);
                        return
                    end
                end
            else
                combinations = nchoosek(eligible, 2);
                for index = 1:size(combinations, 1)
                    matrix = coordinates(combinations(index, :), :);
                    if norm(cross(matrix(1, :), matrix(2, :))) > ...
                            max(1e-10, obj.tolerance^2)
                        indices = combinations(index, :);
                        return
                    end
                end
            end
            error("KSSOLV:Matgenlab:PointGroupAnalyzer:Basis", ...
                "Unable to construct a molecular coordinate basis.");
        end

        function operations = tryAddRotation(obj, operations, rotation)
            if any(~isfinite(rotation), "all") || ...
                    abs(det(rotation)) < 1e-10
                return
            end
            % A molecular geometry is normally rounded or slightly
            % distorted. Project the basis-derived map onto the nearest
            % orthogonal matrix, then let the coordinate tolerance decide
            % whether it is a genuine molecular automorphism.
            [left, ~, right] = svd(rotation);
            rotation = left * right.';
            rotation(abs(rotation) < 1e-12) = 0;
            operation = ...
                kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(rotation, zeros(1, 3));
            if ~obj.operationMapsMolecule(operation)
                return
            end
            if ~any(cellfun(@(candidate) ...
                    all(abs(candidate.affine_matrix - ...
                    operation.affine_matrix) <= ...
                    obj.matrix_tolerance, "all"), operations))
                operations{end + 1} = operation;
            end
        end

        function tf = operationMapsMolecule(obj, operation)
            tf = ~isempty(obj.siteMapping(operation));
        end

        function mapping = siteMapping(obj, operation)
            transformed = operation.operate(obj.centered_mol.cart_coords);
            numberSites = obj.centered_mol.num_sites;
            species = strings(1, numberSites);
            for index = 1:numberSites
                species(index) = ...
                    obj.centered_mol(index).species_string;
            end
            mapping = zeros(1, numberSites);
            used = false(1, numberSites);
            for siteIndex = 1:numberSites
                distances = vecnorm(obj.centered_mol.cart_coords - ...
                    transformed(siteIndex, :), 2, 2).';
                candidates = find(species == species(siteIndex) & ...
                    distances <= obj.tolerance & ~used);
                if isempty(candidates)
                    mapping = [];
                    return
                end
                [~, nearest] = min(distances(candidates));
                mapping(siteIndex) = candidates(nearest);
                used(mapping(siteIndex)) = true;
            end
        end

        function symbol = classifyOperations(obj, operations) %#ok<INUSL>
            determinants = cellfun(@(operation) ...
                det(operation.rotation_matrix), operations);
            proper = operations(determinants > 0);
            improper = operations(determinants < 0);
            numberProper = numel(proper);
            numberTotal = numel(operations);
            hasInversion = any(cellfun(@(operation) ...
                norm(operation.rotation_matrix + eye(3), "fro") < 1e-5, ...
                improper));
            mirrors = sum(cellfun(@(operation) ...
                abs(trace(operation.rotation_matrix) - 1) < 1e-5, ...
                improper));

            if numberProper == 1
                if hasInversion
                    symbol = "Ci";
                elseif mirrors > 0
                    symbol = "Cs";
                else
                    symbol = "C1";
                end
                return
            elseif numberProper == 12
                if numberTotal == 24
                    if hasInversion, symbol = "Th"; else, symbol = "Td"; end
                else
                    symbol = "T";
                end
                return
            elseif numberProper == 24
                if numberTotal == 48, symbol = "Oh"; else, symbol = "O"; end
                return
            elseif numberProper == 60
                if numberTotal == 120, symbol = "Ih"; else, symbol = "I"; end
                return
            end

            maximumOrder = 1;
            for index = 1:numel(proper)
                rotation = proper{index}.rotation_matrix;
                cosine = max(-1, min(1, (trace(rotation) - 1) / 2));
                angle = acos(cosine);
                if angle > 1e-8
                    maximumOrder = max(maximumOrder, ...
                        round(2 * pi / angle));
                end
            end
            isDihedral = numberProper >= 2 * maximumOrder;
            if isDihedral
                prefix = "D" + string(maximumOrder);
                if numberTotal == numberProper
                    symbol = prefix;
                elseif hasInversion || mirrors >= maximumOrder + 1
                    symbol = prefix + "h";
                else
                    symbol = prefix + "d";
                end
            else
                prefix = "C" + string(maximumOrder);
                if numberTotal == numberProper
                    symbol = prefix;
                elseif mirrors >= maximumOrder
                    symbol = prefix + "v";
                elseif hasInversion || mirrors > 0
                    symbol = prefix + "h";
                else
                    symbol = "S" + string(numberTotal);
                end
            end
        end
    end
end
