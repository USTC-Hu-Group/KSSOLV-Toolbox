classdef BandStructurePlot < kssolv.services.workflow.module.visualization.chart.AbstractChartContainer
    %BANDSTRUCTUREPLOT 用于绘制能量收敛曲线图和误差曲线的自定义图表类

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties
        % An array containing the k-point coordinates and labels.
        % It is a matrix with each row consisting of 3 coordinates, the number
        % of points between each pair of k-points, and the k-point label.
        kPoints (:, 5) = {0.0000000000, 0.0000000000, 0.0000000000, 21, 'Γ'}

        % A matrix where each row corresponds to the energy levels
        % at the respective k-points.
        energyBands
    end

    properties (Dependent)
        % A property for setting and getting the y-axis limits of the plot.
        YLimits (1, 2) double

        % A property for setting and getting the mode of y-axis limits.
        % It can be either 'auto' or 'manual'.
        YLimitsMode {mustBeMember(YLimitsMode, {'auto', 'manual'})}
    end

    properties (Access = private, Transient, NonCopyable)
        segmentedKPoints

        segmentedEnergyBands

        % Stores the labels for the k-points, e.g., 'Γ', 'X', 'M'.
        kPointLabels (:, 1)

        % Stores the interpolated k-points along the path in reciprocal space.
        kPointPath (:, 3)

        % Stores the cumulative distance along the k-point path.
        kPointDistance (:, 1)

        % Stores the positions of k-point labels on the x-axis.
        kPointTicks (:, 1)
    end

    methods (Access = protected)
        function update(this)
            % Update method for updating the chart when data or properties change.

            numberOfPoints = cell2mat(this.kPoints(:, 4));
            numberOfPoints(end, :) = [];
            segmentBreaks = [0; find(numberOfPoints == 2)];
            this.segmentedKPoints = cell(length(segmentBreaks), 1);
            this.segmentedEnergyBands = {};

            for i = 1:length(segmentBreaks)-1
                this.segmentedKPoints{i, 1} = this.kPoints(segmentBreaks(i)+1:segmentBreaks(i+1), :);
            end
            this.segmentedKPoints{end, 1} = this.kPoints(segmentBreaks(end)+1:end, :);

            for i = 1:size(this.segmentedKPoints, 1)
                % Compute the k-point path and distances for each segment.
                this.kPointLabels{i, 1} = this.computeKPointLabels(i);
                this.kPointPath{i, 1} = this.computePathPoints(i);
                this.kPointDistance{i, 1} = this.computePathDistance(i);
                this.kPointTicks{i, 1} = this.computeXTicks(i);
                this.segmentedEnergyBands{i, 1} = this.computeEnergyBands(i);
            end

            % Get the axes for plotting.
            ax = getAxes(this);
            hold(ax, 'on');

            xTicks = [];
            xTickLabels = [];
            xLine = [];
            for index = 1:size(this.segmentedKPoints, 1)
                % Plot the energy bands.
                energyBands = this.segmentedEnergyBands{index, 1}; %#ok<*PROP>
                for i = 1:size(energyBands, 1)
                    plot(ax, this.kPointDistance{index, 1}, energyBands(i,:), ...
                        'b', 'LineWidth', 2);
                end

                if length(this.kPointTicks{index, 1}) > 1
                    xTicks = [xTicks; this.kPointTicks{index, 1}(1:end-1)]; %#ok<*AGROW>
                else
                    xTicks = [xTicks; this.kPointTicks{index, 1}(1)];
                end

                if length(this.kPointLabels{index, 1}) > 1
                    xTickLabels = [xTickLabels; this.kPointLabels{index, 1}(1:end-1)];
                else
                    xTickLabels = [xTickLabels; this.kPointLabels{index, 1}(1)];
                end

                if index == 1
                    if length(this.kPointTicks{index, 1}) > 1
                        xLine = [xLine; this.kPointTicks{index, 1}(2:end-1)];
                    end
                else
                    if length(this.kPointTicks{index, 1}) > 1
                        xLine = [xLine; this.kPointTicks{index, 1}(1:end-1)];
                    else
                        xLine = [xLine; this.kPointTicks{index, 1}(1)];
                    end
                end
            end

            xTicks = [xTicks; this.kPointTicks{index, 1}(end)];
            xTickLabels = [xTickLabels; this.kPointLabels{end, 1}(end)];
            xLine = [xLine; this.kPointTicks{end, 1}(end)];

            % Turn off the hold state to avoid overwriting plots.
            hold(ax, 'off');

            % Set plot style and labels.
            grid(ax, "on");
            box(ax, "on");
            axis(ax, 'square');

            set(ax, 'FontSize', 22, 'GridLineStyle', '--');
            xlim(ax, [this.kPointDistance{1, 1}(1) this.kPointDistance{end, 1}(end)]);
            xticks(ax, unique(xTicks));
            xticklabels(ax, xTickLabels);
            xline(ax, xLine, '--');
            xlabel(ax, 'Wave Vector', 'FontSize', 22);
            ylabel(ax, 'E-E_{fermi} (eV)', 'FontSize', 22);
            yline(ax, 0, '--');

            % 保存 Axes
            this.axes = ax;
        end
    end

    methods (Access = private)
        function kPointLabels = computeKPointLabels(this, segmentIndex)
            segmentedKPoints = this.segmentedKPoints{segmentIndex, 1};
            kPointLabels = string(char(segmentedKPoints{:, 5}));
            if segmentIndex > 1
                kPointLabels(1) = strcat(this.kPointLabels{segmentIndex-1, 1}(end), '|', kPointLabels(1));
            end
        end

        function kPointPath = computePathPoints(this, segmentIndex)
            % Compute the interpolated k-points along the path in reciprocal space.

            % Extract k-point labels.
            segmentedKPoints = this.segmentedKPoints{segmentIndex, 1};

            % Extract k-point coordinates and the number of points for interpolation.
            symmetricKPoints = cell2mat(segmentedKPoints(:, 1:3));
            numberOfPoints = cell2mat(segmentedKPoints(:, 4));

            % Calculate the total number of points along the path.
            totalNumberOfPoints = 1 + sum(numberOfPoints(1:end-1) - 1);
            kPointPath = zeros(totalNumberOfPoints, 3);

            % Initialize the first k-point.
            kPointPath(1, :) = symmetricKPoints(1, :);

            % Interpolate k-points between the specified symmetric points.
            currentIndex = 2;
            for i = 1:size(symmetricKPoints, 1) - 1
                % Number of points to interpolate (excluding the end point).
                numDeltaPoints = numberOfPoints(i) - 1;

                % Calculate the interpolated points.
                deltaKPoints = (symmetricKPoints(i + 1, :) - symmetricKPoints(i, :)) .* (1:numDeltaPoints)' / numDeltaPoints;

                % Add the interpolated points to the k-point path.
                kPointPath(currentIndex:currentIndex + numDeltaPoints - 1, :) = symmetricKPoints(i, :) + deltaKPoints;

                % Update the current index.
                currentIndex = currentIndex + numDeltaPoints;
            end
        end

        function kPointDistance = computePathDistance(this, segmentIndex)
            % Compute the cumulative distance along the k-point path.
            kPointPath = this.kPointPath{segmentIndex, 1}; %#ok<*PROPLC>
            nPoints = size(kPointPath, 1);
            kPointDistance = zeros(nPoints, 1);

            % Calculate the distance between consecutive k-points.
            for i = 2:nPoints
                distance = sqrt(sum((kPointPath(i, :) - kPointPath(i-1, :)) .^ 2));
                kPointDistance(i) = kPointDistance(i-1) + distance;
            end

            if segmentIndex > 1
                kPointDistance = kPointDistance + this.kPointDistance{segmentIndex-1, 1}(end);
            end
        end

        function kPointTicks = computeXTicks(this, segmentIndex)
            % Compute the positions of k-point labels on the x-axis.
            segmentedKPoints = this.segmentedKPoints{segmentIndex, 1};
            kPointDistance = this.kPointDistance{segmentIndex, 1};
            numberOfPoints = cell2mat(segmentedKPoints(:, 4));
            indices = 1 + cumsum([0; numberOfPoints(1:end-1) - 1]);
            kPointTicks = kPointDistance(indices);
        end

        function energyBands = computeEnergyBands(this, segmentIndex)
            segmentedKPoints = this.segmentedKPoints{segmentIndex, 1};
            numberOfPoints = cell2mat(segmentedKPoints(:, 4));
            totalNumberOfPoints = 1 + sum(numberOfPoints(1:end-1) - 1);

            if segmentIndex == 1
                energyBands = this.energyBands(:, 1:totalNumberOfPoints);
            else
                index = sum(cellfun(@(e)size(e, 2), this.segmentedEnergyBands));
                energyBands = this.energyBands(:, index+1:index+totalNumberOfPoints);
            end
        end
    end

    methods
        %% ylim method
        function varargout = ylim(this, varargin)
            % YLIM Method to get or set the y-axis limits of the plot.
            ax = getAxes(this);
            [varargout{1:nargout}] = ylim(ax, varargin{:});
        end

        %% set and get methods for YLimits and YLimitsMode
        function set.YLimits(this, ylm)
            % Setter method for YLimits.
            ax = getAxes(this);
            ax.YLim = ylm;
        end

        function ylm = get.YLimits(this)
            % Getter method for YLimits.
            ax = getAxes(this);
            ylm = ax.YLim;
        end

        function set.YLimitsMode(this, ylmmode)
            % Setter method for YLimitsMode.
            ax = getAxes(this);
            ax.YLimMode = ylmmode;
        end

        function ylm = get.YLimitsMode(this)
            % Getter method for YLimitsMode.
            ax = getAxes(this);
            ylm = ax.YLimMode;
        end
    end
end
