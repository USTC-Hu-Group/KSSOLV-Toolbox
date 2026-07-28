function test_cp2k_matlab()
%TEST_CP2K_MATLAB Native regression for the frozen pymatgen.io.cp2k surface.
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
fixtures = "/tmp/pymatgen-core-upstream/test-files/io/cp2k";
assert(isfolder(fixtures), "Frozen pymatgen CP2K fixtures are unavailable.");
import kssolv.analysis.matgenlab.io.cp2k.*

% Native input grammar, preprocessing, repeated keywords and MSON round-trip.
input = Cp2kInput.from_file(fullfile(fixtures, "cp2k.inp"));
assert(input.check("FORCE_EVAL/DFT/MGRID"));
forceEval = input("FORCE_EVAL");
dft = forceEval("DFT");
mgrid = dft("MGRID");
ngrids = mgrid("NGRIDS");
assert(ngrids.values{1} == 5);
assert(isa(dft("BASIS_SET_FILE_NAME"), ...
    "kssolv.analysis.matgenlab.io.cp2k.KeywordList"));
assert(input.check("INCLUDE"));
include = input("INCLUDE");
assert(include("KEYWORD") == Keyword("KEYWORD", "VALUE"));
roundtrip = Cp2kInput.from_dict(input.as_dict());
assert(strcmp(input.get_str(), roundtrip.get_str()));
scrambled = lower(input.get_str());
scrambledInput = Cp2kInput.from_str(scrambled);
assert(scrambledInput.check("force_eval/dft/mgrid"));

% Atomic basis/potential metadata and CP2K data-file grammar.
basisText = join([ ...
    "H  SZV-MOLOPT-GTH SZV-MOLOPT-GTH-q1"
    "1"
    "2 0 0 7 1"
    "11.478000339908 0.024916243200"
    "3.700758562763 0.079825490000"
    "1.446884268432 0.128862675300"
    "0.716814589696 0.379448894600"
    "0.247918564176 0.324552432600"
    "0.066918004004 0.037148121400"
    "0.021708243634 -0.001125195500"], newline);
basis = GaussianTypeOrbitalBasisSet.from_str(basisText);
assert(basis.nexp == 7);
assert(abs(basis.exponents{1}(1) - 11.478000339908) < 1e-12);
basisFile = BasisFile.from_str(basisText);
assert(numel(basisFile.objects) == 1);
info = BasisInfo.from_str("cc-pc-DZVP-MOLOPT-q1-SCAN");
assert(info.valence == 2 && info.polarization == 1 && ...
    info.electrons == 1 && info.cc && info.pc && info.molopt);
assert(BasisInfo.from_str("cc-pc-DZVP-MOLOPT-q1").softmatch(info));
allElectron = GthPotential.from_str(join( ...
    ["H ALLELECTRON ALL", "1 0 0", "0.2 0"], newline));
assert(allElectron.potential == "All Electron");
allKeyword = allElectron.get_keyword();
assert(allKeyword.values{1} == "ALL");
pseudo = GthPotential.from_str(join( ...
    ["H GTH-PBE-q1 GTH-PBE", "1", ...
    "0.2 2 -4.17890044 0.72446331", "0"], newline));
assert(abs(pseudo.r_loc - 0.2) < 1e-12 && pseudo.nexp_ppl == 2);
assert(max(abs(pseudo.c_exp_ppl - [-4.17890044, 0.72446331])) < 1e-12);

% Official output and companion-file oracle values.
output = Cp2kOutput(fullfile(fixtures, "cp2k.out"), false, true);
assert(output.cp2k_version == "2022.1" && output.completed);
assert(output.num_warnings == 2 && output.spin_polarized);
assert(upper(output.run_type) == "ENERGY_FORCE");
assert(abs(output.final_energy + 197.40000341992783) < 1e-10);
assert(max(abs(output.data.forces{1}(1,:) - [-1e-8, -1e-8, -1e-8])) < 1e-15);
assert(abs(output.band_gap - 0.27940141999999923) < 1e-12);
assert(abs(output.data.tdos.energies(1) + 6.781065751604123) < 1e-12);
assert(abs(output.data.pdos.Si_1.s.efermi + 6.7370756409404455) < 1e-12);
assert(output.initial_structure.num_sites == 2);
output.parse_chi_tensor();
assert(abs(output.data.PV1{1} - 0.1587) < 1e-12);
assert(max(abs(output.data.chi_soft{1}(1,:) - [5.9508, -1.6579, -1.6579])) < 1e-12);
output.parse_gtensor();
assert(abs(output.data.gmatrix_total{1}(1,1) - 2.0023193044) < 1e-12);
assert(abs(output.data.delta_g{1}(1,1) - 0.7158445077) < 1e-12);
output.parse_hyperfine();
hyperfine = output.data.hyperfine_tensor{1};
assert(numel(hyperfine) == 2);
assert(abs(hyperfine{1}(1,2) - 0.0000001288) < 1e-15);
output.parse_atomic_kind_info();
output.parse_total_numbers();
output.parse_mulliken();
output.parse_hirshfeld();
output.parse_mo_eigenvalues();
assert(output.data.atomic_kind_info.Si_1.orbital_basis_set == ...
    "DZVP-MOLOPT-SR-GTH-q4");
