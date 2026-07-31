function [x, moved] = move_bad(system, x, activeStructures, cycle)
%MOVE_BAD Reposition the worst molecules using Packmol's heuristic.

if nargin < 3 || isempty(activeStructures)
    activeStructures = 1:numel(system.structures);
end
if nargin < 4
    cycle = 0;
end
[~, ~, diagnostics] = kssolv.analysis.packmol.evaluate( ...
    system, x, ActiveStructures = activeStructures);
randomPoint = kssolv.analysis.packmol.initial_point( ...
    system, SeedOffset = cycle + 104729);
stream = RandStream("mt19937ar", "Seed", ...
    mod(abs(system.config.settings.seed) + cycle + 7919, 2^32 - 1));
moleculeCount = system.free_molecule_count;
moved = 0;
for structureIndex = reshape(activeStructures, 1, [])
    instances = find(arrayfun(@(item) ...
        ~item.fixed && item.structure_index == structureIndex, ...
        system.instances));
    if isempty(instances)
        continue
    end
    scores = zeros(numel(instances), 1);
    for i = 1:numel(instances)
        atoms = system.instances(instances(i)).atom_indices;
        scores(i) = max(diagnostics.atom_distance_violation(atoms)) + ...
            max(diagnostics.atom_restraint_contribution(atoms));
    end
    bad = find(scores > system.config.settings.precision);
    if isempty(bad)
        continue
    end
    fraction = min(system.config.settings.movefrac, ...
        numel(bad) / numel(instances));
    count = min(system.structures(structureIndex).maxmove, ...
        max(floor(numel(instances) * fraction), 1));
    [~, order] = sort(scores, "ascend");
    badIndices = order(end - count + 1:end);
    goodPoolSize = max(floor(numel(instances) * fraction), 1);
    goodPool = order(1:goodPoolSize);
    referenceCoordinates = system.structures(structureIndex). ...
        molecule.coordinates;
    diameter = moleculeDiameter(referenceCoordinates);
    for position = reshape(badIndices, 1, [])
        badInstance = system.instances(instances(position));
        badVariable = badInstance.variable_index;
        badTranslation = 3 * (badVariable - 1) + (1:3);
        badRotation = 3 * moleculeCount + ...
            3 * (badVariable - 1) + (1:3);
        if system.config.settings.movebadrandom || numel(instances) == 1
            x(badTranslation) = randomPoint(badTranslation);
            x(badRotation) = randomPoint(badRotation);
        else
            goodPosition = goodPool(randi(stream, numel(goodPool)));
            goodInstance = system.instances(instances(goodPosition));
            goodVariable = goodInstance.variable_index;
            goodTranslation = 3 * (goodVariable - 1) + (1:3);
            goodRotation = 3 * moleculeCount + ...
                3 * (goodVariable - 1) + (1:3);
            x(badTranslation) = x(goodTranslation) + ...
                diameter * (rand(stream, 3, 1) - 0.5) * 0.6;
            x(badRotation) = x(goodRotation);
        end
        moved = moved + 1;
    end
end
x = min(max(x, system.lower_bounds), system.upper_bounds);
end

function value = moleculeDiameter(coordinates)
value = 0;
for i = 1:size(coordinates, 1) - 1
    differences = coordinates(i + 1:end, :) - coordinates(i, :);
    value = max(value, max(sqrt(sum(differences.^2, 2)), [], ...
        "omitmissing"));
end
if value == 0
    value = 1;
end
end
