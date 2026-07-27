function result = getPath2D(structure, symprec, angle_tolerance)
%GETPATH2D Generate the high-symmetry k-path for a 2D Brillouin zone.
%
% This function uses SPGLIB symmetry analysis on a provided 2D crystal structure to:
%   1. Standardize the cell.
%   2. Determine the 2D lattice symmetry type (hexagonal, square, rectangular, centered_rectangular, or oblique).
%   3. Based on the identified symmetry, generate a set of special (high-symmetry) k-points and labels.
%   4. Return these k-points in fractional coordinates along with associated path segments and labels.
%
% Input:
%   structure       - A 1x3 cell array {lattice, positions, types} describing the crystal structure:
%                     lattice:   3x3 matrix of lattice vectors
%                     position:  Nx3 matrix of atomic positions
%                     types:     Nx1 or Nx cell array of atom types (element identifiers)
%   symprec         - Symmetry precision for SPGLIB (default: 1e-5)
%   angle_tolerance - Angle tolerance for SPGLIB (default: -1.0)
%
% Output:
%   result - A structure containing:
%       .path            : A cell array of {start_label, end_label} pairs defining
%                          a path through special k-points.
%       .point_coords     : A structure where each field is a label of a special k-point,
%                           and the value is its fractional coordinate (z=0).
%       .labels           : A cell array of labels in the order they appear in the path.
%       .symmetry_type    : A string indicating the lattice type:
%                           'hexagonal', 'square', 'rectangular', 'centered_rectangular', or 'oblique'.
%       .conv_lattice     : The standardized lattice vectors as returned by SPGLIB.
%       .conv_positions   : The standardized atomic positions as returned by SPGLIB.
%       .conv_types       : The standardized atom types as returned by SPGLIB.
%
% Reference:
%   https://github.com/aiidalab/aiidalab-qe/blob/main/src/aiidalab_qe/plugins/bands/bands_workchain.py#L67

arguments
    structure (1, 3) cell {mustBeNonempty}
    symprec (1, 1) double = 1e-5
    angle_tolerance (1, 1) double = -1.0
end

% Extract components of the input structure
lattice = structure{1};
position = structure{2};
types = structure{3};

% Perform symmetry detection using SPGLIB
dataset = kssolv.analysis.spglib.Spglib.getDataset(lattice, position, types, size(types, 1), symprec, angle_tolerance);
if isempty(dataset)
    error('SymmetryDetectionError: SPGLIB could not detect the symmetry of the system.');
end

% Obtain the standardized cell from SPGLIB results
conv_lattice = dataset.std_lattice;
conv_positions = dataset.std_positions;
conv_types = dataset.std_types;

% Compute reciprocal lattice and restrict it to the first two dimensions
reciprocalLattice = kssolv.analysis.seekpath.utils.getReciprocalCellRows(lattice);
B = reciprocalLattice(1:2, 1:2);

% Determine the lattice type using the cell parameters
[a, b, ~, ~, ~, cosGamma] = kssolv.analysis.seekpath.utils.getCellParameters(lattice);
symmetryType = determineSymmetryType(a, b, cosGamma);

