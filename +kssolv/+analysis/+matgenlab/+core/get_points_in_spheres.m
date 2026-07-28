function neighbors = get_points_in_spheres(all_coords, center_coords, ...
        radius, pbc, numerical_tol, lattice, return_fcoords)
%GET_POINTS_IN_SPHERES Find Cartesian points and periodic images in spheres.
if nargin < 4 || isempty(pbc), pbc = true; end
if nargin < 5 || isempty(numerical_tol), numerical_tol = 1e-8; end
if nargin < 6, lattice = []; end
if nargin < 7, return_fcoords = false; end
all_coords = double(all_coords);
center_coords = double(center_coords);
if size(all_coords, 2) ~= 3 || size(center_coords, 2) ~= 3
    error("KSSOLV:Matgenlab:Lattice:CoordinateShape", ...
        "Coordinates must have shape N-by-3.");
end
if isscalar(pbc), pbc = repmat(logical(pbc), 1, 3); end
pbc = reshape(logical(pbc), 1, 3);
if (any(pbc) || return_fcoords) && isempty(lattice)
    error("KSSOLV:Matgenlab:Lattice:MissingLattice", ...
        "A lattice is required for periodic or fractional results.");
end
if ~isempty(lattice) && ...
        ~isa(lattice, "kssolv.analysis.matgenlab.core.Lattice")
    lattice = kssolv.analysis.matgenlab.core.Lattice(lattice);
end
imageRanges = {0, 0, 0};
if any(pbc)
    reciprocalLengths = lattice.reciprocal_lattice.lengths;
    maximum = ceil((radius + 0.15) .* reciprocalLengths / (2 * pi));
    for axis = 1:3
        if pbc(axis)
            imageRanges{axis} = -maximum(axis):maximum(axis);
        end
    end
end
neighbors = cell(size(center_coords, 1), 1);
for centerIndex = 1:size(center_coords, 1)
    values = cell(1, 0);
    for first = imageRanges{1}
        for second = imageRanges{2}
            for third = imageRanges{3}
                image = [first, second, third];
                if isempty(lattice)
                    translated = all_coords;
                else
                    translated = all_coords + image * lattice.matrix;
                end
                distances = vecnorm( ...
                    translated - center_coords(centerIndex, :), 2, 2);
                for pointIndex = ...
                        reshape(find(distances < radius + numerical_tol), 1, [])
                    coordinate = translated(pointIndex, :);
                    if return_fcoords
                        coordinate = round( ...
                            lattice.get_fractional_coords(coordinate), 10);
                    end
                    values{end + 1} = {coordinate, ...
                        distances(pointIndex), pointIndex, image}; %#ok<AGROW>
                end
            end
        end
    end
    neighbors{centerIndex} = values;
end
end
