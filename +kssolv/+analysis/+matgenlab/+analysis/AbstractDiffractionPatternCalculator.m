classdef (Abstract) AbstractDiffractionPatternCalculator
    %ABSTRACTDIFFRACTIONPATTERNCALCULATOR Shared diffraction plotting API.

    properties (Constant)
        TWO_THETA_TOL = 1e-5
        SCALED_INTENSITY_TOL = 1e-3
    end

    methods (Abstract)
        pattern = get_pattern(obj, structure, scaled, two_theta_range)
    end

    methods
        function ax = get_plot(obj, structure, varargin)
            options = struct( ...
                "two_theta_range", [0, 90], ...
                "annotate_peaks", "compact", ...
                "ax", [], ...
                "with_labels", true, ...
                "fontsize", 16);
            options = parseOptions(options, varargin{:});
            if isempty(options.ax)
                figureHandle = figure();
                ax = axes(figureHandle);
            else
                ax = options.ax;
            end
            pattern = obj.get_pattern( ...
                structure, true, options.two_theta_range);
            holdState = ishold(ax);
            hold(ax, "on");
            maximum = max(pattern.y, [], "omitnan");
            for index = 1:numel(pattern.x)
                angle = pattern.x(index);
                if ~isempty(options.two_theta_range) && ...
                        (angle < options.two_theta_range(1) || ...
                        angle > options.two_theta_range(2))
                    continue
                end
                families = pattern.hkls{index};
                labels = strings(1, numel(families));
                for familyIndex = 1:numel(families)
                    hkl = families(familyIndex).hkl;
                    labels(familyIndex) = "(" + ...
                        strjoin(string(hkl), ", ") + ")";
                end
                label = strjoin(labels, ", ");
                plot(ax, [angle, angle], [0, pattern.y(index)], ...
                    "k-", "LineWidth", 1.5, "DisplayName", label);
                annotation = lower(string(options.annotate_peaks));
                if annotation == "full"
                    text(ax, angle, pattern.y(index), label, ...
                        "FontSize", options.fontsize);
                elseif annotation == "compact"
                    compact = labels;
                    for familyIndex = 1:numel(families)
                        hkl = families(familyIndex).hkl;
                        if all(abs(hkl) < 10)
                            compact(familyIndex) = strjoin(string(hkl), "");
                        end
                    end
                    vertical = maximum > 0 && ...
                        pattern.y(index) / maximum > 0.5;
                    if vertical
                        text(ax, angle, pattern.y(index), ...
                            strjoin(compact, ","), ...
                            "Rotation", 90, ...
                            "HorizontalAlignment", "right", ...
                            "VerticalAlignment", "top", ...
                            "FontSize", options.fontsize);
                    else
                        text(ax, angle, pattern.y(index), ...
                            strjoin(compact, ","), ...
                            "HorizontalAlignment", "center", ...
                            "VerticalAlignment", "bottom", ...
                            "FontSize", options.fontsize);
                    end
                end
            end
            if options.with_labels
                xlabel(ax, "2\theta (degrees)");
                ylabel(ax, "Intensities (scaled)");
            end
            if ~holdState, hold(ax, "off"); end
        end

        function show_plot(obj, structure, varargin)
            ax = obj.get_plot(structure, varargin{:});
            figure(ax.Parent);
        end

        function fig = plot_structures(obj, structures, varargin)
            options = struct("fontsize", 6);
            [options, remaining] = extractOption(options, varargin{:});
            if ~iscell(structures)
                structures = num2cell(structures);
            end
            fig = figure();
            layout = tiledlayout(fig, numel(structures), 1, ...
                "TileSpacing", "compact");
            for index = 1:numel(structures)
                ax = nexttile(layout);
                obj.get_plot(structures{index}, remaining{:}, ...
                    "fontsize", options.fontsize, ...
                    "ax", ax, ...
                    "with_labels", index == numel(structures));
                info = structures{index}.get_space_group_info();
                title(ax, sprintf("%s %s (%d)", ...
                    structures{index}.formula, info{1}, info{2}));
            end
        end
    end
end

function options = parseOptions(options, varargin)
for index = 1:2:numel(varargin)
    if index == numel(varargin)
        error("KSSOLV:Matgenlab:Diffraction:Arguments", ...
            "Name-value arguments must occur in pairs.");
    end
    name = char(lower(string(varargin{index})));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:Diffraction:Option", ...
            "Unknown option '%s'.", name);
    end
    options.(name) = varargin{index + 1};
end
end

function [options, remaining] = extractOption(options, varargin)
remaining = cell(1, 0);
index = 1;
while index <= numel(varargin)
    if index == numel(varargin)
        error("KSSOLV:Matgenlab:Diffraction:Arguments", ...
            "Name-value arguments must occur in pairs.");
    end
    name = char(lower(string(varargin{index})));
    if isfield(options, name)
        options.(name) = varargin{index + 1};
    else
        remaining(end + 1:end + 2) = varargin(index:index + 1);
    end
    index = index + 2;
end
end
