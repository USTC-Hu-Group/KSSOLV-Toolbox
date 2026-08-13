classdef MolecularGeometryCommands
    %MOLECULARGEOMETRYCOMMANDS Exact molecular measurements and edits.

    methods (Static)
        function ids = commandIds()
            ids = [
                "measure_geometry"
                "set_distance"
                "set_angle"
                "set_dihedral"
                "align_geometry"
                "clean_geometry"
                "optimize_geometry"
                ];
        end

        function value = supports(commandId)
            value = any(kssolv.modeling.geometry. ...
                MolecularGeometryCommands.commandIds() == string(commandId));
        end

        function result = execute(model, commandId, parameters)
            import kssolv.modeling.ParameterUtils
            commandId = string(commandId);
            changed = true; analysis = struct();
            switch commandId
                case "measure_geometry"
                    indices = ParameterUtils.indices(parameters, ...
                        model.num_sites, []);
                    analysis = measureValue(model, indices);
                    changed = false;
                case "set_distance"
                    indices = exactIndices(parameters, model.num_sites, 2);
                    target = positiveScalar(parameters, "value", 1.5);
                    moving = movingSet(model, indices(1), indices(2), ...
                        parameters);
                    reference = geometryReference( ...
                        model, indices, parameters);
                    if ~isempty(reference)
                        direction = reference(2, :) - reference(1, :);
                        if norm(direction) <= eps, direction = [1, 0, 0]; end
                        direction = direction / norm(direction);
                        model = translateModel(model, moving, ...
                            reference(1, :) + target * direction - ...
                            reference(2, :), true);
                    else
                        direction = minimumImageDisplacement( ...
                            model, indices(1), indices(2));
                        if norm(direction) <= eps, direction = [1, 0, 0]; end
                        direction = direction / norm(direction);
                        current = minimumImageDisplacement( ...
                            model, indices(1), indices(2));
                        model = translateModel(model, moving, ...
                            target * direction - current, true);
                    end
                case "set_angle"
                    indices = exactIndices(parameters, model.num_sites, 3);
                    target = angleScalar(parameters, "value", 109.5, 0, 180);
                    moving = movingSet(model, indices(2), indices(3), ...
                        parameters);
                    reference = geometryReference( ...
                        model, indices, parameters);
                    if ~isempty(reference)
                        firstVector = reference(1, :) - reference(2, :);
                        movingVector = reference(3, :) - reference(2, :);
                        axis = cross(movingVector, firstVector);
                        if norm(axis) <= 1e-12
                            axis = perpendicular(movingVector);
                        end
                        [nextPoint, errorValue] = bestAnglePoint( ...
                            reference, target, axis);
                        if errorValue > 1e-7
                            error("KSSOLV:Modeling:GeometryReference", ...
                                "Unable to satisfy the referenced bond angle.");
                        end
                        model = translateModel(model, moving, ...
                            nextPoint - reference(3, :), true);
                    else
                        firstVector = minimumImageDisplacement( ...
                            model, indices(2), indices(1));
                        movingVector = minimumImageDisplacement( ...
                            model, indices(2), indices(3));
                        current = vectorAngle(firstVector, movingVector);
                        axis = cross(movingVector, firstVector);
                        if norm(axis) <= 1e-12
                            axis = perpendicular(movingVector);
                        end
                        model = unwrapMovingAnchor( ...
                            model, moving, indices(2), indices(3));
                        model = rotateModel(model, moving, ...
                            deg2rad(current - target), axis, ...
                            model(indices(2)).coords);
                    end
                case "set_dihedral"
                    indices = exactIndices(parameters, model.num_sites, 4);
                    target = angleScalar(parameters, "value", 180, -180, 180);
                    reference = geometryReference( ...
                        model, indices, parameters);
                    if ~isempty(reference)
                        axis = reference(3, :) - reference(2, :);
                        if norm(axis) <= eps
                            error("KSSOLV:Modeling:DihedralAxis", ...
                                "The central dihedral bond has zero length.");
                        end
                        [nextPoint, errorValue] = bestDihedralPoint( ...
                            reference, target, axis);
                        if errorValue > 1e-7
                            error("KSSOLV:Modeling:GeometryReference", ...
                                "Unable to satisfy the referenced dihedral angle.");
                        end
                        model = translateModel(model, indices(4), ...
                            nextPoint - reference(4, :), true);
                    else
                        if isPeriodicModel(model)
                            moving = indices(4);
                        else
                            moving = movingSet(model, indices(2), indices(3), ...
                                parameters);
                        end
                        current = signedDihedral( ...
                            unwrappedChain(model, indices));
                        axis = minimumImageDisplacement( ...
                            model, indices(2), indices(3));
                        if norm(axis) <= eps
                            error("KSSOLV:Modeling:DihedralAxis", ...
                                "The central dihedral bond has zero length.");
                        end
                        model = unwrapMovingAnchor( ...
                            model, moving, indices(3), indices(4));
                        model = rotateModel(model, moving, ...
                            deg2rad(wrap180(target - current)), axis, ...
                            model(indices(2)).coords);
                        % Resolve the sign convention from the actual result.
                        actual = signedDihedral(unwrappedChain(model, indices));
                        residual = wrap180(target - actual);
                        if abs(residual) > 1e-10
                            model = rotateModel(model, moving, ...
                                deg2rad(-residual), axis, ...
                                model(indices(2)).coords);
                            actual = signedDihedral( ...
                                unwrappedChain(model, indices));
                            residual = wrap180(target - actual);
                            if abs(residual) > 1e-7
                                model = rotateModel(model, moving, ...
                                    deg2rad(2 * residual), axis, ...
                                    model(indices(2)).coords);
                            end
                        end
                    end
                case "align_geometry"
                    indices = ParameterUtils.indices(parameters, ...
                        model.num_sites, 1:model.num_sites);
                    mode = lower(string(ParameterUtils.get(parameters, ...
                        "mode", "principal_axis")));
                    target = ParameterUtils.vector(parameters, ...
                        "target", 3, [1, 0, 0]);
                    if norm(target) <= eps
                        error("KSSOLV:Modeling:AlignmentTarget", ...
                            "Alignment target cannot be zero.");
                    end
                    [model, coordinates] = ...
                        unwrapSelection(model, indices);
                    anchor = mean(coordinates, 1);
                    centered = coordinates - anchor;
                    [~, ~, vectors] = svd(centered, 0);
                    if mode == "plane_normal"
                        source = vectors(:, end).';
                    else
                        source = vectors(:, 1).';
                    end
                    [axis, angle] = alignmentRotation(source, target);
                    model = rotateModel( ...
                        model, indices, angle, axis, anchor);
                case "clean_geometry"
                    iterations = double(ParameterUtils.get(parameters, ...
                        "iterations", 4));
                    if iterations < 1 || iterations ~= fix(iterations)
                        error("KSSOLV:Modeling:CleanIterations", ...
                            "Clean iterations must be a positive integer.");
                    end
                    model = cleanRuleBased(model, iterations);
                    analysis = kssolv.modeling.chemistry. ...
                        MoleculeDiagnostics.inspect(model);
                    analysis.cleanMethod = "rule-based-bond-length-relaxation";
                    analysis.geometryParameterSet = ...
                        kssolv.modeling.forcefield. ...
                        GeometryParameterProvider.ParameterSet;
                    analysis.isEnergyMinimization = false;
                case "optimize_geometry"
                    maximumIterations = double(ParameterUtils.get( ...
                        parameters, "maximumIterations", 200));
                    forceTolerance = double(ParameterUtils.get( ...
                        parameters, "forceTolerance", 1e-3));
                    fixedIndices = double(ParameterUtils.get( ...
                        parameters, "fixedIndices", zeros(1, 0)));
                    [model, analysis] = kssolv.modeling.forcefield. ...
                        GeometryOptimizer.optimize(model, ...
                        MaximumIterations = maximumIterations, ...
                        ForceTolerance = forceTolerance, ...
                        FixedIndices = fixedIndices);
                otherwise
                    error("KSSOLV:Modeling:GeometryCommand", ...
                        "Unsupported molecular geometry command '%s'.", ...
                        commandId);
            end
            result = struct("model", model, "changed", changed, ...
                "message", "Molecular geometry updated.");
            if ~isempty(fieldnames(analysis)), result.analysis = analysis; end
            if commandId == "measure_geometry"
                result.message = "Geometry measurement completed.";
            elseif commandId == "clean_geometry"
                result.message = "Rule-based geometry clean completed; " + ...
                    "this is not an energy minimization.";
            elseif commandId == "optimize_geometry"
                if analysis.converged
                    result.message = "Geometry optimization converged.";
                else
                    result.message = "Geometry optimization stopped without " + ...
                        "convergence (" + analysis.reason + ").";
                end
            end
        end

        function value = measure(model, indices)
            value = measureValue(model, indices);
        end
    end
