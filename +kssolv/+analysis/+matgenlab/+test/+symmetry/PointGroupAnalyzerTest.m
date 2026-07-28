classdef PointGroupAnalyzerTest < matlab.unittest.TestCase
    % Molecular fixtures frozen from pymatgen-core v2026.7.24.

    methods (Test)
        function sphericalTopGroups(testCase)
            import kssolv.analysis.matgenlab.core.Molecule
            import kssolv.analysis.matgenlab.symmetry.analyzer.PointGroupAnalyzer
            methane = Molecule(["C", "H", "H", "H", "H"], [
                0, 0, 0; 0, 0, 1.08; 1.026719, 0, -0.363; ...
                -0.513360, -0.889165, -0.363; ...
                -0.513360, 0.889165, -0.363]);
            analyzer = PointGroupAnalyzer(methane);
            testCase.verifyEqual(analyzer.sch_symbol, "Td");
            testCase.verifyEqual(length(analyzer.get_pointgroup()), 24);
            testCase.verifyEqual( ...
                analyzer.get_rotational_symmetry_number(), 12);

            octahedral = Molecule(["P", repmat("F", 1, 6)], [
                0, 0, 0; 0, 0, 1; 0, 0, -1; ...
                0, 1, 0; 0, -1, 0; 1, 0, 0; -1, 0, 0]);
            analyzer = PointGroupAnalyzer(octahedral);
            testCase.verifyEqual(analyzer.sch_symbol, "Oh");
            testCase.verifyEqual(length(analyzer.get_pointgroup()), 48);
        end

        function cyclicAndDihedralGroups(testCase)
            import kssolv.analysis.matgenlab.core.Molecule
            import kssolv.analysis.matgenlab.symmetry.analyzer.PointGroupAnalyzer
            water = Molecule(["H", "O", "H"], [
                0, .780362, -.456316; 0, 0, .114079; ...
                0, -.780362, -.456316]);
            testCase.verifyEqual(PointGroupAnalyzer(water).sch_symbol, "C2v");
            ammonia = Molecule(["N", "H", "H", "H"], [
                0, 0, 0; 0, -.9377, -.3816; ...
                .8121, .4689, -.3816; -.8121, .4689, -.3816]);
            testCase.verifyEqual(PointGroupAnalyzer(ammonia).sch_symbol, "C3v");
            boronFluoride = Molecule(["B", "F", "F", "F"], [
                0, 0, 0; 0, -.9377, 0; ...
                .8121, .4689, 0; -.8121, .4689, 0]);
            analyzer = PointGroupAnalyzer(boronFluoride);
            testCase.verifyEqual(analyzer.sch_symbol, "D3h");
            testCase.verifyEqual(length(analyzer.get_pointgroup()), 12);
        end

        function linearGroupsAndConvention(testCase)
            import kssolv.analysis.matgenlab.core.Molecule
            import kssolv.analysis.matgenlab.symmetry.analyzer.PointGroupAnalyzer
            coords = [0, 0, 0; 0, 0, 1.08; 0, 0, -1.08];
            analyzer = PointGroupAnalyzer(Molecule(["C", "H", "H"], coords));
            testCase.verifyEqual(analyzer.sch_symbol, "D*h");
            testCase.verifyEqual(analyzer.get_rotational_symmetry_number(), 2);
            analyzer = PointGroupAnalyzer(Molecule(["C", "H", "N"], coords));
            testCase.verifyEqual(analyzer.sch_symbol, "C*v");
            testCase.verifyEqual(analyzer.get_rotational_symmetry_number(), 1);
            testCase.verifyEqual(PointGroupAnalyzer( ...
                Molecule("He", [0, 0, 0])).sch_symbol, "Kh");
        end

        function asymmetricGroups(testCase)
            import kssolv.analysis.matgenlab.core.Molecule
            import kssolv.analysis.matgenlab.symmetry.analyzer.PointGroupAnalyzer
            molecule = Molecule(["C", "H", "F", "Br", "Cl"], [
                0, 0, 0; 0, 0, 1.08; 1.026719, 0, -.363; ...
                -.51336, -.889165, -.363; -.51336, .889165, -.363]);
            testCase.verifyEqual(PointGroupAnalyzer(molecule).sch_symbol, "C1");
            molecule = Molecule(["O", "O", "H", "H"], [
                0, .727403, -.050147; 0, -.727403, -.050147; ...
                .83459, .897642, .401175; -.83459, -.897642, .401175]);
            testCase.verifyEqual(PointGroupAnalyzer(molecule).sch_symbol, "C2");
        end

        function equivalentAtomsAndSymmetrization(testCase)
            import kssolv.analysis.matgenlab.core.Molecule
            import kssolv.analysis.matgenlab.symmetry.analyzer.PointGroupAnalyzer
            water = Molecule(["H", "O", "H"], [
                0, .780362, -.456316; 0, 0, .114079; ...
                0, -.780362, -.456316]);
            analyzer = PointGroupAnalyzer(water);
            equivalent = analyzer.get_equivalent_atoms();
            testCase.verifyEqual(sort(cellfun(@numel, ...
                equivalent.eq_sets)), [1, 2]);
            result = analyzer.symmetrize_molecule();
            testCase.verifyEqual(result.sym_mol.num_sites, 3);
            testCase.verifyEqual(result.index_base, 1);
            operations = analyzer.get_symmetry_operations();
            testCase.verifyNumElements(operations, 4);
            testCase.verifyTrue(analyzer.is_valid_op(operations{1}));
        end

        function helpers(testCase)
            import kssolv.analysis.matgenlab.core.*
            import kssolv.analysis.matgenlab.symmetry.analyzer.*
            methane = Molecule(["C", "H", "H", "H", "H"], [
                0, 0, 0; 0, 0, 1.08; 1.026719, 0, -.363; ...
                -.51336, -.889165, -.363; -.51336, .889165, -.363]);
            [origin, clusters] = ...
                cluster_sites(methane.get_centered_molecule(), .1);
            testCase.verifyClass(origin, ...
                "kssolv.analysis.matgenlab.core.Site");
            testCase.verifyEqual(origin.species_string, "C");
            testCase.verifyEqual(numel(clusters), 1);
            identity = SymmOp.from_rotation_and_translation( ...
                eye(3), zeros(1, 3));
            rotation = SymmOp.from_axis_angle_and_translation([0, 0, 1], 90);
            testCase.verifyEqual(numel(generate_full_symmops( ...
                {identity, rotation}, .1)), 4);
        end

        function iterativeSymmetrizationRestoresInversion(testCase)
            % Coordinates are the exact NumPy RNG(0) distortion used by
            % upstream test_symmetrize_molecule2.
            import kssolv.analysis.matgenlab.core.Molecule
            import kssolv.analysis.matgenlab.symmetry.analyzer.*
            species = {"C", "C", "F", "Br", "H", "F", "H", "Br"};
            coordinates = [
                -.745713488945, -.005605243165, -.108978867478
                 .757245005858, -.027783468658,  .159079752745
                -1.092799997743, 1.038354048156, .034813238210
                -1.303271073552, -.768163723127, .498066298967
                -1.040251538732, -.259939583197, -1.250295547363
                 1.121386632265, -1.018212949143, -.085815007818
                 .944581526819, .301125668472, 1.181573266853
                 1.308323173527, .703740266326, -.478424496495
                ];
            molecule = Molecule(species, coordinates);
            testCase.verifyEqual( ...
                PointGroupAnalyzer(molecule, .1).sch_symbol, "C1");
            result = iterative_symmetrize(molecule, 10, .3, .01);
            testCase.verifyEqual( ...
                PointGroupAnalyzer(result.sym_mol, .1).sch_symbol, "Ci");
        end

        function frozenOracleMolecularValues(testCase)
            testCase.assumeTrue(kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.isAvailable());
            import kssolv.analysis.matgenlab.core.Molecule
            import kssolv.analysis.matgenlab.symmetry.analyzer.PointGroupAnalyzer
            molecule = Molecule(["H", "O", "H"], [
                0, .780362, -.456316; 0, 0, .114079; ...
                0, -.780362, -.456316]);
            request = struct( ...
                "module", "pymatgen.symmetry.analyzer", ...
                "symbol", "PointGroupAnalyzer", ...
                "construct", struct("args", {{molecule.as_dict()}}), ...
                "operations", {{ ...
                    struct("kind", "get", "name", "sch_symbol"), ...
                    struct("kind", "call", ...
                        "name", "get_rotational_symmetry_number") ...
                    }});
            reference = kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.execute(request);
            analyzer = PointGroupAnalyzer(molecule);
            testCase.verifyEqual(analyzer.sch_symbol, ...
                string(reference.results{1}));
            testCase.verifyEqual(analyzer.get_rotational_symmetry_number(), ...
                reference.results{2});
        end
    end
end
