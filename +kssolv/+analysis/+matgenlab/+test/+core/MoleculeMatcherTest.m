classdef MoleculeMatcherTest < matlab.unittest.TestCase
    properties (Constant, Access = private)
        FixtureRoot = "+kssolv/+analysis/+matgenlab/+test/" + ...
            "+core/+fixtures/+molecule_matcher"
    end

    methods (Test)
        function kabschAndSerializationMatchOracle(testCase)
            testCase.assumeTrue(isfolder(testCase.FixtureRoot), ...
                "Official pymatgen molecule_matcher fixtures unavailable.");
            target = testCase.loadMolecule("t3.xyz");
            source = testCase.loadMolecule("t4.xyz");
            matcher = kssolv.analysis.matgenlab.core.KabschMatcher(target);
            [~, ~, rmsd] = matcher.match(source);
            testCase.verifyEqual(rmsd, 0.00487969912498296, ...
                AbsTol = 1e-12);
            restored = kssolv.analysis.matgenlab.core.KabschMatcher. ...
                from_dict(matcher.as_dict());
            testCase.verifyEqual(restored.as_dict(), matcher.as_dict());
        end

        function orderMatchersMatchOfficialFixtures(testCase)
            testCase.assumeTrue(isfolder(testCase.FixtureRoot), ...
                "Official pymatgen molecule_matcher fixtures unavailable.");
            target = testCase.loadMolecule("Si2O_cluster.xyz");
            perturbed = testCase.loadMolecule( ...
                "Si2O_cluster_perturbed.xyz");
            random = testCase.loadMolecule("Si2O_cluster_2.xyz");

            brute = kssolv.analysis.matgenlab.core. ...
                BruteForceOrderMatcher(target);
            [~, rmsd] = brute.fit(perturbed);
            testCase.verifyEqual(rmsd, 0.4215889759652215, ...
                AbsTol = 1e-12);

            hungarian = kssolv.analysis.matgenlab.core. ...
                HungarianOrderMatcher(target);
            [~, rmsd] = hungarian.fit(random);
            testCase.verifyEqual(rmsd, 0.40237339648564513, ...
                AbsTol = 1e-12);

            genetic = kssolv.analysis.matgenlab.core. ...
                GeneticOrderMatcher(target, 0.5196152422706631);
            matches = genetic.match(random);
            testCase.verifyNumElements(matches, 3);
            testCase.verifyEqual(matches{1}{4}, 0.3992654193602329, ...
                AbsTol = 1e-12);
            restored = kssolv.analysis.matgenlab.core.KabschMatcher. ...
                from_dict(genetic.as_dict());
            testCase.verifyEqual(restored.as_dict(), genetic.as_dict());
        end

        function assignmentAndStaticGeometryApis(testCase)
            costs = [19, 95, 9; 26, 30, 88];
            [solution, cost] = kssolv.analysis.matgenlab.core. ...
                get_linear_assignment_solution(costs);
            testCase.verifyEqual(solution, [3, 1]);
            testCase.verifyEqual(cost, 35);

            source = [1, 0, 0; 0, 1, 0; 0, 0, 1];
            rotation = [0, -1, 0; 1, 0, 0; 0, 0, 1];
            calculated = kssolv.analysis.matgenlab.core.KabschMatcher. ...
                kabsch(source, source * rotation);
            testCase.verifyEqual(calculated, rotation, AbsTol = 1e-12);

            axis = kssolv.analysis.matgenlab.core. ...
                HungarianOrderMatcher.get_principal_axis(source, [1; 1; 1]);
            testCase.verifySize(axis, [1, 3]);
            vectorRotation = kssolv.analysis.matgenlab.core. ...
                HungarianOrderMatcher.rotation_matrix_vectors( ...
                [1, 0, 0], [0, 1, 0]);
            testCase.verifyEqual(vectorRotation * [1; 0; 0], ...
                [0; 1; 0], AbsTol = 1e-12);
        end

        function openBabelAbsenceIsExplicit(testCase)
            expected = ...
                "KSSOLV:Matgenlab:MoleculeMatcher:OpenBabelRequired";
            mapper = kssolv.analysis.matgenlab.core. ...
                IsomorphismMolAtomMapper();
            testCase.verifyError(@() mapper.get_molecule_hash([]), expected);
            testCase.verifyError(@() mapper.uniform_labels([], []), expected);
            inchi = kssolv.analysis.matgenlab.core.InchiMolAtomMapper(30);
            restored = kssolv.analysis.matgenlab.core. ...
                AbstractMolAtomMapper.from_dict(inchi.as_dict());
            testCase.verifyClass(restored, ...
                "kssolv.analysis.matgenlab.core.InchiMolAtomMapper");
            testCase.verifyEqual(restored.angle_tolerance, 30);

            matcher = kssolv.analysis.matgenlab.core. ...
                MoleculeMatcher(0.02, inchi);
            dictionary = matcher.as_dict();
            testCase.verifyEqual(dictionary.tolerance, 0.02);
            testCase.verifyEqual(dictionary.mapper.angle_tolerance, 30);
            testCase.verifyError(@() matcher.get_rmsd([], []), expected);
        end
    end

    methods (Access = private)
        function molecule = loadMolecule(testCase, filename)
            xyz = kssolv.analysis.matgenlab.io.xyz.XYZ.from_file( ...
                fullfile(testCase.FixtureRoot, filename));
            molecule = xyz.molecule;
        end
    end
end
