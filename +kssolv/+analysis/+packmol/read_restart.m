function x = read_restart(system, x)
%READ_RESTART Apply global or per-structure Packmol restart files.

globalFile = system.config.settings.restart_from;
if globalFile ~= "none"
    poses = readPoses(resolve(globalFile, ...
        system.config.working_directory), ...
        system.free_molecule_count);
    x = assignPoses(x, 1:system.free_molecule_count, poses, ...
        system.free_molecule_count);
    return
end
for structureIndex = 1:numel(system.structures)
    filename = system.structures(structureIndex).restart_from;
    if filename == "none"
        continue
    end
    variableIndices = zeros(1, 0);
    for instance = reshape(system.instances, 1, [])
        if ~instance.fixed && instance.structure_index == structureIndex
            variableIndices(end + 1) = instance.variable_index; %#ok<AGROW>
        end
    end
    poses = readPoses(resolve(filename, ...
        system.config.working_directory), numel(variableIndices));
    x = assignPoses(x, variableIndices, poses, ...
        system.free_molecule_count);
end
end

function poses = readPoses(filename, count)
if ~isfile(filename)
    error("KSSOLV:Packmol:OpenFile", ...
        "Could not open restart file '%s'.", filename);
end
lines = splitlines(string(fileread(filename)));
poses = zeros(count, 6);
for i = 1:count
    if i > numel(lines)
        invalidRestart(filename, count);
    end
    line = regexprep(lines(i), ...
        "([0-9.])[dD]([+-]?[0-9]+)", "$1E$2");
    values = str2double(kssolv.analysis.packmol.tokenize(line));
    if numel(values) < 6 || any(~isfinite(values(1:6)))
        invalidRestart(filename, count);
    end
    poses(i, :) = values(1:6);
end
end

function x = assignPoses(x, indices, poses, moleculeCount)
for i = 1:numel(indices)
    variableIndex = indices(i);
    translationOffset = 3 * (variableIndex - 1);
    rotationOffset = 3 * moleculeCount + translationOffset;
    x(translationOffset + (1:3)) = poses(i, 1:3);
    x(rotationOffset + (1:3)) = poses(i, 4:6);
end
end

function value = resolve(filename, directory)
filename = string(filename);
if isAbsolute(filename)
    value = filename;
else
    value = fullfile(directory, filename);
end
end

function invalidRestart(filename, count)
error("KSSOLV:Packmol:Restart", ...
    "Restart file '%s' does not contain %d six-value poses.", ...
    filename, count);
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
