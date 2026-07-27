function retData = getBrillouinZone(b1, b2, b3)
%GETBRILLOUINZONE Compute the faces of the Brillouin zone given three reciprocal lattice vectors.
%
% This function calculates the Brillouin zone based on the provided reciprocal lattice vectors
% (b1, b2, b3) and returns a structure containing the vertices and faces of the Brillouin zone.
%
% Input:
%   b1, b2, b3  - The three reciprocal lattice vectors (1x3 vectors), defining the reciprocal lattice.
%
% Output:
%   retData     - A structure with fields:
%       - vertices: Coordinates of the vertices of the Brillouin zone.
%       - faces: Faces of the Brillouin zone, defined by the indices of vertices that form each face.

retData = struct();

supercellSize = 3;  % Range of the supercell

% Generate G-vector points (reciprocal lattice points)
points3D = zeros((2 * supercellSize + 1)^3, 3);
centralIdx = [];
idx = 1;
for i = -supercellSize:supercellSize
    for j = -supercellSize:supercellSize
        for k = -supercellSize:supercellSize
            point = i*b1 + j*b2 + k*b3;
            points3D(idx, :) = point;
            if i == 0 && j == 0 && k == 0
                centralIdx = idx;
            end
            idx = idx + 1;
        end
    end
end

% Compute the Voronoi diagram
[V, C] = voronoin(points3D);

% Extract the central Voronoi cell (around the origin)
centralCell = C{centralIdx};
% Remove the point at infinity (index 1)
centralCell(centralCell == 1) = [];
centralVoronoi3D = V(centralCell, :);

% Compute the convex hull of these points to get the shape of the Brillouin zone
K = convhulln(centralVoronoi3D);

% Store all vertices (remove duplicates)
[uniqueVertices, ~, idxMap] = unique(centralVoronoi3D, 'rows', 'stable');
retData.vertices = uniqueVertices;

% Construct the list of triangles using new vertex indices
triangles = idxMap(K);

% Compute the normal vector for each triangle
numTriangles = size(triangles, 1);
normals = zeros(numTriangles, 3);
for i = 1:numTriangles
    simplex = triangles(i, :);
    p1 = uniqueVertices(simplex(1), :);
    p2 = uniqueVertices(simplex(2), :);
    p3 = uniqueVertices(simplex(3), :);
    v1 = p2 - p1;
    v2 = p3 - p1;
    normals(i, :) = cross(v1, v2);
    normals(i, :) = normals(i, :) / norm(normals(i, :));
end

% Build the mapping from edges to triangles
edges = containers.Map('KeyType', 'char', 'ValueType', 'any');
for simplexIdx = 1:numTriangles
    simplex = triangles(simplexIdx, :);
    edgesList = {[simplex(1), simplex(2)], [simplex(2), simplex(3)], [simplex(3), simplex(1)]};
    for e = 1:3
        edge = sort(edgesList{e});
        key = sprintf('%d-%d', edge(1), edge(2));
        if isKey(edges, key)
            edges(key) = [edges(key), simplexIdx];
        else
            edges(key) = simplexIdx;
        end
    end
end

% Initialize Union-Find structure for merging coplanar triangles
groups = 1:numTriangles;

% Define the find and union functions for Union-Find
    function root = findRoot(i)
        % Find the root of the set and perform path compression
        if groups(i) ~= i
            groups(i) = findRoot(groups(i));
        end
        root = groups(i);
    end

% Merge triangles that are coplanar and share an edge
keys = edges.keys;
for i = 1:length(keys)
    key = keys{i};
    trianglesList = edges(key);
    if length(trianglesList) ~= 2
        continue;
    end
    tr1 = trianglesList(1);
    tr2 = trianglesList(2);

    % Check if the normal vectors are parallel (i.e., triangles are coplanar)
    n1 = normals(tr1, :);
    n2 = normals(tr2, :);

    % Use the cross product of normal vectors to check coplanarity
    if norm(cross(n1, n2)) < 1e-4  % Adjust threshold for numerical stability
        % Union the groups
        root1 = findRoot(tr1);
        root2 = findRoot(tr2);
        if root1 ~= root2
            groups(root2) = root1;
        end
    end
end

% Get the group label for each triangle
groupLabels = zeros(numTriangles, 1);
for i = 1:numTriangles
    groupLabels(i) = findRoot(i);
end

% Collect and build the faces
uniqueGroups = unique(groupLabels);
numFaces = length(uniqueGroups);
faces = cell(numFaces, 1);

for idx = 1:numFaces
    group = uniqueGroups(idx);
    groupTriangles = find(groupLabels == group);
    % Collect all vertices in this group
    groupVertices = unique(triangles(groupTriangles, :));
    % Get the coordinates of these vertices
    groupPoints = uniqueVertices(groupVertices, :);
    % Compute the normal vector (using the first triangle)
    n = normals(groupTriangles(1), :);
    % Choose two orthogonal vectors to build the plane basis
    [v1, v2] = findPlaneBasis(n);
    % Project the points onto the plane
    projected = groupPoints * [v1', v2'];
    % Compute the 2D convex hull to get the ordered vertices of the face boundary
    K2 = convhull(projected(:, 1), projected(:, 2));
    orderedVertices = groupVertices(K2);
    % Store the vertex indices of the face (indices in the global vertices list)
    faces{idx} = orderedVertices';
end

retData.faces = faces;
end

function [v1, v2] = findPlaneBasis(n)
% Find two vectors orthogonal to the normal vector n to build the plane basis
% Using Gram-Schmidt orthogonalization

% Choose an arbitrary vector not parallel to n
if abs(n(1)) < abs(n(2))
    if abs(n(1)) < abs(n(3))
        v1 = [1, 0, 0];
    else
        v1 = [0, 0, 1];
    end
else
    if abs(n(2)) < abs(n(3))
        v1 = [0, 1, 0];
    else
        v1 = [0, 0, 1];
    end
end

% Orthogonalize
v1 = v1 - dot(v1, n) * n;
v1 = v1 / norm(v1);
v2 = cross(n, v1);
v2 = v2 / norm(v2);
end
