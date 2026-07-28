classdef StructureTest < matlab.unittest.TestCase
    methods (Test)
        function spacegroupConstructionAndCellConversions(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_spacegroup(225, ...
                    kssolv.analysis.matgenlab.core.Lattice.cubic(5.64), ...
                    {"Na", "Cl"}, [0, 0, 0; 0.5, 0.5, 0.5]);
            testCase.verifyClass(structure, ...
                "kssolv.analysis.matgenlab.core.Structure");
            testCase.verifyEqual(structure.num_sites, 8);
            testCase.verifyEqual(structure.formula, "Na4 Cl4");
            info = structure.get_space_group_info();
            testCase.verifyEqual(info{1}, "Fm-3m");
            testCase.verifyEqual(info{2}, 225);
            primitive = structure.to_primitive();
            testCase.verifyEqual(primitive.num_sites, 2);
            dataset = structure.get_symmetry_dataset();
            testCase.verifyEqual(dataset.number, 225);
            testCase.verifyEqual(numel(dataset.orbits), 8);

            perovskite = kssolv.analysis.matgenlab.core.Structure. ...
                from_prototype("perovskite", {"Sr", "Ti", "O"}, "a", 3.9);
            testCase.verifyEqual(perovskite.formula, "Sr1 Ti1 O3");
            testCase.verifyEqual(perovskite.num_sites, 5);
        end

        function skipChecksAllowsParserOccupancy(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(3);
            overOccupied = struct("Fe", 0.8, "Mn", 0.4);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, {overOccupied}, [0, 0, 0]), ...
                "KSSOLV:Matgenlab:Site:Occupancy");
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, {overOccupied}, [0, 0, 0], skip_checks = true);
            testCase.verifyEqual(structure.get_site(1).species.num_atoms, ...
                1.2, "AbsTol", 1e-12);
        end

        function copyInterpolateMergeAndCharge(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(4);
            first = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, ["Li", "O"], ...
                [0.95, 0, 0; 0.5, 0.5, 0.5]);
            ending = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, ["Li", "O"], ...
                [0.05, 0, 0; 0.5, 0.5, 0.5]);
            images = first.interpolate(ending, 2);
            testCase.verifyEqual(numel(images), 3);
            testCase.verifyEqual(images{2}.frac_coords(1, 1), 1, ...
                "AbsTol", 1e-12);
            copied = first.copy();
            testCase.verifyTrue(copied == first);
            copied = copied.set_charge(2);
            testCase.verifyEqual(copied.charge, 2);
            copied = copied.unset_charge();
            testCase.verifyTrue(isnan(copied.charge));

            duplicates = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, ["Li", "Na"], ...
                [0, 0, 0; 0.001, 0, 0]);
            duplicates = duplicates.merge_sites(0.01, "delete");
            testCase.verifyEqual(duplicates.num_sites, 1);

            frame = first.as_dataframe();
            testCase.verifyEqual(height(frame), 2);
            testCase.verifyEqual(frame.Properties.VariableNames(1:7), ...
                {'Species', 'a', 'b', 'c', 'x', 'y', 'z'});
        end

        function poscarFacadeRoundTrip(testCase)
            original = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(4), ...
                ["Na", "Cl"], [0, 0, 0; 0.5, 0.5, 0.5]);
            text = original.to("", "poscar");
            restored = ...
                kssolv.analysis.matgenlab.core.Structure.from_str( ...
                    text, "poscar");
            testCase.verifyTrue(restored == original);
        end
        function basicPropertiesAndNeighbors(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(3), ...
                ["Na", "Cl"], [0, 0, 0; 0.5, 0.5, 0.5]);

            testCase.verifyEqual(structure.num_sites, 2);
            testCase.verifyEqual(structure.volume, 27, AbsTol = 1e-12);
            testCase.verifyEqual(structure.get_distance(1, 2), ...
                sqrt(6.75), AbsTol = 1e-12);
            neighbors = structure.get_neighbors(structure(1), 3);
            testCase.verifyGreaterThanOrEqual(numel(neighbors), 1);
        end

        function mutationOperationsReturnUpdatedValue(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(4), ...
                "Si", [0, 0, 0]);
            structure = structure.append("Si", [0.25, 0.25, 0.25]);
            testCase.verifyEqual(structure.num_sites, 2);
            structure = structure.translate_sites(2, [0.25, 0, 0]);
            testCase.verifyEqual(structure(2).frac_coords, [0.5, 0.25, 0.25]);
            structure = structure.scale_lattice(512);
            testCase.verifyEqual(structure.volume, 512, AbsTol = 1e-10);
            structure = structure.remove_sites(1);
            testCase.verifyEqual(structure.num_sites, 1);
        end

        function serializationRoundTrip(testCase)
            original = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.hexagonal(3, 5), ...
                ["Li", "O"], [0, 0, 0; 1/3, 2/3, 0.5], ...
                site_properties = struct("magmom", [1, 0]));
            restored = kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                original.as_dict());

            testCase.verifyTrue(restored == original);
            testCase.verifyEqual(restored.site_properties.magmom, {1, 0});
        end

        function supercellAndRotation(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(2), ...
                "Li", [0, 0, 0]);
            supercell = structure.make_supercell([2, 1, 1]);
            testCase.verifyEqual(supercell.num_sites, 2);
            testCase.verifyEqual(supercell.volume, 16, AbsTol = 1e-12);

            structure = structure.append("Li", [0.5, 0, 0]);
            structure = structure.rotate_sites(2, pi / 2);
            testCase.verifyEqual(structure(2).coords, [0, 1, 0], ...
                AbsTol = 1e-12);
        end
    end
end
