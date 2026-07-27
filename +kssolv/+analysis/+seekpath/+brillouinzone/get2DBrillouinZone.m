function retData = get2DBrillouinZone(b1, b2)
%GET2DBRILLOUINZONE Compute the vertices of the 2D Brillouin zone given two reciprocal lattice vectors.
%
% This function calculates the 2D Brillouin zone based on the provided reciprocal lattice vectors
% (b1, b2) and returns a structure containing the faces and vertices of the Brillouin zone polygon.
%
% Input:
%   b1, b2  - The two reciprocal lattice vectors (1x2 vectors), defining the 2D reciprocal lattice.
%
% Output:
%   retData - A structure with fields:
%       - faces: A cell array containing one element, a row vector of vertex indices forming the polygon.
%       - vertices: Coordinates of the vertices of the Brillouin zone polygon (Nx2 matrix).
%
% Reference:
%   https://gist.github.com/Ionizing/e6ff28f7abb13bf6c5e923a2c4d2f19e

% Construct the reciprocal lattice matrix B (2x2).
B = [b1; b2];

% Generate a [-1,0,1]^2 grid of points in integer coordinates.
[X, Y] = meshgrid(-1:1, -1:1);
gridPoints = [X(:), Y(:)];  % 9x2 matrix

% Map these grid points into reciprocal space using B.
% For a point (i,j), the reciprocal space coordinate is (i,j)*B = i*b1 + j*b2.
mappedPoints = gridPoints * B;

% Compute the Voronoi diagram for these points.
[V, C] = voronoin(mappedPoints);

% The center point (the origin of the reciprocal lattice) is at index 5 (1-based indexing).
centerPointIndex = 5;
centerCellIndices = C{centerPointIndex};

% Check if the Voronoi cell is bounded. If '1' appears, the cell is unbounded.
if any(centerCellIndices == 1)
    error('The Voronoi cell for the center point is unbounded. This should not happen for this lattice.');
end

% Extract the Brillouin zone vertices (the Voronoi cell around the center point).
bzVertices = V(centerCellIndices, :);

% Sort the vertices by their polar angle around the centroid to ensure a proper polygon order.
centroid = mean(bzVertices, 1);
angles = atan2(bzVertices(:,2) - centroid(2), bzVertices(:,1) - centroid(1));
[~, idx] = sort(angles);
bzVertices = bzVertices(idx, :);

% Create the faces array. If there are N vertices, the face is [1,2,3,...,N,1].
numVertices = size(bzVertices, 1);
faceIndices = [1:numVertices, 1];

% Store the results in a structure.
retData.faces = {faceIndices};
retData.vertices = bzVertices;
end
