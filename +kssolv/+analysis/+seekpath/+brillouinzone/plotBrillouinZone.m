function plotBrillouinZone(b1, b2, b3)
%PLOTBRILLOUINZONE Plot the Brillouin zone given reciprocal lattice vectors.
%
% This function computes and plots either a 2D or 3D Brillouin zone depending
% on the provided reciprocal lattice vectors.
%
% Inputs:
%   b1, b2, b3 - The reciprocal lattice vectors. If b3 is essentially zero,
%                the function will plot a 2D Brillouin zone. Otherwise,
%                it will plot a 3D Brillouin zone.
%
% This function calls `brillouinzone.getBrillouinZone` to compute the vertices and faces.

arguments
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
    plot2DBZ(facesData, b1, b2);
else
    facesData = kssolv.analysis.seekpath.brillouinzone.getBrillouinZone(b1, b2, b3);
    plot3DBZ(facesData, b1, b2, b3);
end
end

function plot2DBZ(facesData, b1 , b2)
%PLOT2DBZ Plot a 2D Brillouin zone given the computed facesData.
%
% facesData includes faces and vertices for a 2D Brillouin zone.
% b1 and b2 are the defining reciprocal lattice vectors.

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
        'FaceAlpha', 0.8, 'LineWidth', 1);
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

hold off;
end

function plot3DBZ(facesData, b1, b2, b3)
%PLOT3DBZ Plot a 3D Brillouin zone given the computed facesData.
%
% facesData includes faces and vertices for a 3D Brillouin zone.
% b1, b2, b3 are the defining reciprocal lattice vectors.

faces = facesData.faces;
vertices = facesData.vertices;

figure;
hold on;
axis equal;
view(3);
set(gca, 'Visible', 'off');
xlabel('X');
ylabel('Y');
zlabel('Z');

% Draw the faces
for i = 1:length(faces)
    faceIndices = faces{i};
    patch('Faces', faceIndices, 'Vertices', vertices, ...
        'FaceColor', '#A1BEFF', 'EdgeColor', 'k', ...
        'FaceAlpha', 0.8, 'LineWidth', 1);
end

% Plot the origin
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

hold off;

% Rotate the view
view(115, 10);

% Allow interactive rotation
rotate3d(gcf, 'on');
end