end

function value = measureValue(model, indices)
switch numel(indices)
    case 2
        value = struct("kind", "distance", "value", ...
            norm(minimumImageDisplacement( ...
            model, indices(1), indices(2))), ...
            "unit", "angstrom", "indices", indices);
    case 3
        value = struct("kind", "angle", "value", vectorAngle( ...
            minimumImageDisplacement(model, indices(2), indices(1)), ...
            minimumImageDisplacement(model, indices(2), indices(3))), ...
            "unit", "degree", "indices", indices);
    case 4
        value = struct("kind", "dihedral", "value", ...
            signedDihedral(unwrappedChain(model, indices)), ...
            "unit", "degree", "indices", indices);
    otherwise
        error("KSSOLV:Modeling:MeasurementSelection", ...
            "Select 2, 3, or 4 atoms to measure distance, angle, or dihedral.");
end
end

function indices = exactIndices(parameters, count, expected)
indices = kssolv.modeling.ParameterUtils.indices(parameters, count, []);
if numel(indices) ~= expected
    error("KSSOLV:Modeling:GeometrySelection", ...
        "This geometry operation requires exactly %d atoms.", expected);
end
indices = reshape(indices, 1, []);
end

function value = positiveScalar(parameters, name, fallback)
value = double(kssolv.modeling.ParameterUtils.get(parameters, name, fallback));
if ~isscalar(value) || ~isfinite(value) || value <= 0
    error("KSSOLV:Modeling:GeometryValue", ...
        "%s must be a positive finite scalar.", name);