assert(output.data.total_numbers.atoms == 2);
assert(all(output.data.mulliken{1}{1}.population == [2, 2]));
assert(abs(output.data.hirshfeld{1}{1}.net_charge) < 1e-12);

% DFT set generation, activators, molecular boundary conditions and validation.
lattice = kssolv.analysis.matgenlab.core.Lattice([ ...
    0, 2.734364, 2.734364; 2.734364, 0, 2.734364; ...
    2.734364, 2.734364, 0]);
structure = kssolv.analysis.matgenlab.core.Structure( ...
    lattice, {"Si", "Si"}, [0, 0, 0; 0.25, 0.25, 0.25]);
setBasis = GaussianTypeOrbitalBasisSet.from_str(basisText);
setBasis.element = kssolv.analysis.matgenlab.core.Element("Si");
setBasis.exponents{1} = [2.693604434572, 1.359613855428, ...
    0.513245176029, 0.326563011394, 0.139986977410, 0.068212286977];
mapping = struct("Si", struct("basis", setBasis, "potential", pseudo));
set = DftSet(structure, "basis_and_potential", mapping, ...
    "xc_functionals", "PBE", "print_pdos", false, ...
    "print_dos", false, "print_v_hartree", false, ...
    "print_e_density", false, "print_mo_cubes", false);
assert(set.cutoff == 150 && set.check("FORCE_EVAL/SUBSYS/Si_1"));
assert(~set.check("MOTION"));
set.activate_motion();
set.print_pdos();
set.print_v_hartree();
set.activate_nmr();
set.activate_epr();
set.activate_hyperfine();
set.activate_polar();
set.activate_tddfpt();
assert(set.check("MOTION"));
assert(set.check("FORCE_EVAL/DFT/PRINT/PDOS"));
assert(set.check("FORCE_EVAL/DFT/PRINT/V_HARTREE_CUBE"));
assert(set.check("FORCE_EVAL/PROPERTIES/LINRES/NMR/PRINT/CHI_TENSOR"));
assert(set.check("FORCE_EVAL/PROPERTIES/LINRES/EPR/PRINT/G_TENSOR"));
assert(set.check("FORCE_EVAL/PROPERTIES/TDDFPT"));
set.activate_hybrid();
assert(set.check("FORCE_EVAL/DFT/XC/HF"));
assert(set.check("FORCE_EVAL/DFT/AUXILIARY_DENSITY_MATRIX_METHOD"));
assert(strlength(string(set.get_str())) > 1000);

molecule = kssolv.analysis.matgenlab.core.Molecule({"Si"}, [0, 0, 0]);
molecularSet = DftSet(molecule, "basis_and_potential", mapping, ...
    "print_dos", false, "print_pdos", false, "print_mo_cubes", false, ...
    "print_v_hartree", false, "print_e_density", false);
assert(molecularSet.check("FORCE_EVAL/DFT/POISSON"));
poisson = molecularSet.by_path("FORCE_EVAL/DFT/POISSON");
periodic = poisson("PERIODIC");
assert(upper(string(periodic.values{1})) == "NONE");

% All production files are accepted by MATLAB's analyzer.
files = dir(fullfile(root, "+kssolv", "+analysis", "+matgenlab", ...
    "+io", "+cp2k", "*.m"));
issues = 0;
for index = 1:numel(files)
    issues = issues + numel(checkcode(fullfile(files(index).folder, ...
        files(index).name), "-id"));
end
assert(issues == 0);
end
