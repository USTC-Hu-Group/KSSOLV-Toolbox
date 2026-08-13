classdef GeometryOptimizer
    %GEOMETRYOPTIMIZER Deterministic backtracking molecular minimizer.

    methods (Static)
        function [model, analysis] = optimize(model, options)
            arguments
                model
                options.MaximumIterations (1,1) double = 200
                options.ForceTolerance (1,1) double = 1e-3
                options.FixedIndices double = zeros(1, 0)
                options.InitialStep (1,1) double = 0.05
                options.CancelFcn = []
                options.ForceFieldEvaluator = []
            end
            validateOptions(model, options);
            coordinates = model.cart_coords;
            fixed = unique(reshape(double(options.FixedIndices), 1, []));
            movable = true(model.num_sites, 1); movable(fixed) = false;
            state = evaluateForceField( ...
                model, coordinates, options.ForceFieldEvaluator);
            initialState = state;
            trace = nan(options.MaximumIterations + 1, 1);
            trace(1) = state.energy;
            converged = maximumMovableForce(state.gradient, movable) <= ...
                options.ForceTolerance;
            reason = "force-tolerance";
            iterations = 0;
            displacementHistory = cell(7, 1);
            gradientHistory = cell(7, 1);
            historyCount = 0;

            while ~converged && iterations < options.MaximumIterations
                if shouldCancel(options.CancelFcn)
                    reason = "cancelled";
                    break
                end
                gradient = state.gradient;
                gradient(~movable, :) = 0;
                direction = lbfgsDirection(gradient, ...
                    displacementHistory(1:historyCount), ...
                    gradientHistory(1:historyCount));
                directionalDerivative = sum(gradient .* direction, "all");
                if directionalDerivative >= 0
                    historyCount = 0;
                    direction = -gradient;
                    directionalDerivative = -sum(gradient.^2, "all");
                end
                maximumDisplacement = max(vecnorm(direction, 2, 2));
                if maximumDisplacement > options.InitialStep
                    direction = direction * ...
                        (options.InitialStep / maximumDisplacement);
                    directionalDerivative = ...
                        sum(gradient .* direction, "all");
                end
                step = 1;
                accepted = false;
                for trial = 1:32
                    candidate = coordinates + step * direction;
                    candidateState = evaluateForceField( ...
                        model, candidate, options.ForceFieldEvaluator);
                    decrease = 1e-4 * step * directionalDerivative;
                    if candidateState.energy <= state.energy + decrease
                        accepted = true;
                        break
                    end
                    step = 0.5 * step;
                end
                if ~accepted
                    reason = "line-search-failed";
                    break
                end
                newGradient = candidateState.gradient;
                newGradient(~movable, :) = 0;
                displacement = candidate - coordinates;
                gradientChange = newGradient - gradient;
                curvature = sum(displacement .* gradientChange, "all");
                curvatureScale = norm(displacement, "fro") * ...
                    norm(gradientChange, "fro");
                if curvature > 1e-10 * max(curvatureScale, eps)
                    if historyCount < 7
                        historyCount = historyCount + 1;
                    else
                        displacementHistory(1:6) = ...
                            displacementHistory(2:7);
                        gradientHistory(1:6) = gradientHistory(2:7);
                    end
                    displacementHistory{historyCount} = displacement;
                    gradientHistory{historyCount} = gradientChange;
                end
                coordinates = candidate;
                state = candidateState;
                iterations = iterations + 1;
                trace(iterations + 1) = state.energy;
                converged = maximumMovableForce(state.gradient, movable) <= ...
                    options.ForceTolerance;
            end
            if ~converged && iterations >= options.MaximumIterations
                reason = "maximum-iterations";
            end
            for index = 1:model.num_sites
                model = model.replace(index, [], coordinates(index, :));
            end
            analysis = struct( ...
                "method", "deterministic-lbfgs-backtracking", ...
                "isEnergyMinimization", true, ...
                "forceField", state.parameterSet, ...
                "forceFieldSource", state.source, ...
                "parameterSchemaVersion", stateField(state, ...
                    "parameterSchemaVersion", NaN), ...
                "parameterSource", stateField(state, ...
                    "parameterSource", "external evaluator"), ...
                "initialEnergy", initialState.energy, ...
                "finalEnergy", state.energy, ...
                "energyUnit", state.energyUnit, ...
                "maximumForce", maximumMovableForce( ...
                    state.gradient, movable), ...
                "forceUnit", state.gradientUnit, ...
                "iterations", iterations, ...
                "converged", converged, ...
                "reason", reason, ...
                "fixedIndices", fixed, ...
                "fallbackCount", state.fallbackCount, ...
                "fallbackByKind", stateField(state, ...
                    "fallbackByKind", struct()), ...
                "parameterCount", stateField(state, ...
                    "parameterCount", struct()), ...
                "termEnergy", state.termEnergy, ...
                "termCount", state.termCount, ...
                "limitations", state.limitations, ...
                "energyTrace", trace(1:iterations + 1));
        end
    end