% Define known sets of special k-points for each lattice type.
% The chosen points and labels replicate the logic from the referenced Python code.
switch symmetryType
    case 'hexagonal'
        point_coords = [
            0.0,    0.0,   0.0;
            0.5,    0.0,   0.0;
            1/3,    1/3,   0.0;
            1.0,    0.0,   0.0
            ];
        labels = {'GAMMA', 'M', 'K', 'GAMMA'};

    case 'square'
        point_coords = [
            0.0,   0.0, 0.0;
            0.5,   0.0, 0.0;
            0.5,   0.5, 0.0;
            1.0,   0.0, 0.0
            ];
        labels = {'GAMMA', 'X', 'M', 'GAMMA'};

    case 'rectangular'
        point_coords = [
            0.0,   0.0, 0.0;
            0.5,   0.0, 0.0;
            0.5,   0.5, 0.0;
            0.0,   0.5, 0.0;
            1.0,   0.0, 0.0
            ];
        labels = {'GAMMA', 'X', 'S', 'Y', 'GAMMA'};

    case 'centered_rectangular'
        % For centered_rectangular lattices, we compute 'eta' and 'nu' as per the referenced logic.
        a1 = B(1,:);
        a2 = B(2,:);
        norm_a1 = norm(a1);
        norm_a2 = norm(a2);
        cos_gamma = dot(a1,a2)/(norm_a1*norm_a2);
        gamma = acos(cos_gamma);
        eta = (1 - (norm_a1/norm_a2)*cos_gamma)/(2*(sin(gamma))^2);
        nu = 0.5 - (eta*norm_a2*cos_gamma)/norm_a1;

        point_coords = [
            0.0,   0.0, 0.0;
            0.5,   0.0, 0.0;
            1-eta, nu,  0.0;
            0.5,   0.5, 0.0;
            eta,    1-nu, 0.0;
            1.0,   0.0, 0.0
            ];
        labels = {'GAMMA', 'X', 'H_1', 'C', 'H', 'GAMMA'};

    case 'oblique'
        % For oblique lattices, similar computations for 'eta' and 'nu' are done.
        a1 = B(1,:);
        a2 = B(2,:);
        norm_a1 = norm(a1);
        norm_a2 = norm(a2);
        cos_gamma = dot(a1,a2)/(norm_a1*norm_a2);
        gamma = acos(cos_gamma);
        eta = (1 - (norm_a1/norm_a2)*cos_gamma)/(2*(sin(gamma))^2);
        nu = 0.5 - (eta*norm_a2*cos_gamma)/norm_a1;

        point_coords = [
            0.0,    0.0, 0.0;
            0.5,    0.0, 0.0;
            1-eta,  nu,  0.0;
            0.5,    0.5, 0.0;
            eta,     1-nu, 0.0;
            0.0,    0.5, 0.0;
            1.0,    0.0, 0.0
            ];
        labels = {'GAMMA', 'X', 'H_1', 'C', 'H', 'Y', 'GAMMA'};

    otherwise
        error('Unknown symmetry type: %s', symmetryType);
end

% Construct the path from the labels
path = cell(length(labels)-1, 2);
for i = 1:length(labels)-1
    path{i, 1} = labels{i};
    path{i, 2} = labels{i+1};
end

% Store special k-points in a containers.Map
points = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(labels)
    key = labels{i};
    if ~isKey(points, key)
        points(key) = point_coords(i, :) * reciprocalLattice;
    end
end

% Package results
result.path = path;
result.point_coords = points;
result.labels = labels;
result.symmetry_type = symmetryType;
result.conv_lattice = conv_lattice;
result.conv_positions = conv_positions;
result.conv_types = conv_types;
end


function symmetryType = determineSymmetryType(a, b, cosGamma)
%DETERMINESYMMETRYTYPE Identify the 2D lattice symmetry type from lattice parameters.
%
% The function classifies the 2D lattice into one of the following types based on the
% lengths of the lattice vectors (a,b) and the cosine of the angle gamma between them:
%   - 'hexagonal' if a ≈ b and gamma ≈ 120° (cosGamma ≈ -0.5)
%   - 'square' if a ≈ b and gamma ≈ 90°   (cosGamma ≈ 0.0)
%   - 'rectangular' if a ≠ b and gamma ≈ 90°
%   - 'rectangular_centered' if a condition related to half the lattice vector projection holds
%   - 'oblique' otherwise (a ≠ b and gamma ≠ 90°)
%
% The logic follows a tolerance-based comparison to determine the closest category.
%
% Input:
%   a, b      - Lattice vector lengths
%   cosGamma  - Cosine of angle gamma between these vectors
%
% Output:
%   symmetryType - A string indicating the detected lattice type.
%
% Reference:
%   https://github.com/aiidalab/aiidalab-qe/blob/main/src/aiidalab_qe/plugins/bands/bands_workchain.py#L175

tolerance = 1e-3;
isClose = @(x,y) abs(x - y) <= tolerance;

% Hexagonal check: a~b and gamma~120° => cosGamma ~ -0.5
if isClose(a, b) && isClose(cosGamma, -0.5)
    symmetryType = 'hexagonal';
    return;
end

% Square check: a~b and gamma~90° => cosGamma ~ 0
if isClose(a, b) && isClose(cosGamma, 0.0)
    symmetryType = 'square';
    return;
end

% Rectangular: a≠b and gamma~90° => cosGamma ~0
if ~isClose(a, b) && isClose(cosGamma, 0.0)
    symmetryType = 'rectangular';
    return;
end

% Rectangular_centered: if b*cosGamma ~ a/2 within tolerance
if abs(b*cosGamma - (a/2)) <= tolerance
    symmetryType = 'rectangular_centered';
    return;
end

% Oblique: no other conditions met, gamma ≠90°, a≠b
if ~isClose(a, b) && ~isClose(cosGamma, 0.0)
    symmetryType = 'oblique';
    return;
end

error('Invalid symmetry type or no known condition matched.');
end