end
end

function value = angleScalar(parameters, name, fallback, lower, upper)
value = double(kssolv.modeling.ParameterUtils.get(parameters, name, fallback));
if ~isscalar(value) || ~isfinite(value) || value < lower || value > upper
    error("KSSOLV:Modeling:GeometryAngle", ...
        "%s must be between %g and %g degrees.", name, lower, upper);
end
end

function angle = vectorAngle(first, second)
denominator = norm(first) * norm(second);
if denominator <= eps
    error("KSSOLV:Modeling:ZeroLengthGeometry", ...
        "Cannot measure an angle with a zero-length vector.");
end
angle = acosd(max(-1, min(1, dot(first, second) / denominator)));
end

function angle = signedDihedral(coordinates)
b1 = coordinates(2, :) - coordinates(1, :);
b2 = coordinates(3, :) - coordinates(2, :);
b3 = coordinates(4, :) - coordinates(3, :);
if norm(b2) <= eps
    error("KSSOLV:Modeling:ZeroLengthGeometry", ...
        "The central dihedral bond has zero length.");
end
n1 = cross(b1, b2); n2 = cross(b2, b3);
if norm(n1) <= eps || norm(n2) <= eps
    error("KSSOLV:Modeling:UndefinedDihedral", ...
        "Dihedral is undefined for collinear atoms.");
