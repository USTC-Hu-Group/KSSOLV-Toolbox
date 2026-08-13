classdef MolecularMechanicsForceField
    %MOLECULARMECHANICSFORCEFIELD Auditable generic MM energy.
    %
    % This deterministic model combines harmonic typed bonds and angles,
    % generic periodic torsions, and short-range non-bonded repulsion. It is
    % useful for construction cleanup and local geometry relaxation. It is
    % not a branded force field and does not claim condensed-phase or
    % adsorption-energy accuracy.

    properties (Constant)
        SchemaVersion = 2
        ParameterSet = "kssolv-generic-mm-v2"
        Source = "KSSOLV traceable generic molecular-mechanics parameters"
    end

    methods (Static)
        function state = evaluate(model, coordinates)
            arguments
                model
                coordinates double = model.cart_coords
            end
            coordinates = double(coordinates);
            if ~isequal(size(coordinates), [model.num_sites, 3]) || ...
                    any(~isfinite(coordinates), "all")
                error("KSSOLV:Modeling:ForceFieldCoordinates", ...
                    "Force-field coordinates must be a finite N-by-3 array.");
            end

            bonds = kssolv.modeling.chemistry. ...
                MoleculeDiagnostics.topology(model);
            environment = bondedEnvironment(model.num_sites, bonds);
            atomMetadata = atomParameters(model, environment);
            [bondEnergy, bondGradient, bondMetadata] = ...
                bondTerms(model, coordinates, bonds);
            [angleEnergy, angleGradient, angleMetadata] = ...
                angleTerms(model, coordinates, environment);
            [torsionEnergy, torsionGradient, torsionMetadata] = ...
                torsionTerms(model, coordinates, bonds, environment);
            [repulsionEnergy, repulsionGradient, repulsionMetadata] = ...
                repulsionTerms(model, coordinates, bonds);
            gradient = bondGradient + angleGradient + ...
                torsionGradient + repulsionGradient;
            forces = -gradient;
            if isempty(forces)
                maximumForce = 0;
            else
                maximumForce = max(vecnorm(forces, 2, 2));
            end
            fallbackByKind = struct( ...
                "atom", fallbackTotal(atomMetadata), ...
                "bond", fallbackTotal(bondMetadata), ...
                "angle", fallbackTotal(angleMetadata), ...
                "torsion", fallbackTotal(torsionMetadata), ...
                "nonbonded", fallbackTotal(repulsionMetadata));
            state = struct( ...
                "schemaVersion", ...
                kssolv.modeling.forcefield. ...
                MolecularMechanicsForceField.SchemaVersion, ...
                "parameterSet", ...
                kssolv.modeling.forcefield. ...
                MolecularMechanicsForceField.ParameterSet, ...
                "parameterSchemaVersion", ...
                kssolv.modeling.forcefield. ...
                GeometryParameterProvider.SchemaVersion, ...
                "parameterSource", ...
                kssolv.modeling.forcefield. ...
                GeometryParameterProvider.ParameterSet, ...
                "source", ...
                kssolv.modeling.forcefield. ...
                MolecularMechanicsForceField.Source, ...
                "isEnergyModel", true, ...
                "energy", bondEnergy + angleEnergy + ...
                    torsionEnergy + repulsionEnergy, ...
                "energyUnit", "kJ/mol", ...
                "gradient", gradient, ...
                "gradientUnit", "kJ/(mol angstrom)", ...
                "maximumForce", maximumForce, ...
                "termEnergy", struct("bond", bondEnergy, ...
                    "angle", angleEnergy, "torsion", torsionEnergy, ...
                    "repulsion", repulsionEnergy), ...
                "termCount", struct("bond", size(bonds, 1), ...
                    "angle", numel(angleMetadata), ...
                    "torsion", numel(torsionMetadata), ...
                    "repulsion", activeTotal(repulsionMetadata)), ...
                "parameterCount", struct("atom", numel(atomMetadata), ...
                    "bond", numel(bondMetadata), ...
                    "angle", numel(angleMetadata), ...
                    "torsion", numel(torsionMetadata), ...
                    "nonbonded", numel(repulsionMetadata)), ...
                "fallbackByKind", fallbackByKind, ...
                "fallbackCount", fallbackByKind.atom + ...
                    fallbackByKind.bond + fallbackByKind.angle + ...
                    fallbackByKind.torsion + fallbackByKind.nonbonded, ...
                "limitations", [ ...
                    "No electrostatics"; ...
                    "No dispersion attraction"; ...
                    "Generic rather than chemistry-specific torsions"; ...
                    "Torsion derivatives use central finite differences"; ...
                    "Molecules only"]);
        end
    end
end

