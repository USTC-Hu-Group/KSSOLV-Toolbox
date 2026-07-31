function write_restarts(system, x)
%WRITE_RESTARTS Write global and per-structure Packmol restart files.

settings = system.config.settings;
if settings.restart_to ~= "none"
    writePoses(resolve(settings.restart_to, ...
        system.config.working_directory), ...
        collectPoses(x, 1:system.free_molecule_count, ...
        system.free_molecule_count));
end
for structureIndex = 1:numel(system.structures)
    filename = system.structures(structureIndex).restart_to;
    if filename == "none"
        continue
    end
    variableIndices = zeros(1, 0);
    for instance = reshape(system.instances, 1, [])
        if ~instance.fixed && instance.structure_index == structureIndex
            variableIndices(end + 1) = instance.variable_index; %#ok<AGROW>
        end
    end
    writePoses(resolve(filename, system.config.working_directory), ...
        collectPoses(x, variableIndices, system.free_molecule_count));
end
end

function poses = collectPoses(x, indices, moleculeCount)
poses = zeros(numel(indices), 6);
for i = 1:numel(indices)
    variableIndex = indices(i);
    translationOffset = 3 * (variableIndex - 1);
    rotationOffset = 3 * moleculeCount + translationOffset;
    poses(i, :) = [ ...
        x(translationOffset + (1:3)).', ...
        x(rotationOffset + (1:3)).'];
end
end

function writePoses(filename, poses)
[fileId, message] = fopen(filename, "w");
if fileId < 0
    error("KSSOLV:Packmol:Restart", ...
        "Could not open restart_to file '%s': %s", filename, message);
end
cleanup = onCleanup(@() fclose(fileId));
for i = 1:size(poses, 1)
    fprintf(fileId, " %23.16E %23.16E %23.16E %23.16E %23.16E %23.16E\n", ...
        poses(i, :));
end
clear cleanup
end

function value = resolve(filename, directory)
filename = string(filename);
if isAbsolute(filename)
    value = filename;
else
    value = fullfile(directory, filename);
end
end

function value = isAbsolute(path)
path = char(string(path));
if ispc
    value = ~isempty(regexp(path, "^[A-Za-z]:[\\/]", "once")) || ...
        startsWith(path, "\\");
else
    value = startsWith(path, "/");
end
end
