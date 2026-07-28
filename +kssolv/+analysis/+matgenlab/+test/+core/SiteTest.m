classdef SiteTest < matlab.unittest.TestCase
    methods (Test)
        function neighborSerialization(testCase)
            neighbor = kssolv.analysis.matgenlab.core.Neighbor( ...
                "O", [1, 2, 3], 2.5, 4);
            restored = ...
                kssolv.analysis.matgenlab.core.Neighbor.from_dict( ...
                    neighbor.as_dict());
            testCase.verifyTrue(restored == neighbor);
            testCase.verifyEqual(restored.nn_distance, 2.5);
            testCase.verifyEqual(restored.index, 4);

            periodic = kssolv.analysis.matgenlab.core.PeriodicNeighbor( ...
                "Na", [0.1, 0.2, 0.3], ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(3), ...
                1.2, 2, [1, 0, -1]);
            periodicRestored = ...
                kssolv.analysis.matgenlab.core.PeriodicNeighbor.from_dict( ...
                    periodic.as_dict());
            testCase.verifyEqual(periodicRestored.frac_coords, ...
                periodic.frac_coords, "AbsTol", 1e-12);
            testCase.verifyEqual(periodicRestored.image, [1, 0, -1]);
        end
        function orderedAndDisorderedSites(testCase)
            ordered = kssolv.analysis.matgenlab.core.Site( ...
                "Fe", [0.25, 0.35, 0.45]);
            disordered = kssolv.analysis.matgenlab.core.Site( ...
                struct("Fe", 0.5, "Mn", 0.5), [0.25, 0.35, 0.45]);

            testCase.verifyTrue(ordered.is_ordered);
            testCase.verifyFalse(disordered.is_ordered);
            testCase.verifyEqual(ordered.specie.symbol, "Fe");
            testCase.verifyError(@() disordered.specie, ...
                "KSSOLV:Matgenlab:Site:DisorderedSpecie");
            testCase.verifyEqual(ordered.distance(disordered), 0);
            testCase.verifyEqual(ordered.hash(), 26);
            testCase.verifyEqual(disordered.hash(), 51);
        end

        function siteSerializationRoundTrip(testCase)
            original = kssolv.analysis.matgenlab.core.Site( ...
                struct("Fe", 0.5, "Mn", 0.5), [0.25, 0.35, 0.45], ...
                properties = struct("magmom", 5.1));
            restored = kssolv.analysis.matgenlab.core.Site.from_dict( ...
                original.as_dict());

            testCase.verifyTrue(restored == original);
            testCase.verifyEqual(restored.properties.magmom, 5.1);
        end

        function periodicCoordinatesAndDistance(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(10);
            site = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                "Fe", [0.25, 0.35, 0.45], lattice);
            other = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                "Fe", [0, 0, 0], lattice);

            testCase.verifyEqual(site.coords, [2.5, 3.5, 4.5], ...
                AbsTol = 1e-12);
            testCase.verifyEqual(site.distance(other), 6.22494979899, ...
                AbsTol = 1e-10);
        end

        function periodicImageAndUnitCell(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(10);
            site = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                "Fe", [1.25, 2.35, 4.46], lattice);
            image = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                "Fe", [0.25, 0.35, 0.46], lattice);

            testCase.verifyTrue(site.is_periodic_image(image));
            site = site.to_unit_cell(true);
            testCase.verifyEqual(site.frac_coords, [0.25, 0.35, 0.46], ...
                AbsTol = 1e-12);
        end

        function periodicSerializationRoundTrip(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.hexagonal(3, 5);
            original = kssolv.analysis.matgenlab.core.PeriodicSite( ...
                "Fe2+", [0.2, 0.3, 0.4], lattice, ...
                properties = struct("magmom", 5));
            restored = ...
                kssolv.analysis.matgenlab.core.PeriodicSite.from_dict( ...
                    original.as_dict());

            testCase.verifyTrue(restored == original);
            testCase.verifyEqual(restored.specie.oxi_state, 2);
        end
    end
end