function metadata = atomParameters(model, environment)
metadata = emptyMetadata();
for index = 1:model.num_sites
    parameter = kssolv.modeling.forcefield. ...
        GeometryParameterProvider.atom(symbolAt(model, index), ...
        environment.orders(index, environment.adjacency(index, :)));
    metadata(end + 1, 1) = compactMetadata(parameter, false); %#ok<AGROW>
end
end

function [energy, gradient, metadata] = bondTerms(model, coordinates, bonds)
energy = 0;
gradient = zeros(size(coordinates));
metadata = emptyMetadata();
for row = 1:size(bonds, 1)
    first = bonds(row, 1);
    second = bonds(row, 2);
    order = bonds(row, 3);
    parameter = kssolv.modeling.forcefield. ...
        GeometryParameterProvider.bond( ...
        symbolAt(model, first), symbolAt(model, second), order);
    metadata(end + 1, 1) = compactMetadata(parameter, true); %#ok<AGROW>
    forceConstant = parameter.forceConstant;
    vector = coordinates(first, :) - coordinates(second, :);
    distance = norm(vector);
    if distance <= 1e-12
        vector = deterministicDirection(first, second);
        distance = 1e-12;
    end
    displacement = distance - parameter.value;
    energy = energy + 0.5 * forceConstant * displacement^2;
    contribution = forceConstant * displacement * vector / distance;
    gradient(first, :) = gradient(first, :) + contribution;
    gradient(second, :) = gradient(second, :) - contribution;
end
end

function [energy, gradient, metadata] = angleTerms( ...
        model, coordinates, environment)
energy = 0;
gradient = zeros(size(coordinates));
metadata = emptyMetadata();
for center = 1:model.num_sites
    neighbors = find(environment.adjacency(center, :));
    incidentOrders = environment.orders( ...
        center, environment.adjacency(center, :));
    for firstPosition = 1:numel(neighbors) - 1
        for secondPosition = firstPosition + 1:numel(neighbors)
            first = neighbors(firstPosition);
            second = neighbors(secondPosition);
            parameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.angle(symbolAt(model, first), ...
                symbolAt(model, center), symbolAt(model, second), ...
                incidentOrders);
            [termEnergy, termGradient] = oneAngle( ...
                coordinates, first, center, second, parameter);
            energy = energy + termEnergy;
            gradient([first, center, second], :) = ...
                gradient([first, center, second], :) + termGradient;
            metadata(end + 1, 1) = ...
                compactMetadata(parameter, termEnergy ~= 0); %#ok<AGROW>
        end
    end
end
end

function [energy, gradient] = oneAngle( ...
        coordinates, first, center, second, parameter)
firstVector = coordinates(first, :) - coordinates(center, :);
secondVector = coordinates(second, :) - coordinates(center, :);
firstLength = norm(firstVector);
secondLength = norm(secondVector);
gradient = zeros(3, 3);
if firstLength <= 1e-12 || secondLength <= 1e-12
    energy = 0;
    return
end
cosine = max(-1, min(1, dot(firstVector, secondVector) / ...
    (firstLength * secondLength)));
angle = acos(cosine);
target = deg2rad(parameter.value);
forceConstant = parameter.forceConstant;
delta = angle - target;
energy = 0.5 * forceConstant * delta^2;
if abs(delta) <= 1e-14, return, end
sine = max(sqrt(max(0, 1 - cosine^2)), 1e-8);
dFirst = -(secondVector / (firstLength * secondLength) - ...
    cosine * firstVector / firstLength^2) / sine;
dSecond = -(firstVector / (firstLength * secondLength) - ...
    cosine * secondVector / secondLength^2) / sine;
gradient(1, :) = forceConstant * delta * dFirst;
gradient(3, :) = forceConstant * delta * dSecond;
gradient(2, :) = -gradient(1, :) - gradient(3, :);
end

function [energy, gradient, metadata] = torsionTerms( ...
        model, coordinates, bonds, environment)
energy = 0;
gradient = zeros(size(coordinates));
metadata = emptyMetadata();
for row = 1:size(bonds, 1)
    second = bonds(row, 1);
    third = bonds(row, 2);
    firstNeighbors = find(environment.adjacency(second, :));
    fourthNeighbors = find(environment.adjacency(third, :));
    firstNeighbors(firstNeighbors == third) = [];
    fourthNeighbors(fourthNeighbors == second) = [];
    for first = reshape(firstNeighbors, 1, [])
        for fourth = reshape(fourthNeighbors, 1, [])
            if first == fourth, continue, end
            indices = [first, second, third, fourth];
            parameter = kssolv.modeling.forcefield. ...
                GeometryParameterProvider.torsion( ...
                symbolAt(model, first), symbolAt(model, second), ...
                symbolAt(model, third), symbolAt(model, fourth), ...
                bonds(row, 3));
            [termEnergy, termGradient] = oneTorsion( ...
                coordinates(indices, :), parameter);
            energy = energy + termEnergy;
            gradient(indices, :) = gradient(indices, :) + termGradient;
            metadata(end + 1, 1) = ...
                compactMetadata(parameter, termEnergy ~= 0); %#ok<AGROW>
        end
    end
