function [f, gradient, diagnostics] = evaluate(system, x, options)
%EVALUATE Compute the native Packmol objective and analytical gradient.
arguments
    system (1,1) struct
    x (:,1) double
    options.RestraintsOnly (1,1) logical = false
    options.ActiveStructures double = []
end

[coordinates, ~, derivatives] = ...
    kssolv.analysis.packmol.cartesian_coordinates(system, x);
cartesianGradient = zeros(system.atom_count, 3);
atomRestraint = zeros(system.atom_count, 1);
atomDistance = zeros(system.atom_count, 1);
restraintObjective = 0;
maximumRestraint = 0;
activeStructures = options.ActiveStructures;
if isempty(activeStructures)
    activeStructures = 1:numel(system.structures);
end

for instanceIndex = 1:numel(system.instances)
    instance = system.instances(instanceIndex);
    if instance.fixed || ...
            ~any(instance.structure_index == activeStructures)
        continue
    end
    structure = system.structures(instance.structure_index);
    for constraintIndex = 1:numel(structure.constraints)
        constraint = structure.constraints(constraintIndex);
        atomIndices = instance.atom_indices(constraint.atoms);
        [value, localGradient, ~, perAtom] = ...
            kssolv.analysis.packmol.constraint_function( ...
            constraint.type, constraint.parameters, ...
            coordinates(atomIndices, :));
        restraintObjective = restraintObjective + value;
        cartesianGradient(atomIndices, :) = ...
            cartesianGradient(atomIndices, :) + localGradient;
        atomRestraint(atomIndices) = ...
            atomRestraint(atomIndices) + perAtom;
    end
    if system.config.settings.using_pbc
        atomIndices = instance.atom_indices;
        [value, localGradient, ~, perAtom] = ...
            kssolv.analysis.packmol.constraint_function( ...
            3, [system.config.settings.pbc_min, ...
                system.config.settings.pbc_max], ...
            coordinates(atomIndices, :));
        restraintObjective = restraintObjective + value;
        cartesianGradient(atomIndices, :) = ...
            cartesianGradient(atomIndices, :) + localGradient;
        atomRestraint(atomIndices) = ...
            atomRestraint(atomIndices) + perAtom;
    end
end
maximumRestraint = max(atomRestraint, [], "omitmissing");

distanceObjective = 0;
maximumDistance = 0;
if ~options.RestraintsOnly
    if system.config.settings.using_pbc
        pbcLength = system.config.settings.pbc_max - ...
            system.config.settings.pbc_min;
    else
        pbcLength = [];
    end
    cutoff = 2 * max(system.radius);
    if system.config.settings.using_pbc
        pairs = kssolv.analysis.packmol.candidate_pairs( ...
            coordinates, cutoff, system.config.settings.pbc_min, ...
            system.config.settings.pbc_max);
    else
        pairs = kssolv.analysis.packmol.candidate_pairs( ...
            coordinates, cutoff);
    end
    for pairIndex = 1:size(pairs, 1)
        first = pairs(pairIndex, 1);
        second = pairs(pairIndex, 2);
        if ~any(system.atom_structure(first) == activeStructures) && ...
                ~system.fixed(first)
            continue
        end
        if system.atom_instance(first) == system.atom_instance(second)
            continue
        end
        if system.fixed(first) && system.fixed(second)
            continue
        end
        if ~any(system.atom_structure(second) == activeStructures) && ...
                ~system.fixed(second)
            continue
        end
        delta = kssolv.analysis.packmol.delta_vector( ...
            coordinates(first, :), coordinates(second, :), pbcLength);
        distanceSquared = sum(delta.^2);
        targetSquared = ...
            (system.radius(first) + system.radius(second))^2;
        maximumDistance = max(maximumDistance, ...
            max(targetSquared - distanceSquared, 0));
        atomDistance(first) = max(atomDistance(first), ...
            max(targetSquared - distanceSquared, 0));
        atomDistance(second) = max(atomDistance(second), ...
            max(targetSquared - distanceSquared, 0));
        if distanceSquared >= targetSquared
            continue
        end
        pairScale = system.fscale(first) * system.fscale(second);
        residual = distanceSquared - targetSquared;
        distanceObjective = distanceObjective + pairScale * residual^2;
        factor = 4 * pairScale * residual;
        cartesianGradient(first, :) = ...
            cartesianGradient(first, :) + factor * delta;
        cartesianGradient(second, :) = ...
            cartesianGradient(second, :) - factor * delta;
        if system.use_short_radius(first) || ...
                system.use_short_radius(second)
            shortTargetSquared = ...
                (system.short_radius(first) + ...
                 system.short_radius(second))^2;
            if distanceSquared < shortTargetSquared
                shortScale = sqrt( ...
                    system.short_radius_scale(first) * ...
                    system.short_radius_scale(second));
                shortScale = shortScale * ...
                    targetSquared^2 / shortTargetSquared^2;
                shortResidual = ...
                    distanceSquared - shortTargetSquared;
                distanceObjective = distanceObjective + ...
                    pairScale * shortScale * shortResidual^2;
                factor = 4 * pairScale * shortScale * shortResidual;
                cartesianGradient(first, :) = ...
                    cartesianGradient(first, :) + factor * delta;
                cartesianGradient(second, :) = ...
                    cartesianGradient(second, :) - factor * delta;
            end
        end
    end
end

f = restraintObjective + distanceObjective;
gradient = zeros(size(x));
moleculeCount = system.free_molecule_count;
for instanceIndex = 1:numel(system.instances)
    instance = system.instances(instanceIndex);
    if instance.fixed
        continue
    end
    variableIndex = instance.variable_index;
    translationOffset = 3 * (variableIndex - 1);
    rotationOffset = 3 * moleculeCount + translationOffset;
    atomIndices = instance.atom_indices;
    localGradient = cartesianGradient(atomIndices, :);
    gradient(translationOffset + (1:3)) = sum(localGradient, 1);
    reference = system.structures(instance.structure_index). ...
        molecule.coordinates;
    for angleIndex = 1:3
        derivativeCoordinates = reference * ...
            derivatives(:, :, angleIndex, variableIndex).';
        gradient(rotationOffset + angleIndex) = ...
            sum(derivativeCoordinates .* localGradient, "all");
    end
end
diagnostics = struct( ...
    "restraint_objective", restraintObjective, ...
    "distance_objective", distanceObjective, ...
    "maximum_restraint_violation", maximumRestraint, ...
    "maximum_distance_violation", maximumDistance, ...
    "coordinates", coordinates, ...
    "cartesian_gradient", cartesianGradient, ...
    "atom_restraint_contribution", atomRestraint, ...
    "atom_distance_violation", atomDistance);
end
