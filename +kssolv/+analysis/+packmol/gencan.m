function [x, f, g, output] = gencan(fun, x0, lower, upper, options)
%GENCAN Bound-constrained active-set optimizer used by MATLAB Packmol.
%
% This is a MATLAB implementation of the GENCAN design used by Packmol:
% projected-gradient active sets, safeguarded spectral/quasi-Newton steps,
% and a non-monotone Armijo line search. Its public signature exposes the
% quantities passed through Packmol's pgencan/easygencan interface.
arguments
    fun (1,1) function_handle
    x0 (:,1) double
    lower (:,1) double
    upper (:,1) double
    options.MaxIterations (1,1) double {mustBeInteger,mustBePositive} = 20
    options.MaxFunctionEvaluations (1,1) double ...
        {mustBeInteger,mustBePositive} = 200
    options.OptimalityTolerance (1,1) double {mustBePositive} = 1e-6
    options.Memory (1,1) double {mustBeInteger,mustBePositive} = 10
    options.NonmonotoneWindow (1,1) double ...
        {mustBeInteger,mustBePositive} = 10
end
if numel(x0) ~= numel(lower) || numel(x0) ~= numel(upper) || ...
        any(lower > upper)
    error("KSSOLV:Packmol:GENCANBounds", ...
        "GENCAN bounds do not match the variable vector.");
end
x = min(max(x0, lower), upper);
[f, g] = fun(x);
evaluations = 1;
history = f;
sMemory = zeros(numel(x), 0);
yMemory = zeros(numel(x), 0);
rhoMemory = zeros(0, 1);
status = "maximum iterations reached";
iteration = 0;

for iteration = 1:options.MaxIterations
    projected = projectedGradient(x, g, lower, upper);
    optimality = norm(projected, Inf);
    if optimality <= options.OptimalityTolerance
        status = "projected-gradient tolerance satisfied";
        break
    end
    direction = -twoLoop(projected, sMemory, yMemory, rhoMemory);
    direction((x <= lower & direction < 0) | ...
              (x >= upper & direction > 0)) = 0;
    if dot(direction, g) >= -1e-14 * norm(direction) * max(norm(g), 1)
        direction = -projected;
    end
    maximumStep = feasibleStep(x, direction, lower, upper);
    if maximumStep <= 0 || ~isfinite(maximumStep)
        maximumStep = 1;
    else
        maximumStep = min(maximumStep, 1);
    end
    reference = max(history(max(1, end - ...
        options.NonmonotoneWindow + 1):end));
    slope = dot(g, direction);
    step = maximumStep;
    accepted = false;
    while evaluations < options.MaxFunctionEvaluations
        trial = min(max(x + step * direction, lower), upper);
        [trialF, trialG] = fun(trial);
        evaluations = evaluations + 1;
        if isfinite(trialF) && trialF <= reference + 1e-4 * step * slope
            accepted = true;
            break
        end
        step = step / 2;
        if step <= 1e-16
            break
        end
    end
    if ~accepted
        status = "line search failed";
        break
    end
    s = trial - x;
    y = trialG - g;
    curvature = dot(s, y);
    if curvature > 1e-12 * norm(s) * max(norm(y), eps)
        if size(sMemory, 2) == options.Memory
            sMemory(:, 1) = [];
            yMemory(:, 1) = [];
            rhoMemory(1) = [];
        end
        sMemory(:, end + 1) = s; %#ok<AGROW>
        yMemory(:, end + 1) = y; %#ok<AGROW>
        rhoMemory(end + 1, 1) = 1 / curvature; %#ok<AGROW>
    end
    x = trial;
    f = trialF;
    g = trialG;
    history(end + 1, 1) = f; %#ok<AGROW>
    if evaluations >= options.MaxFunctionEvaluations
        status = "maximum function evaluations reached";
        break
    end
end
projected = projectedGradient(x, g, lower, upper);
output = struct( ...
    "iterations", iteration, ...
    "function_evaluations", evaluations, ...
    "first_order_optimality", norm(projected, Inf), ...
    "status", status, ...
    "objective_history", history);
end

function projected = projectedGradient(x, gradient, lower, upper)
projected = x - min(max(x - gradient, lower), upper);
end

function value = twoLoop(q, sMemory, yMemory, rhoMemory)
count = size(sMemory, 2);
alpha = zeros(count, 1);
value = q;
for i = count:-1:1
    alpha(i) = rhoMemory(i) * dot(sMemory(:, i), value);
    value = value - alpha(i) * yMemory(:, i);
end
if count > 0
    yy = dot(yMemory(:, end), yMemory(:, end));
    if yy > 0
        value = value * ...
            (dot(sMemory(:, end), yMemory(:, end)) / yy);
    end
end
for i = 1:count
    beta = rhoMemory(i) * dot(yMemory(:, i), value);
    value = value + sMemory(:, i) * (alpha(i) - beta);
end
end

function step = feasibleStep(x, direction, lower, upper)
steps = Inf(size(x));
positive = direction > 0;
negative = direction < 0;
steps(positive) = (upper(positive) - x(positive)) ./ direction(positive);
steps(negative) = (lower(negative) - x(negative)) ./ direction(negative);
step = min(steps);
end
