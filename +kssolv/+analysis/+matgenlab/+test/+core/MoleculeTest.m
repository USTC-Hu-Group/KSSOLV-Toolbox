classdef MoleculeTest < matlab.unittest.TestCase
    methods (Test)
        function covalentBondsBreakAndZmatrix(testCase)
            water = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            bonds = water.get_covalent_bonds();
            testCase.verifyEqual(numel(bonds), 2);
            [hydroxyl, hydrogen] = water.break_bond(1, 2);
            testCase.verifyEqual(hydroxyl.num_sites, 2);
            testCase.verifyEqual(hydrogen.num_sites, 1);
            testCase.verifyTrue(contains(water.get_zmatrix(), "B1="));
            testCase.verifyTrue(contains(water.get_zmatrix(), "A2="));
        end

        function zmatrixMatchesPymatgen(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle.isAvailable());
            species = ["O", "H", "H"];
            coordinates = [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0];
            request = struct( ...
                "module", "pymatgen.core.structure", ...
                "symbol", "Molecule", ...
                "construct", struct("args", {{species, coordinates}}), ...
                "operations", {{struct( ...
                    "kind", "call", "name", "get_zmatrix")}});
            reference = ...
                kssolv.analysis.matgenlab.test.support.PymatgenOracle.execute(request);
            actual = kssolv.analysis.matgenlab.core.Molecule( ...
                species, coordinates);
            testCase.verifyEqual(actual.get_zmatrix(), ...
                string(reference.results));
        end

        function rotateSites(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                "H", [1, 0, 0]);
            molecule = molecule.rotate_sites([], pi / 2, [0, 0, 1]);
            testCase.verifyEqual(molecule.cart_coords, [0, 1, 0], ...
                "AbsTol", 1e-12);
        end
        function waterProperties(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            testCase.verifyEqual(molecule.num_sites, 3);
            testCase.verifyEqual(molecule.nelectrons, 10);
            testCase.verifyEqual(molecule.spin_multiplicity, 1);
            testCase.verifySize(molecule.center_of_mass, [1, 3]);
            testCase.verifyEqual(molecule.get_distance(1, 2), 0.9572, ...
                AbsTol = 1e-12);
        end

        function mutationAndSerialization(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["H", "H"], [0, 0, 0; 0, 0, 0.74]);
            molecule = molecule.append("He", [2, 0, 0]);
            molecule = molecule.translate_sites(3, [1, 0, 0]);
            testCase.verifyEqual(molecule(3).coords, [3, 0, 0]);
            molecule = molecule.remove_sites(3);
            restored = kssolv.analysis.matgenlab.core.Molecule.from_dict( ...
                molecule.as_dict());
            testCase.verifyTrue(restored == molecule);
        end

        function boxedStructure(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["H", "H"], [0, 0, 0; 0, 0, 0.74]);
            structure = molecule.get_boxed_structure(5, 5, 5);
            testCase.verifyEqual(structure.num_sites, 2);
            testCase.verifyEqual(structure.volume, 125, AbsTol = 1e-12);
        end

        function spatialCovalentSearchMatchesAllPairs(testCase)
            [x, y, z] = ndgrid(0:5, 0:4, 0:3);
            coordinates = [x(:), y(:), z(:)] * 1.45;
            species = repmat("C", size(coordinates, 1), 1);
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                species, coordinates, charge_spin_check = false);
            expected = bruteForcePairs(molecule, 0.2);
            actual = molecule.get_covalent_bond_pairs(0.2);
            testCase.verifyEqual(actual, expected);

            graph = kssolv.analysis.matgenlab.core.OpenBabelNN(). ...
                get_bonded_structure(molecule);
            testCase.verifyEqual(graph.graph.number_of_edges(), ...
                size(expected, 1));
            testCase.verifyEqual(graph.graph.edges(1). ...
                edge_properties.origin, "OpenBabelNN");
        end
    end
end

function pairs = bruteForcePairs(molecule, tolerance)
pairs = zeros(0, 2);
for first = 1:molecule.num_sites
    for second = first + 1:molecule.num_sites
        if kssolv.analysis.matgenlab.core.CovalentBond.is_bonded( ...
                molecule(first), molecule(second), tolerance)
            pairs(end + 1, :) = [first, second]; %#ok<AGROW>
        end
    end
end
end
