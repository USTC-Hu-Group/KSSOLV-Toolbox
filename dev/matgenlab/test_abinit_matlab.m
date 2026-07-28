function test_abinit_matlab()
%TEST_ABINIT_MATLAB Native MATLAB regression for the frozen ABINIT surface.
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
fixtures = "/tmp/pymatgen-core-upstream/test-files/io/abinit";
assert(isfolder(fixtures), "Frozen pymatgen ABINIT fixtures are unavailable.");
import kssolv.analysis.matgenlab.io.abinit.*

% variable + abiobjects
variable = InputVariable("ngkpt", [4 4 4]);
assert(contains(string(variable), "ngkpt 4 4 4"));
spin = SpinMode.as_spinmode("polarized");
assert(spin.nsppol == 2 && spin.nspden == 2 && spin.nspinor == 1);
smear = Smearing.as_smearing("fermi_dirac:1 eV");
assert(abs(smear.tsmear - 1 / 27.211386245988) < 1e-12);
sampling = KSampling.monkhorst([2 2 2], [.5 .5 .5]);
assert(all(sampling.to_abivars().ngkpt == [2 2 2]));
assert(RelaxationMethod.atoms_and_cell().move_cell);
assert(abs(PPModel.as_ppmodel("godby:12 eV").plasmon_freq - ...
    12 / 27.211386245988) < 1e-12);

% NC and PAW pseudopotentials.
tm = Pseudo.from_file(fullfile(fixtures, "14si.pspnc"));
hgh = Pseudo.from_file(fullfile(fixtures, "14si.4.hgh"));
fhi = Pseudo.from_file(fullfile(fixtures, "14-Si.LDA.fhi"));
ge = Pseudo.from_file(fullfile(fixtures, "ge.oncvpsp"));
pb = Pseudo.from_file(fullfile(fixtures, "Pb-d-3_r.psp8"));
oxygen = Pseudo.from_file(fullfile(fixtures, "O.GGA_PBE-JTH-paw.xml"));
assert(tm.has_nlcc && tm.l_max == 2 && tm.l_local == 2);
assert(~hgh.has_nlcc && hgh.l_max == 1 && hgh.l_local == 0);
assert(~fhi.has_nlcc && fhi.l_max == 3 && fhi.l_local == 2);
assert(ge.Z == 32 && ge.Z_val == 4 && ~ge.supports_soc);
assert(pb.Z == 82 && pb.Z_val == 14 && pb.supports_soc);
assert(oxygen.Z == 8 && oxygen.core == 2 && oxygen.valence == 6);
assert(abs(oxygen.paw_radius - 1.4146523028) < 1e-10);
assert(numel(oxygen.ae_core_density.mesh) == ...
    numel(oxygen.ae_core_density.values));
assert(strlength(tm.md5) == 32);
roundtrip = Pseudo.from_dict(tm.as_dict());
assert(roundtrip.md5 == tm.md5);
tableOfPseudos = PseudoTable({tm, hgh, fhi});
assert(length(tableOfPseudos) == 3 && tableOfPseudos.allnc);
assert(length(tableOfPseudos(14)) == 3);

% Input factories.
structure = kssolv.analysis.matgenlab.core.Structure.from_file( ...
    fullfile(fixtures, "si.cif"));
input = BasicAbinitInput(structure, tm);
assert(num_valence_electrons(input.structure, input.pseudos) == 8);
input.set_kmesh([1 2 3], [1 2 3 4 5 6]);
assert(input("nshiftk") == 2);
input.set_gamma_sampling();
assert(input("nshiftk") == 1 && all(input("shiftk") == 0, "all"));
input.set_kpath(3);
assert(numel(input("kptbounds")) == 12);
groundState = gs_input(structure, tm, "kppa", 10, "ecut", 10, ...
    "spin_mode", "polarized");
assert(groundState("nsppol") == 2 && groundState("nband") == 14);
assert(all(groundState("ngkpt") == [2 2 2]));
bands = ebands_input(structure, tm, "kppa", 10, "ecut", 2);
assert(bands.ndtset == 2);
relax = ion_ioncell_relax_input(structure, tm, "kppa", 10, "ecut", 2);
firstRelax = relax(1);
secondRelax = relax(2);
assert(firstRelax("ionmov") == 3 && firstRelax("optcell") == 0);
assert(secondRelax("ionmov") == 3 && secondRelax("optcell") == 2);

% ETSF NetCDF.
reader = EtsfReader(fullfile(fixtures, "Si2_GSR.nc"));
cleanup = onCleanup(@() reader.close()); %#ok<NASGU>
assert(reader.ngroups == 1);
assert(reader.read_dimvalue("number_of_spins") == 1);
assert(reader.read_value("space_group") == 227);
assert(abs(reader.read_value("etotal") + 8.85911566912484) < 1e-12);
ncStructure = reader.read_structure();
assert(ncStructure.num_sites == 2);
assert(reader.chemical_symbols == "Si");
assert(reader.read_abinit_hdr().natom == 2);

% ABINIT timing output.
parser = AbinitTimerParser();
parsed = parser.parse(fullfile(fixtures, "mgb2_scf.abo"));
assert(numel(parsed) == 1);
timers = parser.timers();
timer = timers{1};
assert(abs(timer.cpu_time - 5.1) < 1e-12);
assert(numel(timer.sections) == 30);
assert(abs(timer.sum_sections("cpu_time") - 3.299) < 1e-9);
assert(height(timer.get_dataframe()) == 30);

parser2 = AbinitTimerParser();
assert(numel(parser2.parse(fullfile(fixtures, "si_scf_v10.2.7.abo"))) == 1);
timers2 = parser2.timers();
assert(abs(timers2{1}.cpu_time - 0.3) < 1e-12);
assert(abs(timers2{1}.sum_sections("cpu_time") - 0.307) < 1e-9);
end
