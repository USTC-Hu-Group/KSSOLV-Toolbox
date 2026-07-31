classdef VolumeSceneSerializer
    %VOLUMESCENESERIALIZER Preserve VolumeSceneSpec array shapes for uihtml.

    methods (Static)
        function value = transportScene(scene)
            arguments
                scene (1,1) struct
            end
            value = scene;

            % jsonencode maps a scalar MATLAB struct to a JSON object. The
            % schema requires channels to remain an array even when the file
            % contains only one scalar field.
            value.channels = reshape(num2cell(scene.channels), 1, []);

            if isempty(scene.warnings)
                value.warnings = cell(1, 0);
            elseif isstring(scene.warnings) || ischar(scene.warnings)
                messages = reshape(string(scene.warnings), 1, []);
                warnings = cell(1, numel(messages));
                for index = 1:numel(messages)
                    warnings{index} = struct( ...
                        "code", "volume-warning-" + string(index), ...
                        "message", messages(index), ...
                        "severity", "warning");
                end
                value.warnings = warnings;
            elseif isstruct(scene.warnings)
                value.warnings = ...
                    reshape(num2cell(scene.warnings), 1, []);
            else
                error("KSSOLV:UI:Volume:SceneWarnings", ...
                    "Unsupported volume warning representation.");
            end

            % JSON null is the protocol representation for no atomic scene.
            if ~isfield(scene, "atomicOverlay") || ...
                    isempty(scene.atomicOverlay)
                value.atomicOverlay = NaN;
            end
        end
    end
end
