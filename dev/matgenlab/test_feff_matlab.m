function test_feff_matlab()
%TEST_FEFF_MATLAB Native regression for the frozen pymatgen.io.feff surface.
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
fixtures = "/tmp/pymatgen-core-upstream/test-files/io/feff";
cifFile = "/tmp/pymatgen-core-upstream/test-files/cif/CoO19128.cif";
assert(isfolder(fixtures) && isfile(cifFile), ...
    "Frozen pymatgen FEFF fixtures are unavailable.");
import kssolv.analysis.matgenlab.io.feff.*

% Structural header parsing and MSON-style round-trip.
headerText = Header.header_string_from_file(fullfile(fixtures, "HEADER"));
header = Header.from_str(headerText);
assert(header.formula == "Co2 O2");
assert(header.struct.composition.reduced_formula == "CoO");
assert(header.space_group == "Cmc2_1" && header.space_number == 36);
header2 = Header.from_dict(header.as_dict());
assert(strcmp(header.get_str(), header2.get_str()));
cifHeader = Header.from_cif_file(cifFile);
assert(cifHeader.struct.num_sites == 4);

% Atomic cluster, potential, helper functions and compressed input.
structure = kssolv.analysis.matgenlab.core.Structure.from_file(cifFile);
atoms = Atoms(structure, "O", 12);
atomLines = atoms.get_lines();
assert(all(cellfun(@str2double, atomLines(1, 1:3)) == 0));
assert(atomLines{1, 4} == 0 && string(atomLines{1, 5}) == "O");
referenceCluster = Atoms.cluster_from_file(fullfile(fixtures, "ATOMS"));
distances = cellfun(@str2double, atomLines(:, 6));
referenceDistances = referenceCluster.distance_matrix(1, :).';
assert(numel(distances) == numel(referenceDistances));
assert(max(abs(distances - referenceDistances) ./ ...
    max(referenceDistances, eps)) < 2e-5);
assert(Atoms.cluster_from_file(fullfile(fixtures, ...
    "Pt37_atoms.inp.gz")).num_sites == 37);
assert(strcmp(atoms.get_str(), Atoms.from_dict(atoms.as_dict()).get_str()));
[absorber, absorberIndex] = get_absorbing_atom_symbol_index("O", structure);
assert(absorber == "O" && absorberIndex == 3);
atomMap = get_atom_map(atoms.cluster, "O");
assert(atomMap.Co == 1 && atomMap.O == 2);

potentialText = Potential.pot_string_from_file(fullfile(fixtures, "POTENTIALS"));
[forward, reverse] = Potential.pot_dict_from_str(potentialText);
assert(forward.Co == 1 && reverse(0) == "O" && reverse(2) == "O");
potential = Potential(structure, "O", 12);
assert(strcmp(potential.get_str(), ...
    Potential.from_dict(potential.as_dict()).get_str()));
molecule = kssolv.analysis.matgenlab.core.Molecule.from_file( ...
    fullfile(fixtures, "feff_radial_shell.xyz"));
assert(numel(splitlines(string(Potential(molecule, "Zn", 2.2)))) == 5);
assert(~isfield(Atoms(molecule, "Zn", 9).pot_dict, "Zn"));

% Ordered parameter grammar, nested EELS cards, comparison and serialization.
tags = Tags.from_file(fullfile(fixtures, "PARAMETERS"));
assert(tags("COREHOLE") == "Fsr");
assert(max(abs(tags("LDOS") - [-30, 15, 0.1])) < 1e-12);
sameTags = Tags.from_file(fullfile(fixtures, "PARAMETERS.2"));
tagDiff = tags.diff(sameTags);
assert(isempty(fieldnames(tagDiff.Different)));
assert(numel(fieldnames(tagDiff.Same)) == 12);
assert(Tags.from_dict(tags.as_dict()) == tags);
eelsPowder = Tags.from_file(fullfile(fixtures, "feff_eels_powder.inp"));
powder = eelsPowder("ELNES");
assert(string(powder.ENERGY) == "4.0 .04 0.1");
assert(string(powder.BEAM_ENERGY) == "200 1 0 1");
eelsDirected = Tags.from_file(fullfile(fixtures, "feff_eels_x.inp"));
directed = eelsDirected("ELNES");
assert(string(directed.BEAM_DIRECTION) == "1 0 0");

