function [coordinates, rotations, derivatives] = cartesian_coordinates(system, x)
%CARTESIAN_COORDINATES Convert Packmol rigid variables to atom positions.

x = double(x(:));
moleculeCount = system.free_molecule_count;
if numel(x) ~= 6 * moleculeCount
    error("KSSOLV:Packmol:Variables", ...
        "Expected %d rigid variables, received %d.", ...
        6 * moleculeCount, numel(x));
end
coordinates = system.fixed_coordinates;
rotations = zeros(3, 3, moleculeCount);
derivatives = zeros(3, 3, 3, moleculeCount);
for instanceIndex = 1:numel(system.instances)
    instance = system.instances(instanceIndex);
    if instance.fixed
        continue
    end
    variableIndex = instance.variable_index;
    translationOffset = 3 * (variableIndex - 1);
    rotationOffset = 3 * moleculeCount + translationOffset;
    translation = x(translationOffset + (1:3)).';
    angles = x(rotationOffset + (1:3));
    [rotation, dRotation] = kssolv.analysis.packmol.eulerrmat( ...
        angles(1), angles(2), angles(3));
    structure = system.structures(instance.structure_index);
    coordinates(instance.atom_indices, :) = ...
        structure.molecule.coordinates * rotation.' + translation;
    rotations(:, :, variableIndex) = rotation;
    derivatives(:, :, :, variableIndex) = dRotation;
end
end
