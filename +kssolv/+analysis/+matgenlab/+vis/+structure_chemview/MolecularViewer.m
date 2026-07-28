classdef MolecularViewer
    %MOLECULARVIEWER Lightweight native analogue of chemview's viewer.

    properties
        coordinates double
        topology (1, 1) struct
        representations cell = cell(1, 0)
    end

    methods
        function obj = MolecularViewer(coordinates, topology)
            obj.coordinates = double(coordinates);
            obj.topology = topology;
        end

        function obj = ball_and_sticks(obj, stick_radius)
            obj.representations{end + 1} = struct( ...
                "type", "ball_and_sticks", ...
                "options", struct("stick_radius", stick_radius));
        end

        function obj = add_representation(obj, kind, options)
            obj.representations{end + 1} = struct( ...
                "type", string(kind), "options", options);
        end

        function axesHandle = show(obj, axesHandle)
            if nargin < 2 || isempty(axesHandle)
                figureHandle = figure("Name", "MolecularViewer");
                axesHandle = axes("Parent", figureHandle);
            end
            hold(axesHandle, "on");
            for itemIndex = 1:numel(obj.representations)
                item = obj.representations{itemIndex};
                if item.type == "spheres"
                    point = item.options.coordinates;
                    color = double(item.options.colors(1));
                    rgb = [bitshift(color, -16), ...
                        bitand(bitshift(color, -8), 255), ...
                        bitand(color, 255)] ./ 255;
                    scatter3(axesHandle, point(1), point(2), point(3), ...
                        400 * item.options.radii(1), rgb, "filled", ...
                        "MarkerFaceAlpha", item.options.opacity);
                elseif item.type == "lines"
                    starts = item.options.startCoords;
                    ends = item.options.endCoords;
                    for lineIndex = 1:size(starts, 1)
                        plot3(axesHandle, ...
                            [starts(lineIndex, 1), ends(lineIndex, 1)], ...
                            [starts(lineIndex, 2), ends(lineIndex, 2)], ...
                            [starts(lineIndex, 3), ends(lineIndex, 3)], ...
                            "Color", [1, 1, 1]);
                    end
                end
            end
            axis(axesHandle, "equal");
            hold(axesHandle, "off");
        end
    end
end