% Scattering-path writer.
paths = Paths(atoms, {[0, 1, 0], [0, 2, 0]}, [2, 3]);
pathText = paths.get_str();
assert(contains(pathText, "9999 3 2"));
assert(contains(pathText, "9998 3 3"));
assert(strcmp(pathText, Paths.from_dict(paths.as_dict()).get_str()));

% Official XMU and LDOS numerical oracles, including reciprocal-space DOS.
xmu = Xmu.from_file(fullfile(fixtures, "xmu.dat"), ...
    fullfile(fixtures, "feff.inp"));
assert(xmu.absorbing_atom == "O");
assert(abs(xmu.e_fermi - 544.964) < 1e-6);
assert(isequal(xmu.data, Xmu.from_dict(xmu.as_dict()).data));
ldos = LDos.from_file(fullfile(fixtures, "feff.inp"), ...
    fullfile(fixtures, "ldos"));
assert(abs(ldos.complete_dos.efermi + 11.430) < 1e-12);
assert(abs(ldos.charge_transfer.x0.O.s - 1.887) < 1e-12);
assert(strcmp(ldos.charge_transfer_to_str(), ...
    LDos.from_dict(ldos.as_dict()).charge_transfer_to_str()));
reciprocalDirectory = fullfile(fixtures, "feff_reci_dos");
reciprocalLdos = LDos.from_file(fullfile(reciprocalDirectory, "feff.inp"), ...
    fullfile(reciprocalDirectory, "ldos"));
assert(abs(reciprocalLdos.complete_dos.efermi + 9.672) < 1e-12);
assert(abs(reciprocalLdos.charge_transfer.x0.Na.s - 0.241) < 1e-12);
assert(abs(reciprocalLdos.charge_transfer.x1.O.tot + 0.594) < 1e-12);
eelsData = [(1:3).', (4:6).', (7:9).', (10:12).'];
eels = Eels(eelsData);
assert(isequal(eels.energies, eelsData(:, 1)));
assert(isequal(Eels.from_dict(eels.as_dict()).fine_structure, eelsData(:, 4)));

% MP input sets, user overrides, reciprocal mode and directory regeneration.
xanes = MPXANESSet("O", structure);
assert(xanes.tags("COREHOLE") == "FSR");
[setForward, setReverse] = Potential.pot_dict_from_str(xanes.potential.get_str());
assert(setForward.Co == 1 && setReverse(0) == "O");
xanesLines = xanes.atoms.get_lines();
assert(xanesLines{1, 4} == 0);
xanesDict = xanes.as_dict();
assert(isequaln(xanesDict, FEFFDictSet.from_dict(xanesDict).as_dict()));
custom = MPXANESSet("O", structure, "user_tag_settings", ...
    struct("COREHOLE", "RPA", "EDGE", "L1"));
assert(custom.tags("COREHOLE") == "RPA" && custom.tags("EDGE") == "L1");
elnes = MPELNESSet("O", structure, "radius", 5, "beam_energy", 100, ...
    "beam_direction", [1, 0, 0], "collection_angle", 7, ...
    "convergence_angle", 6);
elnesCards = elnes.tags("ELNES");
assert(isequal(elnesCards.BEAM_ENERGY, [100, 0, 1, 1]));
assert(isequal(elnesCards.BEAM_DIRECTION, [1, 0, 0]));
assert(isequaln(elnes.as_dict(), FEFFDictSet.from_dict( ...
    elnes.as_dict()).as_dict()));
reciprocal = MPXANESSet("O", structure, "user_tag_settings", ...
    struct("RECIPROCAL", ""));
