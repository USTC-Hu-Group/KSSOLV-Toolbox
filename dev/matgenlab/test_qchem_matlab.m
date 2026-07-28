function test_qchem_matlab(upstreamRoot)
%TEST_QCHEM_MATLAB Official-fixture regression for the native Q-Chem port.
if nargin < 1
    upstreamRoot = "/tmp/pymatgen-core-upstream";
end
addpath(fileparts(fileparts(fileparts(mfilename("fullpath")))));
fixture = fullfile(upstreamRoot, "test-files", "io", "qchem");
input = kssolv.analysis.matgenlab.io.qchem.QCInput.from_file( ...
    fullfile(fixture, "test_ref.qin"));
roundtrip = kssolv.analysis.matgenlab.io.qchem.QCInput.from_str(input.get_str());
assert(strcmp(input.get_str(), roundtrip.get_str()));
jobs = kssolv.analysis.matgenlab.io.qchem.QCInput.multi_job_string({input, input});
assert(numel(regexp(jobs, "@@@", "match")) == 1);
kssolv.analysis.matgenlab.internal.TypeRegistry.clear();
decoded = kssolv.analysis.matgenlab.util.decode( ...
    kssolv.analysis.matgenlab.util.encode(input));
assert(strcmp(input.get_str(), decoded.get_str()));

single = kssolv.analysis.matgenlab.io.qchem.QCOutput( ...
    fullfile(fixture, "6.1.1.wb97xv.out.gz"));
assert(abs(single.data.final_energy + 76.43205015) < 1e-8);
scan = kssolv.analysis.matgenlab.io.qchem.QCOutput( ...
    fullfile(fixture, "new_qchem_files", "pes_scan_single_variable.qout"));
assert(numel(scan.data.scan_energies) == 41);
frequency = kssolv.analysis.matgenlab.io.qchem.QCOutput( ...
    fullfile(fixture, "new_qchem_files", "Frequency_no_equal.qout"));
assert(~isempty(frequency.data.frequencies));
isosvp = kssolv.analysis.matgenlab.io.qchem.QCOutput( ...
    fullfile(fixture, "new_qchem_files", "isosvp_water_single.qcout"));
assert(abs(isosvp.data.solvent_data.isosvp.isosvp_dielectric - 78.39) < 1e-8);
cmirs = kssolv.analysis.matgenlab.io.qchem.QCOutput( ...
    fullfile(fixture, "new_qchem_files", "cmirs_benzene_single.qcout"));
assert(cmirs.data.solvent_data.cmirs.CMIRS_enabled);
nbo = kssolv.analysis.matgenlab.io.qchem.nbo_parser( ...
    fullfile(fixture, "new_qchem_files", "nbo.qout"));
assert(numel(nbo.natural_populations) == 3);
assert(numel(nbo.hybridization_character) == 6);
assert(numel(nbo.perturbation_energy) == 2);
assert(abs(nbo.natural_populations{1}.Density(6) + 0.08624) < 1e-8);

gradient = kssolv.analysis.matgenlab.io.qchem.gradient_parser( ...
    fullfile(fixture, "131.0.gz"));
hessian = kssolv.analysis.matgenlab.io.qchem.hessian_parser( ...
    fullfile(fixture, "132.0.gz"), 14);
coefficients = kssolv.analysis.matgenlab.io.qchem.orbital_coeffs_parser( ...
    fullfile(fixture, "53.0.gz"));
assert(isequal(size(gradient), [14, 3]));
assert(isequal(size(hessian), [42, 42]));
assert(numel(coefficients) == 360400);

set = kssolv.analysis.matgenlab.io.qchem.OptSet(input.molecule, ...
    "pcm_dielectric", 10);
assert(strcmp(set.rem.solvent_method, "pcm"));
files = dir(fullfile(fileparts(which( ...
    "kssolv.analysis.matgenlab.io.qchem.QCInput")), "*.m"));
for index = 1:numel(files)
    assert(isempty(checkcode(fullfile(files(index).folder, files(index).name), "-id")));
end
end
