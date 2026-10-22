function verifyCPUBackend(coreDirectory)
%VERIFYCPUBACKEND Check CPU specialization numerically without starting a UI.
assert(~usejava('jvm'), 'CPU backend verification requires -nojvm.');
originalPath = path;
cleanup = onCleanup(@() path(originalPath));
addpath(coreDirectory);
KSSOLV.startup();
assert(isempty(which('lobpcg_gpu')), 'GPU solver is present in the CPU source snapshot.');
settings = options.SCF();
assert(~settings.enableGPU);
warningState = warning('off', 'KSSOLV:Options:ParallelComputing');
warningCleanup = onCleanup(@() warning(warningState));
settings.enableGPU = true;
assert(~settings.enableGPU, 'CPU distribution must refuse GPU computation.');
values = randn(4, 5, 6, 2);
wave = Wavefun(values);
joined = [wave, wave];
assert(norm(joined.psi - [wave.psi, wave.psi], 'fro') == 0);
roundtrip = ifft3(fft3(wave));
assert(norm(roundtrip.psi - wave.psi, 'fro') < 1e-10);
molecule = Molecule('supercell', eye(3)*10, 'atomlist', Atom('H'), ...
    'xyzlist', [0 0 0], 'ecut', 10);
transform = KSFFT(molecule);
coefficients = randn(numel(transform.idxnz), 2);
roundtrip = transform * (transform' * coefficients);
assert(norm(roundtrip - coefficients, 'fro') < 1e-10);
fprintf('PASS: CPU GPU rejection, wavefunction concatenation, FFT and compact FFT roundtrips; JVM disabled.\n');
end
