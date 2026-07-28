classdef PointGroup < ...
        kssolv.analysis.matgenlab.symmetry.groups.SymmetryGroup
    %POINTGROUP One of the 32 crystallographic point groups.

    properties (SetAccess = private)
        generators cell
        crystal_system (1,1) string
    end

    methods
        function obj = PointGroup(int_symbol)
            symbol = kssolv.analysis.matgenlab.internal. ...
                SymmetryDatabase.normalizePointGroup(int_symbol);
            records = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase.all();
            matches = arrayfun(@(item) ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase. ...
                normalizePointGroup(item.point_group) == symbol, records);
            if ~any(matches)
                error("KSSOLV:Matgenlab:PointGroup:Symbol", ...
                    "Invalid crystallographic point-group symbol '%s'.", ...
                    int_symbol);
            end
            record = records(find(matches, 1));
            spaceOperations = ...
                kssolv.analysis.matgenlab.internal.SymmetryDatabase. ...
                operations(record.hall_number);
            rotations = cell(1, 0);
            for index = 1:numel(spaceOperations)
                operation = ...
                    kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_rotation_and_translation( ...
                    spaceOperations{index}.rotation_matrix, zeros(1, 3));
                if ~any(cellfun(@(candidate) ...
                        kssolv.analysis.matgenlab.symmetry.groups. ...
                        SymmetryGroup.operationsEqual( ...
                        candidate, operation), rotations))
                    rotations{end + 1} = operation; %#ok<AGROW>
                end
            end
            obj.symbol = symbol;
            obj.symmetry_ops = rotations;
            obj.order = numel(rotations);
            obj.generators = cellfun(@(operation) ...
                operation.rotation_matrix, rotations, ...
                "UniformOutput", false);
            if record.number <= 2
                obj.crystal_system = "triclinic";
            elseif record.number <= 15
                obj.crystal_system = "monoclinic";
            elseif record.number <= 74
                obj.crystal_system = "orthorhombic";
            elseif record.number <= 142
                obj.crystal_system = "tetragonal";
            elseif record.number <= 167
                obj.crystal_system = "trigonal";
            elseif record.number <= 194
                obj.crystal_system = "hexagonal";
            else
                obj.crystal_system = "cubic";
            end
        end

        function orbit = get_orbit(obj, point, tolerance)
            if nargin < 3, tolerance = 1e-5; end
            point = reshape(double(point), 1, 3);
            orbit = zeros(0, 3);
            for index = 1:numel(obj.symmetry_ops)
                transformed = obj.symmetry_ops{index}.operate(point);
                if ~kssolv.analysis.matgenlab.symmetry.groups. ...
                        in_array_list(orbit, transformed, tolerance)
                    orbit(end + 1, :) = transformed; %#ok<AGROW>
                end
            end
        end
    end

    methods (Static)
        function obj = from_space_group(symbol)
            group = ...
                kssolv.analysis.matgenlab.symmetry.groups.SpaceGroup(symbol);
            obj = ...
                kssolv.analysis.matgenlab.symmetry.groups.PointGroup( ...
                group.point_group);
        end
    end
end
