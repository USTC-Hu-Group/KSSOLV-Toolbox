function x = initial_point(system, options)
%INITIAL_POINT Build Packmol's random rigid-body starting point.
arguments
    system (1,1) struct
    options.SeedOffset (1,1) double {mustBeInteger} = 0
end

moleculeCount = system.free_molecule_count;
x = zeros(6 * moleculeCount, 1);
if moleculeCount == 0
    return
end
seed = double(system.config.settings.seed) + double(options.SeedOffset);
stream = RandStream("mt19937ar", "Seed", mod(abs(seed), 2^32 - 1));
for instanceIndex = 1:numel(system.instances)
    instance = system.instances(instanceIndex);
    if instance.fixed
        continue
    end
    structure = system.structures(instance.structure_index);
    variableIndex = instance.variable_index;
    translationOffset = 3 * (variableIndex - 1);
    rotationOffset = 3 * moleculeCount + translationOffset;
    bestPose = zeros(1, 6);
    bestValue = Inf;
    [lower, upper] = samplingBox(system, structure);
    for attempt = 1:200
        translation = lower + rand(stream, 1, 3) .* (upper - lower);
        angles = 2 * pi * rand(stream, 1, 3);
        for axis = 1:3
            if structure.rotation_constrained(axis)
                center = structure.rotation_bounds(axis, 1);
                width = abs(structure.rotation_bounds(axis, 2));
                angles(axis) = center - width + ...
                    2 * width * rand(stream);
            end
        end
        [rotation, ~] = kssolv.analysis.packmol.eulerrmat( ...
            angles(1), angles(2), angles(3));
        coordinates = structure.molecule.coordinates * rotation.' + ...
            translation;
        value = 0;
        for constraintIndex = 1:numel(structure.constraints)
            constraint = structure.constraints(constraintIndex);
            value = value + kssolv.analysis.packmol.constraint_function( ...
                constraint.type, constraint.parameters, ...
                coordinates(constraint.atoms, :));
        end
        if system.config.settings.using_pbc
            value = value + kssolv.analysis.packmol.constraint_function( ...
                3, [system.config.settings.pbc_min, ...
                    system.config.settings.pbc_max], coordinates);
        end
        overlapValue = 0;
        if system.config.settings.avoid_overlap && any(system.fixed)
            fixedIndices = find(system.fixed);
            if system.config.settings.using_pbc
                pbcLength = system.config.settings.pbc_max - ...
                    system.config.settings.pbc_min;
            else
                pbcLength = [];
            end
            for localAtom = 1:size(coordinates, 1)
                for fixedIndex = reshape(fixedIndices, 1, [])
                    delta = kssolv.analysis.packmol.delta_vector( ...
                        coordinates(localAtom, :), ...
                        system.fixed_coordinates(fixedIndex, :), ...
                        pbcLength);
                    distanceSquared = sum(delta.^2);
                    targetSquared = ( ...
                        structure.radius(localAtom) + ...
                        system.radius(fixedIndex))^2;
                    overlapValue = overlapValue + ...
                        max(targetSquared - distanceSquared, 0)^2;
                end
            end
        end
        value = value + overlapValue;
        if value < bestValue
            bestValue = value;
            bestPose = [translation, angles];
        end
        if value <= system.config.settings.precision && ...
                overlapValue == 0
            break
        end
    end
    x(translationOffset + (1:3)) = bestPose(1:3);
    x(rotationOffset + (1:3)) = bestPose(4:6);
end
x = min(max(x, system.lower_bounds), system.upper_bounds);
x = kssolv.analysis.packmol.read_restart(system, x);
end

function [lower, upper] = samplingBox(system, structure)
side = system.config.settings.sidemax;
lower = repmat(-side, 1, 3);
upper = repmat(side, 1, 3);
if system.config.settings.using_pbc
    lower = system.config.settings.pbc_min;
    upper = system.config.settings.pbc_max;
    return
end
for i = 1:numel(structure.constraints)
    constraint = structure.constraints(i);
    p = constraint.parameters;
    if constraint.type == 2
        lower = p(1:3);
        upper = lower + p(4);
        return
    elseif constraint.type == 3
        lower = p(1:3);
        upper = p(4:6);
        return
    elseif constraint.type == 4
        lower = p(1:3) - p(4);
        upper = p(1:3) + p(4);
        return
    elseif constraint.type == 5
        extent = abs(p(4:6) * p(7));
        lower = p(1:3) - extent;
        upper = p(1:3) + extent;
        return
    elseif constraint.type == 12
        endpoint = p(1:3) + p(4:6) * p(9);
        lower = min(p(1:3), endpoint) - p(7);
        upper = max(p(1:3), endpoint) + p(7);
        return
    end
end
end
