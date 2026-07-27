classdef BrillouinZonePlot < kssolv.services.workflow.module.visualization.chart.AbstractChartContainer
    %BRILLOUINZONE2DPLOT 用于绘制二维布里渊区的自定义图表类

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties
        result
        withPath (1, 1) logical = true
        % b1, b2, b3 are the defining reciprocal lattice vectors.
        b1 (1, :) double
        b2 (1, :) double
        b3 (1, 3) double = [0, 0, 0]
    end

    properties (Access = private, Transient, NonCopyable)
        % facesData includes faces and vertices for a Brillouin zone.
        facesData
    end

    methods (Access = protected)
        function update(this)
            % Update method for updating the chart when data or properties change.
            % Determine if we are effectively in 2D (if b3 is negligible)
            plot2D = norm(this.b3) < 1e-10;

            % Compute the Brillouin zone data and plot
            if plot2D
                this.b1 = this.b1(1, 1:2);
                this.b2 = this.b2(1, 1:2);
                this.facesData = kssolv.analysis.seekpath.brillouinzone.get2DBrillouinZone(this.b1, this.b2);
                if this.withPath
                    this.plot2DBZWithPath();
                else
                    this.plot2DBZ();
                end
            else
                this.facesData = kssolv.analysis.seekpath.brillouinzone.getBrillouinZone(this.b1, this.b2, this.b3);
                if this.withPath
                    this.plot3DBZWithPath();
                else
                    this.plot3DBZ();
                end
            end
        end
    end

    methods (Access = private)
        function plot2DBZ(this)
            %PLOT2DBZ Plot a 2D Brillouin zone given the computed facesData.
            faces = this.facesData.faces;
            vertices = this.facesData.vertices;

            ax = getAxes(this);
            hold(ax, 'on');
            axis(ax, 'equal');
            view(ax, 2);
            set(ax, 'Visible', 'off');
            xlabel(ax, 'X');
            ylabel(ax, 'Y');

            % Draw the faces
            for i = 1:length(faces)
                faceIndices = faces{i};
                patch(ax, 'Faces', faceIndices, 'Vertices', vertices, ...
                    'FaceColor', '#A1BEFF', 'EdgeColor', 'k', ...
                    'FaceAlpha', 0.8, 'LineWidth', 1);
            end

            % Plot the origin
            scatter3(ax, 0, 0, 0, 100, 'g', 'filled');

            % Determine suitable axes length
            axesLength = max(sqrt(sum(vertices.^2, 2))) * 1.5;

            % Draw coordinate axes
            maxLength = max([norm(this.b1), norm(this.b2)]);
            scaleFactor = axesLength / maxLength;

            b1Scaled = this.b1 * scaleFactor;
            b2Scaled = this.b2 * scaleFactor;

            quiver3(ax, 0, 0, 0, b1Scaled(1), b1Scaled(2), 0, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
            quiver3(ax, 0, 0, 0, b2Scaled(1), b2Scaled(2), 0, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);

            % Label axes
            text(ax, b1Scaled(1), b1Scaled(2), 0, 'b_1', 'FontSize', 12, 'FontWeight', 'bold');
            text(ax, b2Scaled(1), b2Scaled(2), 0, 'b_2', 'FontSize', 12, 'FontWeight', 'bold');

            hold(ax, 'off');

            % 保存 Axes
            this.axes = ax;
        end

        function plot2DBZWithPath(this)
            faces = this.facesData.faces;
            vertices = this.facesData.vertices;

            ax = getAxes(this);
            hold(ax, 'on');
            axis(ax, 'equal');
            view(ax, 2);
            set(ax, 'Visible', 'off');
            xlabel(ax, 'X');
            ylabel(ax, 'Y');

            % Draw the faces
            for i = 1:length(faces)
                faceIndices = faces{i};
                patch(ax, 'Faces', faceIndices, 'Vertices', vertices, ...
                    'FaceColor', '#A1BEFF', 'EdgeColor', 'k', ...
                    'FaceAlpha', 0.4, 'LineWidth', 1);
            end

            % Plot the origin
            scatter3(ax, 0, 0, 0, 100, 'g', 'filled');

            % Determine suitable axes length
            axesLength = max(sqrt(sum(vertices.^2, 2))) * 1.5;

            % Draw coordinate axes
            maxLength = max([norm(this.b1), norm(this.b2)]);
            scaleFactor = axesLength / maxLength;

            b1Scaled = this.b1 * scaleFactor;
            b2Scaled = this.b2 * scaleFactor;

            quiver3(ax, 0, 0, 0, b1Scaled(1), b1Scaled(2), 0, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
            quiver3(ax, 0, 0, 0, b2Scaled(1), b2Scaled(2), 0, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);

            % Label axes
            text(ax, b1Scaled(1), b1Scaled(2), 0, 'b_1', 'FontSize', 12, 'FontWeight', 'bold');
            text(ax, b2Scaled(1), b2Scaled(2), 0, 'b_2', 'FontSize', 12, 'FontWeight', 'bold');

            % Plot the path line segments between points using red color.
            % Also, plot the points themselves with a larger size and label them.

            % Initialize a Map to keep track of points that have already been plotted.
            % Keys are character strings (point names), and Values are logical (true/false).
            plottedPoints = containers.Map('KeyType', 'char', 'ValueType', 'logical');

            for i = 1:size(this.result.path, 1)
                % Get point names and their coordinates.
                p1 = this.result.path{i, 1};
                p2 = this.result.path{i, 2};
                coord1 = this.result.point_coords(p1) * this.result.reciprocal_primitive_lattice;
                coord2 = this.result.point_coords(p2) * this.result.reciprocal_primitive_lattice;

                % Plot a line segment between the two points.
                line(ax, [coord1(1), coord2(1)], [coord1(2), coord2(2)], 'Color', 'r', 'LineWidth', 2);

                % Plot and label the first point (p1) if it hasn't been plotted yet.
                if ~isKey(plottedPoints, p1)
                    scatter(ax, coord1(1), coord1(2), 70, 'r', 'filled');

                    % Prepare the label text, rendering 'Gamma' as the Greek letter.
                    if strcmpi(p1, 'Gamma')
                        label_p1 = '\Gamma';
                    else
                        label_p1 = p1;
                    end
                    text(ax, coord1(1), coord1(2), ['  ', label_p1], 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

                    % Mark this point as plotted by adding its key to the map.
                    plottedPoints(p1) = true;
                end

                % Plot and label the second point (p2) if it hasn't been plotted yet.
                if ~isKey(plottedPoints, p2)
                    scatter(ax, coord2(1), coord2(2), 70, 'r', 'filled');

                    % Prepare the label text, rendering 'Gamma' as the Greek letter.
                    if strcmpi(p2, 'Gamma')
                        label_p2 = '\Gamma';
                    else
                        label_p2 = p2;
                    end
                    text(ax, coord2(1), coord2(2), ['  ', label_p2], 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

                    % Mark this point as plotted by adding its key to the map.
                    plottedPoints(p2) = true;
                end
            end

            hold(ax, 'off');

            % 保存 Axes
            this.axes = ax;
        end

        function plot3DBZ(this)
            %PLOT3DBZ Plot a 3D Brillouin zone given the computed facesData.
            faces = this.facesData.faces;
            vertices = this.facesData.vertices;

            ax = getAxes(this);
            hold(ax, 'on');
            axis(ax, 'equal');
            view(ax, 3);
            set(ax, 'Visible', 'off');
            xlabel(ax, 'X');
            ylabel(ax, 'Y');
            zlabel(ax, 'Z');

            % Draw the faces
            for i = 1:length(faces)
                faceIndices = faces{i};
                patch(ax, 'Faces', faceIndices, 'Vertices', vertices, ...
                    'FaceColor', '#A1BEFF', 'EdgeColor', 'k', ...
                    'FaceAlpha', 0.8, 'LineWidth', 1);
            end

            % Plot the origin
            scatter3(ax, 0, 0, 0, 100, 'g', 'filled');

            % Determine suitable axes length
            axesLength = max(sqrt(sum(vertices.^2, 2))) * 1.5;

            % Draw coordinate axes
            maxLength = max([norm(this.b1), norm(this.b2), norm(this.b3)]);
            scaleFactor = axesLength / maxLength;

            b1Scaled = this.b1 * scaleFactor;
            b2Scaled = this.b2 * scaleFactor;
            b3Scaled = this.b3 * scaleFactor;

            quiver3(ax, 0, 0, 0, b1Scaled(1), b1Scaled(2), b1Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
            quiver3(ax, 0, 0, 0, b2Scaled(1), b2Scaled(2), b2Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
            quiver3(ax, 0, 0, 0, b3Scaled(1), b3Scaled(2), b3Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);

            % Label axes
            text(ax, b1Scaled(1), b1Scaled(2), b1Scaled(3), 'b_1', 'FontSize', 12, 'FontWeight', 'bold');
            text(ax, b2Scaled(1), b2Scaled(2), b2Scaled(3), 'b_2', 'FontSize', 12, 'FontWeight', 'bold');
            text(ax, b3Scaled(1), b3Scaled(2), b3Scaled(3), 'b_3', 'FontSize', 12, 'FontWeight', 'bold');

            hold(ax, 'off');

            % Rotate the view
            view(ax, 115, 10);

            % Allow interactive rotation
            rotate3d(ax, 'on');

            % 保存 Axes
            this.axes = ax;
        end

        function plot3DBZWithPath(this)
            % Compute the faces of the Brillouin zone
            faces = this.facesData.faces;
            vertices = this.facesData.vertices;

            % Plot the Brillouin zone
            ax = getAxes(this);
            hold(ax, 'on');
            axis(ax, 'equal');
            view(ax, 3);
            xlabel(ax, 'X');
            ylabel(ax, 'Y');
            zlabel(ax, 'Z');
            set(ax, 'Visible', 'off');

            % Draw the faces of the Brillouin zone with face color 'none'
            for i = 1:length(faces)
                faceIndices = faces{i}; % Indices of face vertices in the global vertices list
                % Use the global vertices list to draw the face
                patch(ax, 'Faces', faceIndices, 'Vertices', vertices, ...
                    'FaceColor', '#A1BEFF', 'EdgeColor', 'k', ...
                    'FaceAlpha', 0.4, 'LineWidth', 1);
            end

            % Plot the origin with larger size and more noticeable
            scatter3(ax, 0, 0, 0, 100, 'g', 'filled');

            % Determine suitable axes length
            axesLength = max(sqrt(sum(vertices.^2, 2))) * 1.5;

            % Draw coordinate axes
            maxLength = max([norm(this.b1), norm(this.b2), norm(this.b3)]);
            scaleFactor = axesLength / maxLength;

            b1Scaled = this.b1 * scaleFactor;
            b2Scaled = this.b2 * scaleFactor;
            b3Scaled = this.b3 * scaleFactor;

            quiver3(ax, 0, 0, 0, b1Scaled(1), b1Scaled(2), b1Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
            quiver3(ax, 0, 0, 0, b2Scaled(1), b2Scaled(2), b2Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);
            quiver3(ax, 0, 0, 0, b3Scaled(1), b3Scaled(2), b3Scaled(3), 'k', 'LineWidth', 2, 'MaxHeadSize', 0.2);

            % Label axes
            text(ax, b1Scaled(1), b1Scaled(2), b1Scaled(3), 'b_1', 'FontSize', 12, 'FontWeight', 'bold');
            text(ax, b2Scaled(1), b2Scaled(2), b2Scaled(3), 'b_2', 'FontSize', 12, 'FontWeight', 'bold');
            text(ax, b3Scaled(1), b3Scaled(2), b3Scaled(3), 'b_3', 'FontSize', 12, 'FontWeight', 'bold');

            % Plot the 3D path line segments between points using red color.
            % Also, plot the points themselves with a larger size and label them.

            % Initialize a Map to keep track of points that have already been plotted.
            plottedPoints = containers.Map('KeyType', 'char', 'ValueType', 'logical');

            for i = 1:size(this.result.path, 1)
                % Get point names and their 3D coordinates.
                p1 = this.result.path{i, 1};
                p2 = this.result.path{i, 2};

                coord1 = this.result.point_coords(p1) * this.result.reciprocal_primitive_lattice;
                coord2 = this.result.point_coords(p2) * this.result.reciprocal_primitive_lattice;

                % Plot a 3D line segment between the two points.
                line(ax, [coord1(1), coord2(1)], [coord1(2), coord2(2)], [coord1(3), coord2(3)], ...
                    'Color', 'r', 'LineWidth', 2);

                % Plot and label the first point (p1) if it hasn't been plotted yet.
                if ~isKey(plottedPoints, p1)
                    scatter3(ax, coord1(1), coord1(2), coord1(3), 70, 'r', 'filled');

                    % Prepare the label text, rendering 'Gamma' as the Greek letter.
                    if strcmpi(p1, 'Gamma')
                        label_p1 = '\Gamma';
                    else
                        label_p1 = p1;
                    end
                    text(ax, coord1(1), coord1(2), coord1(3), ['  ', label_p1], ...
                        'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

                    % Mark this point as plotted by adding its key to the map.
                    plottedPoints(p1) = true;
                end

                % Plot and label the second point (p2) if it hasn't been plotted yet.
                if ~isKey(plottedPoints, p2)
                    scatter3(ax, coord2(1), coord2(2), coord2(3), 70, 'r', 'filled');

                    % Prepare the label text, rendering 'Gamma' as the Greek letter.
                    if strcmpi(p2, 'Gamma')
                        label_p2 = '\Gamma';
                    else
                        label_p2 = p2;
                    end
                    text(ax, coord2(1), coord2(2), coord2(3), ['  ', label_p2], ...
                        'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k', 'Interpreter', 'tex');

                    % Mark this point as plotted by adding its key to the map.
                    plottedPoints(p2) = true;
                end
            end

            hold(ax, "off");

            % Set the view angle
            view(ax, 115, 10);
            if ~isempty(ancestor(ax, 'figure'))
                rotate3d(ax, 'on');
            end

            % 保存 Axes
            this.axes = ax;
        end
    end
end
