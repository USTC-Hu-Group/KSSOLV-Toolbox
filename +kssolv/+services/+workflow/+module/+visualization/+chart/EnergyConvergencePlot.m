classdef EnergyConvergencePlot < kssolv.services.workflow.module.visualization.chart.AbstractChartContainer
    %ENERGYCONVERGENCEPLOT 用于绘制能量收敛曲线图和误差曲线的自定义图表类

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        TotalEnergy % KSSOLV Etot 能量数据 (Hartree)
        SCFError % 误差数据
    end

    methods (Access = protected)
        function update(this)
            ax = getAxes(this);
            cla(ax);

            % 生成迭代步数，假设与 Energy 数组长度相同
            iterations = 1:length(this.TotalEnergy);

            % 设置 X 轴
            xlabel(ax, 'Iterations');
            title(ax, 'Energy Convergence and Error');
            grid(ax, 'on');

            % 左 Y 轴：能量
            yyaxis(ax, 'left');
            plot(ax, iterations, this.TotalEnergy, '-o', 'LineWidth', 2, 'Color', '#0b8fcb');

            % 右 Y 轴：误差（设置为对数坐标）
            yyaxis(ax, 'right');
            semilogy(ax, iterations, this.SCFError, '--s', 'LineWidth', 2, 'Color', '#f38a12');

            % 设置双 Y 轴标签
            hold(ax, "on");
            yyaxis(ax, 'left');
            ylabel(ax, 'Energy (Ha)');
            yyaxis(ax, 'right');
            ylabel(ax, 'Error');

            % 保存 Axes
            this.axes = ax;
        end
    end
end