end
n1 = n1 / norm(n1); n2 = n2 / norm(n2); b2 = b2 / norm(b2);
angle = atan2d(dot(cross(n1, n2), b2), dot(n1, n2));
end

function value = isPeriodicModel(model)
value = isa(model, "kssolv.analysis.matgenlab.core.IStructure") && ...
    any(model.pbc);
end

function vector = minimumImageDisplacement(model, first, second)
vector = model(second).coords - model(first).coords;
if ~isPeriodicModel(model), return, end
fractional = model.lattice.get_fractional_coords(vector);
fractional(model.pbc) = ...
    fractional(model.pbc) - round(fractional(model.pbc));
vector = model.lattice.get_cartesian_coords(fractional);
end

function coordinates = unwrappedChain(model, indices)
coordinates = zeros(numel(indices), 3);
coordinates(1, :) = model(indices(1)).coords;
for position = 2:numel(indices)
    coordinates(position, :) = coordinates(position - 1, :) + ...
        minimumImageDisplacement( ...
        model, indices(position - 1), indices(position));
end
end

function coordinates = geometryReference(model, indices, parameters)
coordinates = [];
if ~isPeriodicModel(model) || ~isfield(parameters, "referenceCoordinates")
    return
end
coordinates = double(parameters.referenceCoordinates);
if ~isequal(size(coordinates), [numel(indices), 3]) || ...
        any(~isfinite(coordinates), "all")
    error("KSSOLV:Modeling:GeometryReference", ...
        "Reference coordinates must be one finite Cartesian row per selected atom.");
end
end

function [point, errorValue] = bestAnglePoint(coordinates, target, axis)
current = vectorAngle(coordinates(1, :) - coordinates(2, :), ...
    coordinates(3, :) - coordinates(2, :));
amount = deg2rad(abs(target - current));
candidates = [
    rotatePoint(coordinates(3, :), coordinates(2, :), axis, amount)
    rotatePoint(coordinates(3, :), coordinates(2, :), axis, -amount)
    ];
errors = zeros(2, 1);
for index = 1:2
    errors(index) = abs(vectorAngle( ...
        coordinates(1, :) - coordinates(2, :), ...
        candidates(index, :) - coordinates(2, :)) - target);
end
[errorValue, selected] = min(errors);
point = candidates(selected, :);
end

function [point, errorValue] = bestDihedralPoint(coordinates, target, axis)
current = signedDihedral(coordinates);
amount = deg2rad(wrap180(target - current));
candidates = [
    rotatePoint(coordinates(4, :), coordinates(2, :), axis, amount)
    rotatePoint(coordinates(4, :), coordinates(2, :), axis, -amount)
    ];
errors = zeros(2, 1);
for index = 1:2
    trial = coordinates;
    trial(4, :) = candidates(index, :);
    errors(index) = abs(wrap180(signedDihedral(trial) - target));
end
[errorValue, selected] = min(errors);
point = candidates(selected, :);
end

function point = rotatePoint(point, anchor, axis, angle)
axis = reshape(double(axis), 1, 3);
axis = axis / norm(axis);
skew = [0, -axis(3), axis(2); ...
    axis(3), 0, -axis(1); -axis(2), axis(1), 0];
rotation = eye(3) + sin(angle) * skew + ...
    (1 - cos(angle)) * (skew * skew);
point = (point - anchor) * rotation.' + anchor;
end

function model = unwrapMovingAnchor(model, moving, fixed, anchor)
if ~isPeriodicModel(model), return, end
direct = model(anchor).coords - model(fixed).coords;
nearest = minimumImageDisplacement(model, fixed, anchor);
model = translateModel(model, moving, nearest - direct, false);
end

function [model, coordinates] = unwrapSelection(model, indices)
coordinates = model.cart_coords(indices, :);
if ~isPeriodicModel(model), return, end
reference = model(indices(1)).coords;
for position = 2:numel(indices)
    coordinates(position, :) = reference + ...
        minimumImageDisplacement(model, indices(1), indices(position));
    model = translateModel(model, indices(position), ...
        coordinates(position, :) - model(indices(position)).coords, false);