end
end

function [energy, gradient] = oneTorsion(localCoordinates, parameter)
[energy, singular] = torsionEnergy(localCoordinates, parameter);
gradient = zeros(4, 3);
if singular, return, end
step = 1e-6;
for row = 1:4
    for column = 1:3
        plus = localCoordinates;
        minus = localCoordinates;
        plus(row, column) = plus(row, column) + step;
        minus(row, column) = minus(row, column) - step;
        plusEnergy = torsionEnergy(plus, parameter);
        minusEnergy = torsionEnergy(minus, parameter);
        gradient(row, column) = (plusEnergy - minusEnergy) / (2 * step);
    end
end
% Suppress only round-off translation drift introduced by differencing.
gradient = gradient - mean(gradient, 1);
end

function [energy, singular] = torsionEnergy(coordinates, parameter)
first = coordinates(1, :) - coordinates(2, :);
axis = coordinates(3, :) - coordinates(2, :);
fourth = coordinates(4, :) - coordinates(3, :);
axisLength = norm(axis);
if axisLength <= 1e-12
    energy = 0;
    singular = true;
    return
end
axis = axis / axisLength;
first = first - dot(first, axis) * axis;
fourth = fourth - dot(fourth, axis) * axis;
if norm(first) <= 1e-10 || norm(fourth) <= 1e-10
    energy = 0;
    singular = true;
    return
end
angle = atan2(dot(cross(axis, first), fourth), dot(first, fourth));
argument = parameter.periodicity * angle - deg2rad(parameter.phase);
energy = parameter.forceConstant * (1 + cos(argument));
singular = false;
end

function [energy, gradient, metadata] = repulsionTerms( ...
        model, coordinates, bonds)
energy = 0;
gradient = zeros(size(coordinates));
metadata = emptyMetadata();
excluded = false(model.num_sites);
for row = 1:size(bonds, 1)
    excluded(bonds(row, 1), bonds(row, 2)) = true;
    excluded(bonds(row, 2), bonds(row, 1)) = true;
end
excluded = excluded | (excluded * excluded > 0);
for first = 1:model.num_sites - 1
    for second = first + 1:model.num_sites
        if excluded(first, second), continue, end
        parameter = kssolv.modeling.forcefield. ...
            GeometryParameterProvider.nonbonded( ...
            symbolAt(model, first), symbolAt(model, second));
        vector = coordinates(first, :) - coordinates(second, :);
        distance = norm(vector);
        active = distance < parameter.cutoff;
        metadata(end + 1, 1) = ...
            compactMetadata(parameter, active); %#ok<AGROW>
        if ~active, continue, end
        if distance <= 1e-12
            vector = deterministicDirection(first, second);
            distance = 1e-12;
        end
        overlap = parameter.cutoff - distance;
        energy = energy + 0.5 * parameter.forceConstant * overlap^2;
        contribution = -parameter.forceConstant * overlap * ...
            vector / distance;
        gradient(first, :) = gradient(first, :) + contribution;
        gradient(second, :) = gradient(second, :) - contribution;
    end
end
end

function environment = bondedEnvironment(count, bonds)
environment = struct("adjacency", false(count), "orders", zeros(count));
for row = 1:size(bonds, 1)
    first = bonds(row, 1);
    second = bonds(row, 2);
    environment.adjacency(first, second) = true;
    environment.adjacency(second, first) = true;
    environment.orders(first, second) = bonds(row, 3);
    environment.orders(second, first) = bonds(row, 3);
end
end

function symbol = symbolAt(model, index)
symbol = string(model(index).specie.symbol);
end

function metadata = emptyMetadata()
metadata = repmat(struct("source", "", "fallback", false, ...
    "active", false), 0, 1);
end

function value = compactMetadata(parameter, active)
value = struct("source", string(parameter.source), ...
    "fallback", logical(parameter.fallback), "active", logical(active));
end

function count = fallbackTotal(metadata)
if isempty(metadata)
    count = 0;
else
    count = sum([metadata.fallback]);
end
end

function count = activeTotal(metadata)
if isempty(metadata)
    count = 0;
else
    count = sum([metadata.active]);
end
end

function value = deterministicDirection(first, second)
seed = mod(104729 * first + 13007 * second, 9973) / 9973;
value = [cos(2*pi*seed), sin(2*pi*seed), 0.5 - seed];
value = value / norm(value);
end
