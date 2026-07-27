function realSpaceCell = getRealCellFromReciprocalRows(reciprocalSpaceRows)
%GETREALCELLFROMRECIPROCALROWS Compute real-space lattice vectors from reciprocal-space cell.
%
% Given the cell in reciprocal space (3x3 matrix, vectors as rows),
% this function returns the real-space cell where the R vectors are
% rows, satisfying the condition:
% realSpaceCell * reciprocalSpaceRows' = 2 * pi * eye(3),
% where eye(3) is the 3x3 identity matrix.
%
% Input:
%   reciprocalSpaceRows - A 3x3 matrix with reciprocal lattice vectors as rows.
%
% Output:
%   realSpaceCell - A 3x3 matrix with real-space lattice vectors as rows.

% Compute the real-space cell
realSpaceColumns = reciprocalSpaceRows \ (2 * pi * eye(3));
realSpaceCell = realSpaceColumns';
end
