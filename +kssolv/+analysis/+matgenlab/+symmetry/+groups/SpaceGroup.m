classdef SpaceGroup < ...
        kssolv.analysis.matgenlab.symmetry.groups.SymmetryGroup
    %SPACEGROUP Crystallographic space group backed by spglib's database.

    properties (SetAccess = private)
        int_number (1,1) double
        full_symbol (1,1) string
        point_group (1,1) string
        hexagonal (1,1) logical = true
        hall_number (1,1) double
        generators cell
    end

    properties (Dependent, SetAccess = private)
        crystal_system
    end

    methods
        function obj = SpaceGroup(int_symbol, hexagonal)
            if nargin < 2, hexagonal = true; end
            if ~isscalar(hexagonal) || ~islogical(hexagonal)
                error("KSSOLV:Matgenlab:SpaceGroup:Hexagonal", ...
                    "hexagonal must be a logical scalar.");
            end
            record = kssolv.analysis.matgenlab.internal. ...
                SymmetryDatabase.resolve(int_symbol, hexagonal);
            obj.symbol = record.short;
            obj.full_symbol = replace(record.full, " ", "");
            obj.point_group = record.point_group;
            obj.int_number = record.number;
            obj.hall_number = record.hall_number;
            obj.hexagonal = ~strcmpi(record.choice, "R");
            obj.symmetry_ops = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase. ...
                operations(record.hall_number);
            obj.order = numel(obj.symmetry_ops);
            generatorOperations = ...
                kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup. ...
                minimalGenerators(obj.symmetry_ops);
            obj.generators = cellfun(@(operation) ...
                operation.affine_matrix, generatorOperations, ...
                "UniformOutput", false);
        end

        function value = get.crystal_system(obj)
            number = obj.int_number;
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

        function orbit = get_orbit(obj, point, tolerance)
            if nargin < 3, tolerance = 1e-5; end
            point = reshape(double(point), 1, 3);
            orbit = zeros(0, 3);
            for index = 1:numel(obj.symmetry_ops)
                transformed = mod(round( ...
                    obj.symmetry_ops{index}.operate(point), 10), 1);
                if ~kssolv.analysis.matgenlab.symmetry.groups. ...
                        in_array_list(orbit, transformed, tolerance)
                    orbit(end + 1, :) = transformed; %#ok<AGROW>
                end
            end
        end

        function [orbit, generators] = ...
                get_orbit_and_generators(obj, point, tolerance)
            if nargin < 3, tolerance = 1e-5; end
            point = reshape(double(point), 1, 3);
            orbit = point;
            generators = { ...
                kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(eye(3), zeros(1, 3))};
            for index = 1:numel(obj.symmetry_ops)
                transformed = mod(round( ...
                    obj.symmetry_ops{index}.operate(point), 10), 1);
                if ~kssolv.analysis.matgenlab.symmetry.groups. ...
                        in_array_list(orbit, transformed, tolerance)
                    orbit(end + 1, :) = transformed; %#ok<AGROW>
                    generators{end + 1} = obj.symmetry_ops{index}; %#ok<AGROW>
                end
            end
        end

        function tf = is_compatible(obj, lattice, tolerance, angleTolerance)
            if nargin < 3, tolerance = 1e-5; end
            if nargin < 4, angleTolerance = 5; end
            lengths = lattice.lengths;
            angles = lattice.angles;
            equalLength = @(a, b) abs(a - b) < tolerance;
            equalAngle = @(a, b) abs(a - b) < angleTolerance;
            switch obj.crystal_system
                case "cubic"
                    tf = all(abs(lengths - lengths(1)) < tolerance) && ...
                        all(abs(angles - 90) < angleTolerance);
                case "hexagonal"
                    tf = equalLength(lengths(1), lengths(2)) && ...
                        equalAngle(angles(1), 90) && ...
                        equalAngle(angles(2), 90) && ...
                        equalAngle(angles(3), 120);
                case "trigonal"
                    if obj.hexagonal
                        tf = equalLength(lengths(1), lengths(2)) && ...
                            equalAngle(angles(1), 90) && ...
                            equalAngle(angles(2), 90) && ...
                            equalAngle(angles(3), 120);
                    else
                        tf = all(abs(lengths - lengths(1)) < tolerance) && ...
                            all(abs(angles - angles(1)) < angleTolerance);
                    end
                case "tetragonal"
                    tf = equalLength(lengths(1), lengths(2)) && ...
                        all(abs(angles - 90) < angleTolerance);
                case "orthorhombic"
                    tf = all(abs(angles - 90) < angleTolerance);
                case "monoclinic"
                    tf = equalAngle(angles(1), 90) && ...
                        equalAngle(angles(3), 90);
                otherwise
                    tf = true;
            end
        end

        function tf = is_subgroup(obj, supergroup)
            if ~isa(supergroup, ...
                    "kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup")
                tf = false;
                return
            end
            if obj.int_number == supergroup.int_number
                tf = true;
                return
            end
            ownRotations = obj.uniqueRotations();
            superRotations = supergroup.uniqueRotations();
            tf = all(cellfun(@(rotation) any(cellfun(@(candidate) ...
                all(abs(rotation - candidate) <= 1e-5, "all"), ...
                superRotations)), ownRotations));
            if ~tf, return; end
            % Equal point parts with the same Bravais centering are not
            % enough to establish a space-group chain (e.g. 229 vs 230).
            % Different centerings can represent a klassengleiche chain,
            % as in Fm-3m < Pm-3m.
            ownCentering = extractBetween(obj.symbol, 1, 1);
            superCentering = extractBetween(supergroup.symbol, 1, 1);
            if numel(ownRotations) == numel(superRotations) && ...
                    ownCentering == superCentering
                tf = false;
            end
        end

        function value = char(obj)
            value = sprintf( ...
                "Spacegroup %s with international number %d and order %d", ...
                obj.symbol, obj.int_number, obj.order);
        end

        function value = string(obj), value = string(char(obj)); end
    end

    methods (Static)
        function obj = from_int_number(number, hexagonal)
            if nargin < 2, hexagonal = true; end
            record = kssolv.analysis.matgenlab.internal. ...
                SymmetryDatabase.fromNumber(number, hexagonal);
            symbol = record.short;
            if record.choice ~= ""
                symbol = symbol + ":" + record.choice;
            end
            obj = ...
                kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup( ...
                symbol, hexagonal);
        end

        function settings = get_settings(int_symbol)
            record = kssolv.analysis.matgenlab.internal. ...
                SymmetryDatabase.resolve(int_symbol, true);
            records = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase.all();
            records = records([records.number] == record.number);
            settings = strings(1, numel(records));
            for index = 1:numel(records)
                settings(index) = records(index).short;
                choice = records(index).choice;
                if startsWith(choice, "1") || startsWith(choice, "2")
                    settings(index) = settings(index) + ":" + ...
                        extractBefore(choice, 2);
                end
            end
            % pymatgen includes the unqualified spelling alongside every
            % explicitly numbered origin choice.
            bare = strings(1, numel(records));
            for index = 1:numel(records)
                bare(index) = records(index).short;
            end
            settings = unique([settings, bare]);
        end
    end

    methods (Static, Access = private)
        function generators = minimalGenerators(operations)
            identity = ...
                kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(eye(3), zeros(1, 3));
            generators = {identity};
            closure = {identity};
            for index = 1:numel(operations)
                if any(cellfun(@(candidate) ...
                        kssolv.analysis.matgenlab.symmetry.groups. ...
                        SymmetryGroup.operationsEqual( ...
                        candidate, operations{index}), closure))
                    continue
                end
                generators{end + 1} = operations{index}; %#ok<AGROW>
                closure = ...
                    kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup. ...
                    closure(generators, numel(operations));
                if numel(closure) == numel(operations), break; end
            end
        end

        function values = closure(generators, maximum)
            values = generators;
            changed = true;
            while changed && numel(values) < maximum
                changed = false;
                current = values;
                for first = 1:numel(current)
                    for second = 1:numel(generators)
                        candidate = current{first} * generators{second};
                        matrix = candidate.affine_matrix;
                        matrix(1:3, 4) = mod(matrix(1:3, 4), 1);
                        candidate = ...
                            kssolv.analysis.matgenlab.core.SymmOp(matrix);
                        if ~any(cellfun(@(item) ...
                                kssolv.analysis.matgenlab.symmetry.groups. ...
                                SymmetryGroup.operationsEqual( ...
                                item, candidate), values))
                            values{end + 1} = candidate; %#ok<AGROW>
                            changed = true;
                        end
                    end
                end
            end
        end
    end

    methods (Access = private)
        function rotations = uniqueRotations(obj)
            rotations = cell(1, 0);
            for index = 1:numel(obj.symmetry_ops)
                rotation = obj.symmetry_ops{index}.rotation_matrix;
                if ~any(cellfun(@(candidate) ...
                        all(abs(rotation - candidate) <= 1e-5, "all"), ...
                        rotations))
                    rotations{end + 1} = rotation; %#ok<AGROW>
                end
            end
        end
    end
end
