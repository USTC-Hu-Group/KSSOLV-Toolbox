classdef BabelInventoryTest < matlab.unittest.TestCase
    properties
        fixtureRoot
        xyzRoot
        methane
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.fixtureRoot = fullfile(pwd, "+kssolv", ...
                "+analysis", "+matgenlab", "+test", "+io", ...
                "+fixtures", "+babel");
            testCase.xyzRoot = fullfile(pwd, "+kssolv", ...
                "+analysis", "+matgenlab", "+test", "+io", ...
                "+fixtures", "+xyz");
            oraclePath = fullfile(pwd, "dev", "matgenlab", ...
                "oracles", "babel_2026.7.24.json");
            testCase.oracle = jsondecode(fileread(oraclePath));
            coordinates = [0, 0, 0; 0, 0, 1.089; ...
                1.026719, 0, -.363; -.513360, -.889165, -.363; ...
                -.513360, .889165, -.363];
            testCase.methane = kssolv.analysis.matgenlab.core. ...
                Molecule({"C", "H", "H", "H", "H"}, coordinates);
        end
    end

    methods (Test)
        function constructionAndViewsMatchPymatgen(testCase)
            adaptor = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor(testCase.methane);
            testCase.verifyEqual(adaptor.pymatgen_mol.formula, ...
                string(testCase.oracle.methane.formula));
            testCase.verifyEqual(adaptor.openbabel_mol.NumAtoms(), 5);
            testCase.verifyEqual(numel(adaptor.pybel_mol.atoms), 5);
            testCase.verifyEqual(adaptor.pymatgen_mol.atomic_numbers, ...
                reshape(testCase.oracle.methane.atomic_numbers, 1, []));
            for index = 2:5
                testCase.verifyEqual( ...
                    adaptor.pymatgen_mol.get_distance(1, index), ...
                    testCase.oracle.methane. ...
                    carbon_hydrogen_distances(index - 1), AbsTol = 1e-12);
            end
            copied = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor(adaptor.openbabel_mol);
            testCase.verifyEqual(copied.pymatgen_mol.formula, "H4 C1");
        end

        function officialPdbAndAllXyzFramesMatch(testCase)
            adaptor = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor.from_file(fullfile( ...
                testCase.fixtureRoot, "Ethane_e.pdb"), "pdb");
            molecule = adaptor.pymatgen_mol;
            testCase.verifyEqual(molecule.formula, ...
                string(testCase.oracle.ethane_pdb.formula));
            testCase.verifyEqual(molecule.num_sites, ...
                testCase.oracle.ethane_pdb.atom_count);
            testCase.verifyEqual(molecule.cart_coords(1, :), ...
                reshape(testCase.oracle.ethane_pdb.first_coordinate, 1, []), ...
                AbsTol = 1e-12);
            testCase.verifyEqual(molecule.cart_coords(end, :), ...
                reshape(testCase.oracle.ethane_pdb.last_coordinate, 1, []), ...
                AbsTol = 1e-12);

            adaptors = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor.from_file(fullfile( ...
                testCase.xyzRoot, "multiple_frame.xyz"), ...
                "xyz", true);
            testCase.verifyEqual(numel(adaptors), ...
                testCase.oracle.multiple_xyz.frame_count);
            testCase.verifyEqual(adaptors{1}.openbabel_mol.NumAtoms(), 62);
            testCase.verifyEqual(adaptors{end}.pymatgen_mol.formula, ...
                string(testCase.oracle.multiple_xyz.last_formula));
        end

        function nativeFormatRoundTrips(testCase)
            formats = ["xyz", "pdb", "mol", "mdl", "sdf", "sd", ...
                "mol2", "ml2", "sy2", "cml", "mrv"];
            for format = formats
                adaptor = kssolv.analysis.matgenlab.io.babel. ...
                    BabelMolAdaptor(testCase.methane);
                path = string(tempname) + "." + format;
                cleanup = onCleanup(@() deleteIfExists(path));
                adaptor.write_file(path, format);
                parsed = kssolv.analysis.matgenlab.io.babel. ...
                    BabelMolAdaptor.from_file(path, format);
                testCase.verifyEqual(parsed.pymatgen_mol.formula, ...
                    "H4 C1", sprintf("format=%s", format));
                testCase.verifyEqual(parsed.pymatgen_mol.num_sites, 5);
                clear cleanup
            end

            xyz = string(kssolv.analysis.matgenlab.io.xyz.XYZ( ...
                testCase.methane));
            parsed = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor.from_str(xyz, "xyz");
            testCase.verifyEqual(parsed.pymatgen_mol.formula, "H4 C1");
        end

        function moleculeGraphAndBondRemovalAreNative(testCase)
            graph = kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_empty_graph(testCase.methane);
            graph.add_edge(1, 2, "weight", 1);
            adaptor = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor.from_molecule_graph(graph);
            testCase.verifyEqual(adaptor.openbabel_mol.bonds, [1, 2, 1]);
            adaptor.remove_bond(2, 1);
            testCase.verifyEmpty(adaptor.openbabel_mol.bonds);
        end

        function explicitTopologyAndBondOrdersSurviveParsing(testCase)
            mol = strjoin([ ...
                "ethene"; "  matgenlab"; ""; ...
                "  2  1  0  0  0  0            999 V2000"; ...
                "   -0.6700    0.0000    0.0000 C   0  0  0  0"; ...
                "    0.6700    0.0000    0.0000 C   0  0  0  0"; ...
                "  1  2  2  0  0  0  0"; "M  END"], newline);
            parsed = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor.from_str(mol, "mol");
            testCase.verifyEqual(parsed.openbabel_mol.bonds, [1, 2, 2]);
            testCase.verifyEqual(parsed.pymatgen_mol.properties. ...
                topology.origin, "source");
            graph = parsed.molecule_graph;
            testCase.verifyEqual(graph.graph.number_of_edges(), 1);
            testCase.verifyEqual(graph.graph.edges(1).weight, 2);
            testCase.verifyEqual(graph.graph.edges(1). ...
                edge_properties.origin, "source");

            pdb = strjoin([ ...
                "HETATM    1 C    MOL     1      -0.670   0.000   0.000  1.00  0.00           C"; ...
                "HETATM    2 C    MOL     1       0.670   0.000   0.000  1.00  0.00           C"; ...
                "CONECT    1    2    2"; "END"], newline);
            parsed = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor.from_str(pdb, "pdb");
            testCase.verifyEqual(parsed.openbabel_mol.bonds, [1, 2, 2]);
        end

        function externalCapabilitiesRequireExplicitInjection(testCase)
            adaptor = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor(testCase.methane);
            expected = "KSSOLV:Matgenlab:Babel:BackendRequired";
            testCase.verifyError(@() adaptor.localopt(), expected);
            testCase.verifyError(@() adaptor.make3d(), expected);
            testCase.verifyError(@() adaptor.add_hydrogen(), expected);
            testCase.verifyError(@() adaptor.rotor_conformer(10, 5), ...
                expected);
            testCase.verifyError(@() adaptor.gen3d_conformer(), expected);
            testCase.verifyError(@() adaptor.confab_conformers(), expected);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.io.babel.BabelMolAdaptor. ...
                from_str("C", "smi"), expected);
        end

        function injectedBackendCoversOptimizationAndConformers(testCase)
            backend = fakeBackend();
            adaptor = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor(testCase.methane, backend);
            adaptor.localopt("uff", 12);
            testCase.verifyEqual(adaptor.pymatgen_mol.cart_coords(2, 3), ...
                1.1, AbsTol = 1e-12);
            adaptor.make3d("mmff94", 8);
            adaptor.add_hydrogen();
            testCase.verifyEqual(adaptor.pymatgen_mol.num_sites, 6);
            adaptor.rotor_conformer(30, 5, ...
                "algo", "RandomRotorSearch", "forcefield", "uff");
            adaptor.gen3d_conformer();
            conformers = adaptor.confab_conformers( ...
                "rmsd_cutoff", .2, "conf_cutoff", 5);
            testCase.verifyEqual(numel(conformers), 2);
            testCase.verifyEqual(conformers{1}.num_sites, 6);
            testCase.verifyEqual(conformers{2}.cart_coords(:, 1), ...
                conformers{1}.cart_coords(:, 1) + .25, AbsTol = 1e-12);
            testCase.verifyEqual(adaptor.pybel_mol.tag, "fake-pybel");

            parsed = kssolv.analysis.matgenlab.io.babel. ...
                BabelMolAdaptor.from_str("C", "smi", backend);
            testCase.verifyEqual(parsed.pymatgen_mol.formula, "C1");
        end
    end
