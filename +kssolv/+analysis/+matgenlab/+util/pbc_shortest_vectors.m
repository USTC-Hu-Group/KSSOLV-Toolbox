function [vectors, distancesSquared] = pbc_shortest_vectors( ...
        lattice, frac_coords1, frac_coords2, mask, return_d2)
%PBC_SHORTEST_VECTORS Shortest Cartesian displacement for every point pair.
% The result has size N1-by-N2-by-3 and points from frac_coords1 to
% frac_coords2, matching pymatgen.util.coord.pbc_shortest_vectors.
if nargin < 4, mask = []; end
if nargin < 5, return_d2 = false; end
coords1 = normalizeFracCoords(frac_coords1);
coords2 = normalizeFracCoords(frac_coords2);
n1 = size(coords1, 1);
n2 = size(coords2, 1);
if isempty(mask), mask = false(n1, n2); else, mask = logical(mask); end
if ~isequal(size(mask), [n1, n2])
    error("KSSOLV:Matgenlab:Coord:InvalidMask", ...
        "mask must have size N1-by-N2.");
end

if isa(lattice, "kssolv.analysis.matgenlab.core.Lattice")
    matrix = lattice.matrix;
    pbc = lattice.pbc;
    useLattice = true;
elseif isnumeric(lattice) && isequal(size(lattice), [3, 3])
    matrix = double(lattice);
    pbc = [true, true, true];
    useLattice = false;
elseif isstruct(lattice) && isfield(lattice, "matrix")
    matrix = double(lattice.matrix);
    if isfield(lattice, "pbc"), pbc = logical(lattice.pbc);
    else, pbc = [true, true, true];
    end
    useLattice = false;
else
    error("KSSOLV:Matgenlab:Coord:InvalidLattice", ...
        "lattice must be a matgenlab Lattice, a 3-by-3 matrix, or a struct.");
end

vectors = zeros(n1, n2, 3);
distancesSquared = zeros(n1, n2);
for idx1 = 1:n1
    for idx2 = 1:n2
        if mask(idx1, idx2)
            vectors(idx1, idx2, :) = 1e20;
            distancesSquared(idx1, idx2) = 1e20;
            continue
        end
        delta = coords2(idx2, :) - coords1(idx1, :);
        if useLattice
            [~, image] = lattice.get_distance_and_image( ...
                coords1(idx1, :), coords2(idx2, :));
        else
            image = shortestImage(delta, matrix, pbc);
        end
        vectors(idx1, idx2, :) = reshape((delta + image) * matrix, 1, 1, 3);
        distancesSquared(idx1, idx2) = sum(vectors(idx1, idx2, :).^2, 3);
    end
end
if ~return_d2 && nargout < 2
    clear distancesSquared
end
end

function coords = normalizeFracCoords(coords)
coords = double(coords);
if isempty(coords), coords = zeros(0, 3);
elseif isvector(coords) && numel(coords) == 3, coords = reshape(coords, 1, 3);
elseif ~ismatrix(coords) || size(coords, 2) ~= 3
    error("KSSOLV:Matgenlab:Coord:InvalidCoordinates", ...
        "Fractional coordinates must be N-by-3.");
end
end

function bestImage = shortestImage(delta, matrix, pbc)
initial = zeros(1, 3);
initial(pbc) = -round(delta(pbc));
upper = norm((delta + initial) * matrix);
reciprocalLengths = vecnorm(inv(matrix).', 2, 2).' * (2 * pi);
bounds = upper * reciprocalLengths / (2 * pi) + 1e-12;
ranges = cell(1, 3);
for dim = 1:3
    if pbc(dim)
        ranges{dim} = floor(-delta(dim) - bounds(dim)): ...
            ceil(-delta(dim) + bounds(dim));
    else
        ranges{dim} = 0;
    end
end
[i1, i2, i3] = ndgrid(ranges{1}, ranges{2}, ranges{3});
images = [i1(:), i2(:), i3(:)];
[~, loc] = min(sum(((delta + images) * matrix).^2, 2));
bestImage = images(loc, :);
end
