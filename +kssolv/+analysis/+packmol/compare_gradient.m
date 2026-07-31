function report = compare_gradient(system, x, options)
%COMPARE_GRADIENT Reproduce Packmol's chkgrad finite-difference audit.
arguments
    system (1,1) struct
    x (:,1) double
    options.WriteLog (1,1) logical = true
    options.LogFile {mustBeTextScalar} = "chkgrad.log"
end

[objective, analytical] = ...
    kssolv.analysis.packmol.evaluate(system, x);
count = numel(x);
discrete = zeros(count, 1);
errors = zeros(count, 1);
bestSteps = zeros(count, 1);
for component = 1:count
    bestError = Inf;
    bestDiscrete = NaN;
    bestStep = NaN;
    step = 1.0e-2;
    while bestError > 1.0e-6 && step >= 1.0e-20
        plus = x;
        minus = x;
        plus(component) = plus(component) + step;
        minus(component) = minus(component) - step;
        numerical = ( ...
            kssolv.analysis.packmol.evaluate(system, plus) - ...
            kssolv.analysis.packmol.evaluate(system, minus)) / (2 * step);
        if min(abs(analytical(component)), abs(numerical)) > 1.0e-10
            candidateError = abs( ...
                (numerical - analytical(component)) / ...
                analytical(component));
        else
            candidateError = abs(numerical - analytical(component));
        end
        if candidateError < bestError
            bestError = candidateError;
            bestDiscrete = numerical;
            bestStep = step;
        end
        step = step / 10;
    end
    discrete(component) = bestDiscrete;
    errors(component) = bestError;
    bestSteps(component) = bestStep;
end
[maximumError, worstComponent] = max(errors);
report = struct( ...
    "objective", objective, ...
    "analytical", analytical, ...
    "discrete", discrete, ...
    "error", errors, ...
    "best_step", bestSteps, ...
    "worst_component", worstComponent, ...
    "maximum_error", maximumError);

if options.WriteLog
    filename = string(options.LogFile);
    if ~isAbsolutePath(filename)
        filename = fullfile(system.config.working_directory, filename);
    end
    [fileId, message] = fopen(filename, "w");
    if fileId < 0
        error("KSSOLV:Packmol:GradientLog", ...
            "Unable to open gradient log '%s': %s", filename, message);
    end
    cleanup = onCleanup(@() fclose(fileId));
    fprintf(fileId, " Function Value = %24.16E\n", objective);
    fprintf(fileId, ...
        " Component     Analytical       Discrete          Error     Best step\n");
    for component = 1:count
        fprintf(fileId, "%10d  %13.7E  %13.7E  %13.7E  %13.7E\n", ...
            component, analytical(component), discrete(component), ...
            errors(component), bestSteps(component));
    end
    fprintf(fileId, " Maximum difference = %d Error= %13.7E\n", ...
        worstComponent, maximumError);
    clear cleanup
end
end

function tf = isAbsolutePath(path)
value = char(string(path));
if ispc
    tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(value, "\\");
else
    tf = startsWith(value, "/");
end
end
