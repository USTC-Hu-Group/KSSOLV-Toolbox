classdef MoleculeTest < matlab.unittest.TestCase
    methods (Test)
        function covalentBondsBreakAndZmatrix(testCase)
            water = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            bonds = water.get_covalent_bonds();
            testCase.verifyEqual(numel(bonds), 2);
            [oxygenHydrogen, hydrogen] = water.break_bond(1, 2);
            testCase.verifyEqual(oxygenHydrogen.num_sites, 2);
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

        function explicitTopologyTracksInsertionReplacementAndRemoval(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            molecule.properties.topology = struct( ...
                "bonds", [1, 2, 1; 1, 3, 1], "origin", "source");

            molecule = molecule.insert(2, "He", [3, 0, 0]);
            testCase.verifyEqual(molecule.properties.topology.bonds, ...
                [1, 3, 1; 1, 4, 1]);
            molecule = molecule.replace(3, "F", [1, 0, 0]);
            testCase.verifyEqual(molecule(3).species_string, "F");
            testCase.verifyEqual(molecule.properties.topology.bonds, ...
                [1, 3, 1; 1, 4, 1]);
            molecule = molecule.remove_sites([2, 3]);
            testCase.verifyEqual(molecule.properties.topology.bonds, ...
                [1, 2, 1]);
        end

        function editableFormatsRoundTripTenTopologyFixtures(testCase)
            formats = ["xyz", "mol", "sdf", "mol2", "pdb"];
            topologyFormats = ["mol", "sdf", "mol2", "pdb"];
            for fixtureIndex = 1:10
                count = fixtureIndex + 2;
                species = repmat("C", 1, count);
                species(2:3:end) = "N";
                species(3:3:end) = "O";
                coordinates = [(0:count - 1)' * 1.25, ...
                    sin((0:count - 1)') * 0.2, ...
                    cos((0:count - 1)') * 0.15];
                molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                    species, coordinates);
                orders = mod((1:count - 1)' + fixtureIndex - 1, 3) + 1;
                bonds = [(1:count - 1)', (2:count)', orders];
                molecule.properties.topology = struct( ...
                    "bonds", bonds, "origin", "source");

                for format = formats
                    restored = ...
                        kssolv.analysis.matgenlab.core.Molecule.from_str( ...
                        molecule.to("", format), format);
                    testCase.verifyEqual(restored.num_sites, count, ...
                        sprintf("fixture %d, format %s", ...
                        fixtureIndex, format));
                    testCase.verifyEqual(restored.composition.formula, ...
                        molecule.composition.formula);
                    tolerance = 5e-7;
                    if format == "pdb", tolerance = 5e-4; end
                    if any(format == ["mol", "sdf"]), tolerance = 5e-5; end
                    if format == "mol2", tolerance = 5e-7; end
                    testCase.verifyEqual(restored.cart_coords, coordinates, ...
                        AbsTol = tolerance);

                    edited = restored.replace(1, "F", []);
                    edited = edited.translate_sites( ...
                        count, [0, 0, 0.25]);
                    editedAgain = ...
                        kssolv.analysis.matgenlab.core.Molecule.from_str( ...
                        edited.to("", format), format);
                    testCase.verifyEqual( ...
                        editedAgain(1).species_string, "F");
                    if any(format == topologyFormats)
                        testCase.verifyEqual( ...
                            editedAgain.properties.topology.bonds, bonds);
                    end
                end
            end
        end

        function fromSitesPreservesSiteProperties(testCase)
            sites = {
                kssolv.analysis.matgenlab.core.Site( ...
                    "H", [0, 0, 0], properties = struct("tag", "first"))
                kssolv.analysis.matgenlab.core.Site( ...
                    "H", [0, 0, 0.74], ...
                    properties = struct("tag", "second"))
                };

            molecule = kssolv.analysis.matgenlab.core.IMolecule. ...
                from_sites(sites);

            testCase.verifyEqual(molecule.site_properties.tag, ...
                {"first", "second"});
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