reciprocalTags = reciprocal.tags;
assert(reciprocalTags.has("RECIPROCAL"));
assert(reciprocalTags("TARGET") == 3);
assert(isequal(reciprocalTags("KMESH"), [12, 12, 7]));
assert(reciprocalTags("CIF") == "Co2O2.cif");
assert(reciprocalTags("COREHOLE") == "RPA");
assert(~isfield(reciprocal.all_input(), "ATOMS"));
assert(~MPEXAFSSet("O", structure, "user_tag_settings", ...
    struct("RECIPROCAL", "")).tags.has("RECIPROCAL"));

outputDirectory = string(tempname);
mkdir(outputDirectory);
cleanup = onCleanup(@()cleanupDirectory(outputDirectory));
xanes.write_input(fullfile(outputDirectory, "xanes"));
regenerated = FEFFDictSet.from_directory(fullfile(outputDirectory, "xanes"));
regenerated.write_input(fullfile(outputDirectory, "xanes_regen"));
originalTags = Tags.from_file(fullfile(outputDirectory, "xanes", "PARAMETERS"));
regeneratedTags = Tags.from_file( ...
    fullfile(outputDirectory, "xanes_regen", "PARAMETERS"));
assert(originalTags == regeneratedTags);
originalCluster = Atoms.cluster_from_file( ...
    fullfile(outputDirectory, "xanes", "feff.inp"));
regeneratedCluster = Atoms.cluster_from_file( ...
    fullfile(outputDirectory, "xanes_regen", "feff.inp"));
originalSymbols = string(cellfun(@(item)item.symbol, ...
    originalCluster.species, "UniformOutput", false));
regeneratedSymbols = string(cellfun(@(item)item.symbol, ...
    regeneratedCluster.species, "UniformOutput", false));
assert(isequal(originalSymbols, regeneratedSymbols));
assert(max(abs(originalCluster.distance_matrix(1, :) - ...
    regeneratedCluster.distance_matrix(1, :))) < 2e-6);
reciprocal.write_input(fullfile(outputDirectory, "reciprocal"));
reciprocalRead = FEFFDictSet.from_directory( ...
    fullfile(outputDirectory, "reciprocal"));
reciprocalRead.write_input(fullfile(outputDirectory, "reciprocal_regen"));
assert(isfile(fullfile(outputDirectory, "reciprocal_regen", "Co2O2.cif")));
assert(~isfile(fullfile(outputDirectory, "reciprocal_regen", "ATOMS")));

% Preserve the exact frozen cluster when rebuilding an existing FEFF directory.
distanceSet = FEFFDictSet.from_directory( ...
    fullfile(fixtures, "feff_dist_test"));
distanceSet.write_input(fullfile(outputDirectory, "distance_regen"));
distanceOriginal = Atoms.cluster_from_file( ...
    fullfile(fixtures, "feff_dist_test", "feff.inp"));
distanceRegenerated = Atoms.cluster_from_file( ...
    fullfile(outputDirectory, "distance_regen", "feff.inp"));
assert(distanceOriginal.num_sites == distanceRegenerated.num_sites);
distanceOriginalSymbols = string(cellfun(@(item)item.symbol, ...
    distanceOriginal.species, "UniformOutput", false));
distanceRegeneratedSymbols = string(cellfun(@(item)item.symbol, ...
    distanceRegenerated.species, "UniformOutput", false));
assert(isequal(distanceOriginalSymbols, distanceRegeneratedSymbols));
assert(max(abs(distanceOriginal.distance_matrix(1, :) - ...
    distanceRegenerated.distance_matrix(1, :))) < 2e-6);

% All production files are accepted by MATLAB's analyzer.
files = dir(fullfile(root, "+kssolv", "+analysis", "+matgenlab", ...
    "+io", "+feff", "*.m"));
issues = 0;
for index = 1:numel(files)
    issues = issues + numel(checkcode(fullfile(files(index).folder, ...
        files(index).name), "-id"));
end
assert(issues == 0);
end

function cleanupDirectory(directory)
if isfolder(directory)
    rmdir(directory, "s");
end
end
