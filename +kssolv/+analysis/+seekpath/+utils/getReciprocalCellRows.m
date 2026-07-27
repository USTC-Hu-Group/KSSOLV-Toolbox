function reciprocalSpaceCell = getReciprocalCellRows(realSpaceCell)
%GETRECIPROCALCELLROWS Compute reciprocal lattice vectors from real-space cell.
%
% Given the cell in real space (3x3 matrix, vectors as rows),
% this function returns the reciprocal-space cell where the G vectors are
% rows, satisfying the condition:
% realSpaceCell * reciprocalSpaceCell' = 2 * pi * eye(3),
% where eye(3) is the 3x3 identity matrix.
%
% Input:
%   realSpaceCell - A 3x3 matrix with lattice vectors as rows.
%
% Output:
%   reciprocalSpaceCell - A 3x3 matrix with reciprocal lattice vectors as rows.

reciprocalSpaceColumns = realSpaceCell \ (2 * pi * eye(3));
reciprocalSpaceCell = reciprocalSpaceColumns';
end
