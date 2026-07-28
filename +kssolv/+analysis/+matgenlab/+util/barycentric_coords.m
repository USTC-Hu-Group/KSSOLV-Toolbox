function barycentric = barycentric_coords(coords, simplex)
%BARYCENTRIC_COORDS Convert Cartesian coordinates to simplex coordinates.
coords = double(coords);
simplex = double(simplex);
if isvector(coords), coords = reshape(coords, 1, []); end
if size(simplex, 1) ~= size(simplex, 2) + 1 || ...
        size(coords, 2) ~= size(simplex, 2)
    error("KSSOLV:Matgenlab:Coord:InvalidSimplex", ...
        "simplex must have d+1 rows and d columns.");
end
transform = simplex(1:end-1, :).' - simplex(end, :).';
allButOne = (transform \ (coords - simplex(end, :)).').';
barycentric = [allButOne, 1 - sum(allButOne, 2)];
end