end

function direction = lbfgsDirection(gradient, displacements, changes)
count = numel(displacements);
if count == 0
    direction = -gradient;
    return
end
query = gradient;
alpha = zeros(count, 1);
rho = zeros(count, 1);
for index = count:-1:1
    rho(index) = 1 / sum(displacements{index} .* changes{index}, "all");
    alpha(index) = rho(index) * ...
        sum(displacements{index} .* query, "all");
    query = query - alpha(index) * changes{index};
end
latestDisplacement = displacements{end};
latestChange = changes{end};
scale = sum(latestDisplacement .* latestChange, "all") / ...
    max(sum(latestChange.^2, "all"), eps);
result = max(scale, eps) * query;
for index = 1:count
    beta = rho(index) * sum(changes{index} .* result, "all");
    result = result + displacements{index} * (alpha(index) - beta);
end
direction = -result;
end

function validateOptions(model, options)
if options.MaximumIterations < 1 || ...
        options.MaximumIterations ~= fix(options.MaximumIterations)
    error("KSSOLV:Modeling:OptimizerIterations", ...
        "Maximum iterations must be a positive integer.");
end
if ~isfinite(options.ForceTolerance) || options.ForceTolerance <= 0
    error("KSSOLV:Modeling:OptimizerTolerance", ...
        "Force tolerance must be a positive finite scalar.");
end
if ~isfinite(options.InitialStep) || options.InitialStep <= 0
    error("KSSOLV:Modeling:OptimizerStep", ...
        "Initial step must be a positive finite scalar.");
end
if ~isempty(options.ForceFieldEvaluator) && ...
        ~isa(options.ForceFieldEvaluator, "function_handle")
    error("KSSOLV:Modeling:ForceFieldEvaluator", ...
        "ForceFieldEvaluator must be a function handle.");
end
fixed = double(options.FixedIndices);
if any(fixed ~= fix(fixed)) || any(fixed < 1) || ...
        any(fixed > model.num_sites)
    error("KSSOLV:Modeling:OptimizerFixedIndex", ...
        "Fixed atom indices must reference existing atoms.");
end
end

function state = evaluateForceField(model, coordinates, evaluator)
state = kssolv.modeling.forcefield.ForceFieldProvider.evaluate( ...
    model, coordinates, evaluator);
end

function value = stateField(state, name, defaultValue)
if isfield(state, name)
    value = state.(name);
else
    value = defaultValue;
end
end

function value = maximumMovableForce(gradient, movable)
if ~any(movable)
    value = 0;
else
    value = max(vecnorm(gradient(movable, :), 2, 2));
end
end

function value = shouldCancel(callback)
value = false;
if isempty(callback), return, end
if ~isa(callback, "function_handle")
    error("KSSOLV:Modeling:OptimizerCancelCallback", ...
        "CancelFcn must be a function handle.");
end
value = logical(callback());
if ~isscalar(value)
    error("KSSOLV:Modeling:OptimizerCancelCallback", ...
        "CancelFcn must return a scalar logical value.");
end
end
