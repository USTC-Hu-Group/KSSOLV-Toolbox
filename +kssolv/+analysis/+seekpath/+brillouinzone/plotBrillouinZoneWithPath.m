function plotBrillouinZoneWithPath(result, b1, b2, b3)
%PLOTBRILLOUINZONEWITHPATH Plot the Brillouin zone along with a specified k-path.
%
% This function first computes the Brillouin zone defined by the reciprocal lattice vectors b1, b2, and b3.
% If b3 is negligible (essentially zero), the zone is considered 2D and will be plotted in two dimensions.
% Otherwise, the zone is considered 3D and will be plotted in three dimensions.
%
% After computing the Brillouin zone, the function plots it, including its vertices and faces.
% It then overlays the k-path segments defined in 'result', drawing line segments between the special
% k-points. These k-points are provided in fractional coordinates and retrieved from 'result.point_coords'.
% Labels corresponding to these points are also placed in the plot.
%
% Inputs:
%   result - A structure containing:
%            .path         : nx2 cell array specifying start and end labels of line segments
%            .point_coords : A structure mapping each label to its fractional coordinates
%   b1, b2, b3 - The three reciprocal lattice vectors (each a 1x3 vector) that define the reciprocal lattice.
%                 If b3 is essentially zero, the zone will be treated as 2D.
%
% This function calls `brillouinzone.getBrillouinZone` to compute the vertices and faces of the Brillouin zone.

arguments
    result
    b1 (1, :) double {mustBeNonempty}
    b2 (1, :) double {mustBeNonempty}
    b3 (1, 3) double = [0, 0, 0]
end

% Determine if we are effectively in 2D (if b3 is negligible)
plot2D = norm(b3) < 1e-10;

% Compute the Brillouin zone data and plot
if plot2D
    b1 = b1(1, 1:2);
    b2 = b2(1, 1:2);
    facesData = kssolv.analysis.seekpath.brillouinzone.get2DBrillouinZone(b1, b2);
    plot2DBZWithPath(facesData, result, b1, b2);
else
    facesData = kssolv.analysis.seekpath.brillouinzone.getBrillouinZone(b1, b2, b3);
    plot3DBZWithPath(facesData, result, b1, b2, b3);
end
end

function plot2DBZWithPath(facesData, result, b1, b2)
faces = facesData.faces;
vertices = facesData.vertices;

figure;
hold on;
axis equal;
view(2);
set(gca, 'Visible', 'off');
xlabel('X');
ylabel('Y');

% Draw the faces
for i = 1:length(faces)
    faceIndices = faces{i};
    patch('Faces', faceIndices, 'Vertices', vertices, ...
        'FaceColor', '#A1BEFF', 'EdgeColor', 'k', ...
        'FaceAlpha', 0.4, 'LineWidth', 1);
end

% Plot the origin
scatter3(0, 0, 0, 100, 'g', 'filled');

% Determine suitable axes length
axesLength = max(sqrt(sum(vertices.^2, 2))) * 1.5;

% Draw coordinate axes
maxLength = max([norm(b1), norm(b2)]);
scaleFactor = axesLength / maxLength;

b1Scaled = b1 * scaleFactor;
b2Scaled = b2 * scaleFactor;

