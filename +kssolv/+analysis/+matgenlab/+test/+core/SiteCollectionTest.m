classdef SiteCollectionTest < matlab.unittest.TestCase
    methods (Test)
        function oxidationAndSpinDecoration(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(4), ...
                ["Fe", "O"], [0, 0, 0; 0.5, 0.5, 0.5]);
            structure = structure.add_oxidation_state_by_element( ...
                struct("Fe", 2, "O", -2));
            testCase.verifyEqual(structure.get_site(1).specie.oxi_state, 2);
            testCase.verifyEqual(structure.get_site(2).specie.oxi_state, -2);
            structure = structure.add_spin_by_element( ...
                struct("Fe", 5, "O", 0));
            testCase.verifyEqual(structure.get_site(1).specie.spin, 5);
            structure = structure.remove_spin();
            testCase.verifyTrue(isnan(structure.get_site(1).specie.spin));
            structure = structure.remove_oxidation_states();
            testCase.verifyClass(structure.get_site(1).specie, ...
                "kssolv.analysis.matgenlab.core.Element");
        end

        function replacementPreservesOccupancy(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["Li", "O"], [0, 0, 0; 1.5, 0, 0]);
            molecule = molecule.replace_species(struct("Li", "Na"));
            testCase.verifyEqual(molecule.get_site(1).specie.symbol, "Na");
            testCase.verifyEqual(molecule.get_site(2).specie.symbol, "O");
        end

        function extractsCovalentCluster(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "He"], ...
                [0, 0, 0; 0.95, 0, 0; 10, 0, 0]);
            cluster = molecule.extract_cluster({molecule.get_site(1)});
            testCase.verifyEqual(numel(cluster), 2);
            testCase.verifyEqual( ...
                sort(string(cellfun(@(site) site.specie.symbol, cluster, ...
                "UniformOutput", false))), ["H", "O"]);
        end
        function aggregateProperties(testCase)
            sites = {
                kssolv.analysis.matgenlab.core.Site("H", [0, 0, 0])
                kssolv.analysis.matgenlab.core.Site("O", [0, 0, 1])
                kssolv.analysis.matgenlab.core.Site("H", [1, 0, 0])
                };
            collection = ...
                kssolv.analysis.matgenlab.test.core.SiteCollectionFixture(sites);

            testCase.verifyEqual(collection.num_sites, 3);
            testCase.verifyEqual(collection.formula, "H2 O1");
            testCase.verifyEqual(collection.atomic_numbers, [1, 8, 1]);
            testCase.verifyEqual(collection.get_distance(1, 2), 1);
            testCase.verifyEqual(collection.get_angle(1, 2, 3), 45, ...
                AbsTol = 1e-12);
        end

        function sitePropertyRoundTrip(testCase)
            sites = {
                kssolv.analysis.matgenlab.core.Site("H", [0, 0, 0])
                kssolv.analysis.matgenlab.core.Site("O", [0, 0, 1])
                };
            collection = ...
                kssolv.analysis.matgenlab.test.core.SiteCollectionFixture(sites);
            collection = collection.add_site_property("charge", [1, -2]);

            testCase.verifyEqual(collection.site_properties.charge, {1, -2});
            collection = collection.remove_site_property("charge");
            testCase.verifyFalse(isfield(collection.site_properties, "charge"));
        end
    end
end