end
end

function model = translateModel(model, indices, vector, toUnitCell)
if isa(model, "kssolv.analysis.matgenlab.core.IMolecule")
    model = model.translate_sites(indices, vector);
else
    model = model.translate_sites(indices, vector, ...
        frac_coords = false, to_unit_cell = toUnitCell);
end
end

function model = rotateModel(model, indices, angle, axis, anchor)
if isa(model, "kssolv.analysis.matgenlab.core.IMolecule")
    model = model.rotate_sites(indices, angle, axis, anchor);
else
    model = model.rotate_sites(indices, angle, axis, anchor, true);
end
end

function indices = movingSet(model, fixed, moving, parameters)
scope = lower(string(kssolv.modeling.ParameterUtils.get( ...
    parameters, "scope", "subtree")));
if isPeriodicModel(model)
    if ~any(scope == ["atom", "subtree", "fragment"])
        error("KSSOLV:Modeling:GeometryScope", ...
            "Unsupported geometry scope '%s'.", scope);
    end
    indices = moving;
    return
end
switch scope
    case "atom"
        indices = moving;
    case {"subtree", "fragment"}
        bonds = kssolv.modeling.chemistry.MoleculeDiagnostics.topology(model);
        adjacency = false(model.num_sites);
        for row = 1:size(bonds, 1)
            adjacency(bonds(row, 1), bonds(row, 2)) = true;
            adjacency(bonds(row, 2), bonds(row, 1)) = true;
        end
        adjacency(fixed, moving) = false; adjacency(moving, fixed) = false;
        indices = breadthFirst(adjacency, moving);
        if any(indices == fixed)
            % Rings cannot be split by one bond; fall back to the explicit atom.
            indices = moving;
        end
    otherwise
        error("KSSOLV:Modeling:GeometryScope", ...
            "Geometry scope must be atom, subtree, or fragment.");
end
end

function visited = breadthFirst(adjacency, start)
seen = false(1, size(adjacency, 1)); seen(start) = true; queue = start;
while ~isempty(queue)
    current = queue(1); queue(1) = [];
    next = find(adjacency(current, :) & ~seen);
    seen(next) = true; queue = [queue, next]; %#ok<AGROW>
end
visited = find(seen);
end

function vector = perpendicular(input)
input = input / max(norm(input), eps); reference = [1, 0, 0];
if abs(dot(input, reference)) > 0.9, reference = [0, 1, 0]; end
vector = cross(input, reference); vector = vector / norm(vector);
end

function [axis, angle] = alignmentRotation(source, target)
source = source / norm(source); target = target / norm(target);
axis = cross(source, target); sine = norm(axis); cosine = dot(source, target);
if sine <= 1e-12
    if cosine >= 0, axis = [1, 0, 0]; angle = 0;
    else, axis = perpendicular(source); angle = pi;
    end
else
    axis = axis / sine; angle = atan2(sine, cosine);
end
end

function value = wrap180(value)
value = mod(value + 180, 360) - 180;
end

function model = cleanRuleBased(model, iterations)
bonds = kssolv.modeling.chemistry.MoleculeDiagnostics.topology(model);
for iteration = 1:iterations
    for row = 1:size(bonds, 1)
        first = bonds(row, 1); second = bonds(row, 2);
        moving = movingSet(model, first, second, struct("scope", "subtree"));
        firstPoint = model(first).coords; secondPoint = model(second).coords;
        vector = secondPoint - firstPoint;
        if norm(vector) <= eps, vector = [1, 0, 0]; end
        ideal = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
            idealBondLength(model(first).specie.symbol, ...
            model(second).specie.symbol, bonds(row, 3));
        correction = 0.65 * (firstPoint + ideal * vector / norm(vector) - ...
            secondPoint);
        model = model.translate_sites(moving, correction);
    end
end
end
