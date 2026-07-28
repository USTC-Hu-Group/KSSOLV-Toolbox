classdef SpacegroupAnalyzerTest < matlab.unittest.TestCase
    % Frozen against pymatgen-core v2026.7.24 test_analyzer.py.

    methods (Test)
        function cubicStructureCoreApi(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            structure = Structure(Lattice.cubic(3), "Si", [0, 0, 0]);
            analyzer = SpacegroupAnalyzer(structure);
            testCase.verifyEqual(analyzer.get_space_group_symbol(), "Pm-3m");
            testCase.verifyEqual(analyzer.get_space_group_number(), 221);
            testCase.verifyEqual(analyzer.get_point_group_symbol(), "m-3m");
            testCase.verifyEqual(analyzer.get_crystal_system(), "cubic");
            testCase.verifyEqual(analyzer.get_lattice_type(), "cubic");
            testCase.verifyEqual(analyzer.get_pearson_symbol(), "cP1");
            testCase.verifyEqual(numel(analyzer.get_symmetry_operations()), 48);
            testCase.verifyTrue(analyzer.is_laue());
        end

        function remainingPublicAnalyzerMembers(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.*
            structure = Structure(Lattice.cubic(3), "Si", [0, 0, 0]);
            analyzer = SpacegroupAnalyzer(structure);
            testCase.verifyEqual(analyzer.get_hall(), "-P 4 2 3");
            testCase.verifyNumElements( ...
                analyzer.get_point_group_operations(), 48);
            testCase.verifyEqual( ...
                analyzer.get_primitive_standard_structure().num_sites, 1);
            testCase.verifyEqual( ...
                analyzer.get_conventional_standard_structure().num_sites, 1);
            irreducible = analyzer.get_ir_reciprocal_mesh([4, 4, 4]);
            kpoints = zeros(numel(irreducible), 3);
            multiplicities = zeros(numel(irreducible), 1);
            for index = 1:numel(irreducible)
                kpoints(index, :) = irreducible{index}{1};
                multiplicities(index) = irreducible{index}{2};
            end
            weights = analyzer.get_kpoint_weights(kpoints);
            testCase.verifyEqual(weights, ...
                multiplicities / sum(multiplicities), AbsTol=1e-14);
            exception = SymmetryUndeterminedError("frozen message");
            testCase.verifyEqual(exception.identifier, ...
                'KSSOLV:Matgenlab:SymmetryUndetermined');
        end

        function datasetUsesMatlabIndices(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            structure = Structure(Lattice.cubic(3), ...
                ["Fe", "Fe"], [0, 0, 0; 0.5, 0.5, 0.5]);
            dataset = SpacegroupAnalyzer(structure).get_symmetry_dataset();
            testCase.verifyEqual(dataset.number, 229);
            testCase.verifyEqual(dataset.index_base, 1);
            testCase.verifyGreaterThanOrEqual(dataset.equivalent_atoms, 1);
            testCase.verifyEqual(dataset.wyckoffs, ["a", "a"]);
        end

        function cartesianOperationsMapSites(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            lattice = Lattice.hexagonal(2.5, 4);
            structure = Structure(lattice, ["C", "C"], ...
                [0, 0, 0; 1/3, 2/3, 0.5]);
            analyzer = SpacegroupAnalyzer(structure);
            fractional = analyzer.get_symmetry_operations(false);
            cartesian = analyzer.get_symmetry_operations(true);
            testCase.verifyEqual(numel(fractional), numel(cartesian));
            point = [0.137, 0.251, 0.389];
            cartPoint = lattice.get_cartesian_coords(point);
            for index = 1:numel(fractional)
                expected = fractional{index}.operate(point);
                actual = lattice.get_fractional_coords( ...
                    cartesian{index}.operate(cartPoint));
                testCase.verifyEqual(actual, expected, AbsTol = 1e-10);
            end
        end

        function reciprocalMeshMatchesFrozenCount(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            analyzer = SpacegroupAnalyzer( ...
                Structure(Lattice.cubic(3), "Si", [0, 0, 0]));
            [grid, mapping] = ...
                analyzer.get_ir_reciprocal_mesh_map([4, 4, 4]);
            irreducible = analyzer.get_ir_reciprocal_mesh([4, 4, 4]);
            testCase.verifySize(grid, [64, 3]);
            testCase.verifyEqual(numel(unique(mapping)), 10);
            testCase.verifyEqual(numel(irreducible), 10);
            testCase.verifyEqual(sum(cellfun(@(entry) entry{2}, ...
                irreducible)), 64);
        end

        function primitiveRefinedAndSymmetrized(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            structure = Structure(Lattice.cubic(3), ...
                repmat({"Cu"}, 1, 4), ...
                [0, 0, 0; 0, 0.5, 0.5; ...
                0.5, 0, 0.5; 0.5, 0.5, 0]);
            analyzer = SpacegroupAnalyzer(structure);
            testCase.verifyEqual(analyzer.find_primitive().num_sites, 1);
            testCase.verifyEqual(analyzer.get_refined_structure().num_sites, 4);
            symmetrized = analyzer.get_symmetrized_structure();
            testCase.verifyEqual(numel(symmetrized.equivalent_indices), 1);
            testCase.verifyEqual(symmetrized.wyckoff_symbols, "4a");
        end

        function operationCollectionEquivalence(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            structure = Structure(Lattice.cubic(3), ...
                ["Fe", "Fe"], [0, 0, 0; 0.5, 0.5, 0.5]);
            operations = ...
                SpacegroupAnalyzer(structure).get_space_group_operations();
            testCase.verifyTrue(operations.are_symmetrically_equivalent( ...
                {structure(1)}, {structure(2)}, 1e-8));
            testCase.verifyEqual(operations.length(), 96);
        end

        function transformationMatrices(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            faceCentered = Structure(Lattice.cubic(3), ...
                repmat({"Cu"}, 1, 4), ...
                [0, 0, 0; 0, .5, .5; .5, 0, .5; .5, .5, 0]);
            matrix = SpacegroupAnalyzer(faceCentered). ...
                get_conventional_to_primitive_transformation_matrix();
            testCase.verifyEqual(matrix, ...
                [0, 1, 1; 1, 0, 1; 1, 1, 0] / 2);
        end

        function frozenOracleAnalyzerValues(testCase)
            testCase.assumeTrue(kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.isAvailable());
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.SpacegroupAnalyzer
            structure = Structure(Lattice.cubic(3), "Si", [0, 0, 0]);
            request = struct( ...
                "module", "pymatgen.symmetry.analyzer", ...
                "symbol", "SpacegroupAnalyzer", ...
                "construct", struct("args", {{structure.as_dict(), .01}}), ...
                "operations", {{ ...
                    struct("kind", "call", ...
                        "name", "get_space_group_symbol"), ...
                    struct("kind", "call", ...
                        "name", "get_space_group_number"), ...
                    struct("kind", "call", ...
                        "name", "get_point_group_symbol"), ...
                    struct("kind", "call", ...
                        "name", "get_pearson_symbol") ...
                    }});
            reference = kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.execute(request);
            analyzer = SpacegroupAnalyzer(structure);
            actual = [analyzer.get_space_group_symbol(), ...
                string(analyzer.get_space_group_number()), ...
                analyzer.get_point_group_symbol(), ...
                analyzer.get_pearson_symbol()];
            expected = [string(reference.results{1}), ...
                string(reference.results{2}), ...
                string(reference.results{3}), ...
                string(reference.results{4})];
            testCase.verifyEqual(actual, expected);
        end
    end
end