end

function backend = fakeBackend()
backend = struct();
backend.from_molecule = @(molecule) struct(molecule = molecule.copy());
backend.to_molecule = @(state) state.molecule;
backend.localopt = @fakeLocalopt;
backend.make3d = @(state, forcefield, steps) state;
backend.add_hydrogen = @fakeAddHydrogen;
backend.remove_bond = @(state, first, second) state;
backend.rotor_conformer = ...
    @(state, rotorArgs, algorithm, forcefield) state;
backend.gen3d_conformer = @(state) state;
backend.confab_conformers = @fakeConfab;
backend.pybel_mol = @(state) struct(tag = "fake-pybel", state = state);
backend.read_string = @fakeReadString;
backend.write_string = @(state, format) ...
    string(kssolv.analysis.matgenlab.io.xyz.XYZ(state.molecule));
end

function state = fakeLocalopt(state, forcefield, steps) %#ok<INUSD>
species = state.molecule.species;
coordinates = state.molecule.cart_coords;
coordinates(2, 3) = 1.1;
state.molecule = kssolv.analysis.matgenlab.core.Molecule( ...
    species, coordinates, charge_spin_check = false);
end

function state = fakeAddHydrogen(state)
value = state.molecule.append("H", [2, 0, 0]);
state.molecule = kssolv.analysis.matgenlab.core.Molecule( ...
    value.species_and_occu, value.cart_coords, ...
    spin_multiplicity = 2, charge_spin_check = false);
end

function result = fakeConfab(state, options) %#ok<INUSD>
first = state.molecule.copy();
second = first.translate_sites(1:first.num_sites, [.25, 0, 0]);
result = {first, second};
end

function state = fakeReadString(text, format) %#ok<INUSD>
state = struct(molecule = kssolv.analysis.matgenlab.core. ...
    Molecule({"C"}, [0, 0, 0], charge_spin_check = false));
end

function deleteIfExists(path)
if isfile(path), delete(path); end
end
