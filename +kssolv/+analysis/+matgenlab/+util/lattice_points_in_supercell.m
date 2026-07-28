function points = lattice_points_in_supercell(supercell_matrix)
%LATTICE_POINTS_IN_SUPERCELL Original-lattice points inside a supercell.
matrix = double(supercell_matrix);
if ~isequal(size(matrix), [3, 3]) || abs(det(matrix)) < eps
    error("KSSOLV:Matgenlab:Coord:InvalidSupercell", ...
        "supercell_matrix must be a nonsingular 3-by-3 matrix.");
end
diagonals = [0 0 0; 0 0 1; 0 1 0; 0 1 1; ...
             1 0 0; 1 0 1; 1 1 0; 1 1 1];
corners = diagonals * matrix;
mins = min(corners, [], 1);
maxes = max(corners, [], 1) + 1;
ar = mins(1):(maxes(1) - 1);
br = mins(2):(maxes(2) - 1);
cr = mins(3):(maxes(3) - 1);
% Arrange grids so C/NumPy's last dimension varies fastest.
[cg, bg, ag] = ndgrid(cr, br, ar);
allPoints = [ag(:), bg(:), cg(:)];
fracPoints = allPoints / matrix;
keep = all(fracPoints < 1 - 1e-10, 2) & ...
    all(fracPoints >= -1e-10, 2);
points = fracPoints(keep, :);
expected = round(abs(det(matrix)));
if size(points, 1) ~= expected
    error("KSSOLV:Matgenlab:Coord:SupercellVectorMismatch", ...
        "The number of transformed vectors mismatch.");
end
end
