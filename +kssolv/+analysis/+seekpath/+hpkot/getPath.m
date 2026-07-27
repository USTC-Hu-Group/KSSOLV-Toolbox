function result = getPath(structure, with_time_reversal, threshold, symprec, angle_tolerance)
%GETPATH Return the k-point path information for band structures given a crystal structure.
%
% This function computes the k-point path for the band structure calculation
% based on the provided crystal structure, and optionally includes time-reversal
% symmetry, lattice parameter thresholds, and symmetry precision.
%
% Usage:
%   result = hpkot.getPath(structure)
%   result = hpkot.getPath(structure, with_time_reversal, threshold, symprec, angle_tolerance)
%
% Input:
%   structure           - A cell array {cell, positions, numbers}, where:
%     - cell            - A 3x3 matrix representing lattice vectors (each row is a vector).
%     - positions       - An Nx3 matrix of atomic positions in fractional coordinates.
%     - numbers         - An Nx1 vector of atomic numbers.
%
% Optional Input:
%   with_time_reversal  - (default true) Whether to include time-reversal symmetry in the path calculation.
%   threshold           - (default 1e-7) Threshold for numerical precision in lattice parameter comparisons.
%   symprec             - (default 1e-5) Symmetry precision for spglib.
%   angle_tolerance     - (default -1.0) Angle tolerance for spglib (typically unused if set to -1).
%
% Output:
%   result              - A struct containing k-point path information and symmetry data.

arguments
    structure (1, 3) cell {mustBeNonempty}
    with_time_reversal (1, 1) logical = true
    threshold (1, 1) double = 1e-7
    symprec (1, 1) double = 1e-5
    angle_tolerance (1, 1) double = -1.0
end

% Extract structure components
lattice = structure{1};
position = structure{2};
types = structure{3};

% Symmetry analysis by SPGLIB
dataset = kssolv.analysis.spglib.Spglib.getDataset(lattice, position, types, size(types, 1), symprec, angle_tolerance);
if isempty(dataset)
    error('SymmetryDetectionError: Spglib could not detect the symmetry of the system.');
end

% Get standardized cell
conv_lattice = dataset.std_lattice;
conv_positions = dataset.std_positions;
conv_types = dataset.std_types;

% Get cell parameters
[a, b, c, cosalpha, cosbeta, cosgamma] = kssolv.analysis.seekpath.utils.getCellParameters(conv_lattice);
spacegroup_number = dataset.spacegroup_number;

% Transformation matrix and volume ratio
transf_matrix = dataset.transformation_matrix;
volume_conv_wrt_original = det(transf_matrix);

% Get space group properties
property = kssolv.analysis.seekpath.data.getSpacegroupData(spacegroup_number);
bravais_lattice = [property{1}, property{2}];
has_inv = property{3};

% Determine extended Bravais lattice
[ext_bravais, conv_lattice, conv_positions] = kssolv.analysis.seekpath.hpkot.internal.getExtendedBravaisLattice(bravais_lattice, spacegroup_number, a, b, c, cosalpha, cosbeta, cosgamma, threshold, conv_lattice, conv_positions);

% Get primitive cell
[prim_lattice, prim_pos, prim_types, ~] = kssolv.analysis.spglib.Spglib.findPrimitive(conv_lattice, conv_positions, conv_types, size(conv_types, 1), 1e-6);
[P, invP] = kssolv.analysis.seekpath.hpkot.internal.getPMatrix(bravais_lattice);

% Get path data
[kparam_def, points_def, path] = kssolv.analysis.seekpath.hpkot.internal.getPathData(ext_bravais);

% Evaluate k-parameters
kparam = struct();
for i = 1:size(kparam_def, 1)
    kparam_name = kparam_def{i, 1};
    kparam_expr = kparam_def{i, 2};
    kparam.(kparam_name) = kssolv.analysis.seekpath.hpkot.internal.evaluateExpression(kparam_expr, a, b, c, cosalpha, cosbeta, cosgamma, kparam);
end

% Extend kparam with additional expressions
kparam_extended = kssolv.analysis.seekpath.hpkot.internal.extendParameters(kparam);

% Compute k-point coordinates
points = containers.Map('KeyType', 'char', 'ValueType', 'any');
point_names = fieldnames(points_def);
for i = 1:length(point_names)
    pointname = point_names{i};
    coords_def = points_def.(pointname);
    coords = zeros(1, 3);
    for j = 1:3
        coords(j) = kssolv.analysis.seekpath.hpkot.internal.evaluateExpressionSimple(coords_def{j}, kparam_extended);
    end
    points(pointname) = coords;
end

% Augment path if necessary
augmented_path = false;
if ~has_inv && ~with_time_reversal
    augmented_path = true;

    % Convert 'points' to a containers.Map if it isn't one already
    if ~isa(points, 'containers.Map')
        point_names = fieldnames(points);
        point_coords = struct2cell(points);
        points = containers.Map(point_names, point_coords);
    end

    % Get the keys (point names) from the 'points' map
    point_names = keys(points);
    for i = 1:length(point_names)
        pointname = point_names{i};
        if strcmp(pointname, 'GAMMA')
            continue;
        end
        coords = points(pointname);
        new_pointname = [pointname, ''''];
        points(new_pointname) = -coords;
    end

    % Deep copy the old path to avoid modifying it while iterating
    old_path = path;
    for i = 1:size(old_path, 1)
        start_p = old_path{i, 1};
        end_p = old_path{i, 2};
        if strcmp(start_p, 'GAMMA')
            new_start_p = start_p;
        else
            new_start_p = [start_p, ''''];
        end
        if strcmp(end_p, 'GAMMA')
            new_end_p = end_p;
        else
            new_end_p = [end_p, ''''];
        end
        path(end + 1, :) = {new_start_p, new_end_p}; %#ok<AGROW>
    end
end

% Prepare result
result.point_coords = points;
result.path = path;
result.has_inversion_symmetry = has_inv;
result.augmented_path = augmented_path;
result.bravais_lattice = bravais_lattice;
result.bravais_lattice_extended = ext_bravais;
result.conv_lattice = conv_lattice;
result.conv_positions = conv_positions;
result.conv_types = conv_types;
result.primitive_lattice = prim_lattice;
result.primitive_positions = prim_pos;
result.primitive_types = prim_types;
result.reciprocal_primitive_lattice = kssolv.analysis.seekpath.utils.getReciprocalCellRows(prim_lattice);
result.inverse_primitive_transformation_matrix = invP;
result.primitive_transformation_matrix = P;
result.volume_original_wrt_conv = volume_conv_wrt_original;
result.volume_original_wrt_prim = volume_conv_wrt_original * det(invP);
result.spacegroup_number = dataset.spacegroup_number;
result.spacegroup_international = dataset.international_symbol;
result.rotation_matrix = dataset.std_rotation_matrix;
end

