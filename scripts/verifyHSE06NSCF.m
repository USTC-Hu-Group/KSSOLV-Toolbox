function results = verifyHSE06NSCF(outputDirectory)
%VERIFYHSE06NSCF Exercise workflow NSCF options on a two-atom HSE06 crystal.
% Run with MATLAB -nojvm -batch "addpath('scripts'); verifyHSE06NSCF('/tmp/hse06')".
% Numerical failures are recorded for review without changing solver settings.
arguments
    outputDirectory (1, :) char
end

assert(~usejava('jvm'), 'Run this verification with MATLAB -nojvm.');
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
diary(fullfile(outputDirectory, 'verification.log'));
diaryCleanup = onCleanup(@() diary('off'));
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath));
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, '+kssolv', '+core', 'kssolv-3o'));
KSSOLV.startup();
rng(7, 'twister');

% A small periodic H2 cell, two bands and a single Gamma-X path (3 points).
crystal = Crystal('name', 'H2 HSE06 NSCF smoke test', ...
    'supercell', 8 * eye(3), 'atomlist', repmat(Atom('H'), 1, 2), ...
    'xyzlist', [4 4 3.25; 4 4 4.75], 'ecut', 10, ...
    'nbnd', 2, 'funct', 'HSE06', 'autokpts', [1 1 1 0 0 0]);
context = containers.Map('KeyType', 'char', 'ValueType', 'any');
context('molecule') = crystal;
results = struct('jvmEnabled', usejava('jvm'), 'atoms', 2, ...
    'bandPoints', 3, 'scf', struct(), 'serial', struct(), ...
    'parallel', struct(), 'maxDifferenceEV', []);

try
    context = kssolv.services.workflow.module.computation.SCFTask. ...
        executeWithOptions(context, struct('maxscfiter', 100, ...
        'maxphiiter', 30, 'scftol', 1e-8, 'phitol', 1e-8, ...
        'enableParallelPool', false));
    results.scf.passed = true;
catch exception
    results.scf = recordFailure(exception);
    saveResults(outputDirectory, results);
    return
end

taskOptions = struct('eigmethod', 'lobpcg', 'maxcgiter', 60, ...
    'maxphiiter', 30, 'GACE', false, 'HT', false);
context = kssolv.services.workflow.module.computation.NSCFTask. ...
    executeWithOptions(context, taskOptions);
assert(isequal(context('NSCFOptions').scfX, context('X')));

% Explicit wavefunctions remain authoritative, and PBE does not require X.
explicitOptions = taskOptions;
explicitOptions.scfX = BlochWavefun({zeros(2, 1)});
explicitContext = kssolv.services.workflow.module.computation.NSCFTask. ...
    executeWithOptions(context, explicitOptions);
assert(isequal(explicitContext('NSCFOptions').scfX, explicitOptions.scfX));
pbeContext = containers.Map('KeyType', 'char', 'ValueType', 'any');
pbeCrystal = copy(crystal);
pbeCrystal.funct = 'PBE';
pbeContext('molecule') = pbeCrystal;
pbeContext = kssolv.services.workflow.module.computation.NSCFTask. ...
    executeWithOptions(pbeContext, taskOptions);
assert(isempty(pbeContext('NSCFOptions').scfX));
% Rebuild after the explicit override check (containers.Map is a handle).
context = kssolv.services.workflow.module.computation.NSCFTask. ...
    executeWithOptions(context, taskOptions);

kPoints = {0 0 0 3 'Gamma'; 0.5 0 0 3 'X'};
try
    nscfOptions = context('NSCFOptions');
    nscfOptions.rho0 = context('H').rho;
    nscfOptions.enableParallelPool = false;
    rng(11, 'twister');
    [serialBands, pathPoints] = eband(copy(crystal), nscfOptions, kPoints);
    assert(size(pathPoints, 1) == 3 && isequal(size(serialBands), [2 3]));
    assert(all(isfinite(serialBands), 'all'));
    results.serial = struct('passed', true, 'energyBandsEV', serialBands);
catch exception
    results.serial = recordFailure(exception);
end
saveResults(outputDirectory, results);

% Exercise the workflow's supported process-pool path with explicit limits.
try
    assert(isempty(gcp('nocreate')), 'Use a fresh MATLAB session for this test.');
    resources = struct('ParallelType', 'Processes', ...
        'ProcessCount', 2, 'ThreadCount', 1);
    [poolCleanup, ~] = kssolv.services.workflow.ExecutionResources.prepare( ...
        resources, 'kssolv.services.workflow.module.postprocessing.BandProcessingTask'); %#ok<ASGLU>
    pool = gcp('nocreate');
    assert(isa(pool, 'parallel.ProcessPool') && pool.NumWorkers == 2);
    assert(~any(fetchOutputs(parfevalOnAll(pool, @usejava, 1, 'jvm'))));
    symmetry = struct('path', {{'GAMMA', 'X'}}, ...
        'point_coords', containers.Map({'GAMMA', 'X'}, {[0 0 0], [0.5 0 0]}));
    context('symmetry') = symmetry;
    context('molecule') = copy(crystal);
    rng(11, 'twister');
    context = kssolv.services.workflow.module.postprocessing.BandProcessingTask. ...
        executeWithOptions(context, struct('numInterpolationPoints', 3), resources);
    assert(context('NSCFOptions').enableParallelPool);
    parallelBands = context('bandProcessing').energyBands;
    assert(isequal(size(parallelBands), [2 3]));
    assert(all(isfinite(parallelBands), 'all'));
    results.parallel = struct('passed', true, 'poolType', class(pool), ...
        'workers', pool.NumWorkers, 'energyBandsEV', parallelBands);
    if results.serial.passed
        results.maxDifferenceEV = max(abs(serialBands - parallelBands), [], 'all');
        assert(results.maxDifferenceEV < 1e-6, ...
            'Serial/parallel bands differ by more than 1e-6 eV.');
    end
catch exception
    results.parallel = recordFailure(exception);
end
clear poolCleanup
saveResults(outputDirectory, results);
disp(results);
end

function failure = recordFailure(exception)
report = getReport(exception, 'extended', 'hyperlinks', 'off');
fprintf(2, '%s\n', report);
failure = struct('passed', false, 'identifier', exception.identifier, ...
    'message', exception.message, 'report', report);
end

function saveResults(outputDirectory, results)
save(fullfile(outputDirectory, 'results.mat'), 'results');
writelines(jsonencode(results, PrettyPrint=true), ...
    fullfile(outputDirectory, 'results.json'));
end