quiver3(0, 0, 0, b1Scaled(1), b1Scaled(2), 0, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
quiver3(0, 0, 0, b2Scaled(1), b2Scaled(2), 0, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);

% Label axes
text(b1Scaled(1), b1Scaled(2), 0, 'b_1', 'FontSize', 12, 'FontWeight', 'bold');
text(b2Scaled(1), b2Scaled(2), 0, 'b_2', 'FontSize', 12, 'FontWeight', 'bold');

% Plot the path line segments between points using red color.
% Also, plot the points themselves with a larger size and label them.

% Initialize a Map to keep track of points that have already been plotted.
% Keys are character strings (point names), and Values are logical (true/false).
plottedPoints = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for i = 1:size(result.path, 1)
    % Get point names and their coordinates.
    p1 = result.path{i, 1};
    p2 = result.path{i, 2};
    coord1 = result.point_coords(p1);
    coord2 = result.point_coords(p2);

    % Plot a line segment between the two points.
    line([coord1(1), coord2(1)], [coord1(2), coord2(2)], 'Color', 'r', 'LineWidth', 2);

    % Plot and label the first point (p1) if it hasn't been plotted yet.
    if ~isKey(plottedPoints, p1)
        scatter(coord1(1), coord1(2), 70, 'r', 'filled');

        % Prepare the label text, rendering 'Gamma' as the Greek letter.
        if strcmpi(p1, 'Gamma')
            label_p1 = '\Gamma';
        else
            label_p1 = p1;
        end
        text(coord1(1), coord1(2), ['  ', label_p1], 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

        % Mark this point as plotted by adding its key to the map.
        plottedPoints(p1) = true;
    end

    % Plot and label the second point (p2) if it hasn't been plotted yet.
    if ~isKey(plottedPoints, p2)
        scatter(coord2(1), coord2(2), 70, 'r', 'filled');

        % Prepare the label text, rendering 'Gamma' as the Greek letter.
        if strcmpi(p2, 'Gamma')
            label_p2 = '\Gamma';
        else
            label_p2 = p2;
        end
        text(coord2(1), coord2(2), ['  ', label_p2], 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

        % Mark this point as plotted by adding its key to the map.
        plottedPoints(p2) = true;
    end
end

hold off;
end

function plot3DBZWithPath(facesData, result, b1, b2, b3)
% Compute the faces of the Brillouin zone
faces = facesData.faces;
vertices = facesData.vertices;

% Plot the Brillouin zone
figure;
hold on;
axis equal;
view(3);
xlabel('X');
ylabel('Y');
zlabel('Z');
set(gca, 'Visible', 'off');

% Draw the faces of the Brillouin zone with face color 'none'
for i = 1:length(faces)
    faceIndices = faces{i}; % Indices of face vertices in the global vertices list
    % Use the global vertices list to draw the face
    patch('Faces', faceIndices, 'Vertices', vertices, ...
        'FaceColor', '#A1BEFF', 'EdgeColor', 'k', ...
        'FaceAlpha', 0.4, 'LineWidth', 1);
end

% Plot the origin with larger size and more noticeable
scatter3(0, 0, 0, 100, 'g', 'filled');

% Determine suitable axes length
axesLength = max(sqrt(sum(vertices.^2, 2))) * 1.5;

% Draw coordinate axes
maxLength = max([norm(b1), norm(b2), norm(b3)]);
scaleFactor = axesLength / maxLength;

b1Scaled = b1 * scaleFactor;
b2Scaled = b2 * scaleFactor;
b3Scaled = b3 * scaleFactor;

quiver3(0, 0, 0, b1Scaled(1), b1Scaled(2), b1Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
quiver3(0, 0, 0, b2Scaled(1), b2Scaled(2), b2Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
quiver3(0, 0, 0, b3Scaled(1), b3Scaled(2), b3Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);

% Label axes
text(b1Scaled(1), b1Scaled(2), b1Scaled(3), 'b_1', 'FontSize', 12, 'FontWeight', 'bold');
text(b2Scaled(1), b2Scaled(2), b2Scaled(3), 'b_2', 'FontSize', 12, 'FontWeight', 'bold');
text(b3Scaled(1), b3Scaled(2), b3Scaled(3), 'b_3', 'FontSize', 12, 'FontWeight', 'bold');

% Plot the 3D path line segments between points using red color.
% Also, plot the points themselves with a larger size and label them.

% Initialize a Map to keep track of points that have already been plotted.
plottedPoints = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for i = 1:size(result.path, 1)
    % Get point names and their 3D coordinates.
    p1 = result.path{i, 1};
    p2 = result.path{i, 2};
    coord1 = result.point_coords(p1) * result.reciprocal_primitive_lattice;
    coord2 = result.point_coords(p2) * result.reciprocal_primitive_lattice;

    % Plot a 3D line segment between the two points.
    line([coord1(1), coord2(1)], [coord1(2), coord2(2)], [coord1(3), coord2(3)], ...
         'Color', 'r', 'LineWidth', 2);

    % Plot and label the first point (p1) if it hasn't been plotted yet.
    if ~isKey(plottedPoints, p1)
        scatter3(coord1(1), coord1(2), coord1(3), 70, 'r', 'filled');

        % Prepare the label text, rendering 'Gamma' as the Greek letter.
        if strcmpi(p1, 'Gamma')
            label_p1 = '\Gamma';
        else
            label_p1 = p1;
        end
        text(coord1(1), coord1(2), coord1(3), ['  ', label_p1], ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

        % Mark this point as plotted by adding its key to the map.
        plottedPoints(p1) = true;
    end

    % Plot and label the second point (p2) if it hasn't been plotted yet.
    if ~isKey(plottedPoints, p2)
        scatter3(coord2(1), coord2(2), coord2(3), 70, 'r', 'filled');

        % Prepare the label text, rendering 'Gamma' as the Greek letter.
        if strcmpi(p2, 'Gamma')
            label_p2 = '\Gamma';
        else
            label_p2 = p2;
        end
        text(coord2(1), coord2(2), coord2(3), ['  ', label_p2], ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

        % Mark this point as plotted by adding its key to the map.
        plottedPoints(p2) = true;
    end
end

hold off;

% Set the view angle
view(115, 10);
rotate3d(gcf, 'on');
end
