classdef SubstitutorTest < matlab.unittest.TestCase
    methods (Test)
        function upstreamMiniTableCases(testCase)
            table = {"O2-", "O2-", 1.0; "S2-", "S2-", 1.3; ...
                "Li1+", "Li1+", 1.0; "Na1+", "Na1+", 1.0; ...
                "Li1+", "Na1+", 0.4; "O2-", "S2-", 0.9};
            substitutor = kssolv.analysis.matgenlab.core.Substitutor( ...
                1e-3, 0.1, "lambda_table", table, "alpha", -5);
            substitutions = substitutor.pred_from_list({"O2-", "Li+"});
            testCase.verifyEqual(numel(substitutions), 4);
            composition = kssolv.analysis.matgenlab.core.Composition( ...
                {"O2-", 1; "Li+", 2});
            balanced = substitutor.pred_from_comp(composition);
            testCase.verifyEqual(numel(balanced), 4);
        end

        function structurePredictionTransformsSpecies(testCase)
            table = {"O2-", "O2-", 1.0; "S2-", "S2-", 1.3; ...
                "Li1+", "Li1+", 1.0; "Na1+", "Na1+", 1.0; ...
                "Li1+", "Na1+", 0.4; "O2-", "S2-", 0.9};
            substitutor = kssolv.analysis.matgenlab.core.Substitutor( ...
                1e-3, 0.1, "lambda_table", table, "alpha", -5);
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(4), ...
                {"Li+", "Li+", "O2-"}, ...
                [0, 0, 0; 0.5, 0.5, 0; 0.25, 0.25, 0.25]);
            records = {struct("structure", structure, "id", "fixture")};
            predictions = substitutor.pred_from_structures( ...
                {"Na+", "O2-"}, records);
            testCase.verifyNotEmpty(predictions);
            testCase.verifyEqual(predictions(1).formula, "Na2 O1");
            testCase.verifyEqual(predictions(1).history{1}.source, "fixture");
        end

        function msonRoundTrip(testCase)
            table = {"O2-", "O2-", 1; "Li+", "Li+", 1};
            original = kssolv.analysis.matgenlab.core.Substitutor( ...
                0.02, 0.1, "lambda_table", table, "alpha", -4);
            restored = kssolv.analysis.matgenlab.core.Substitutor. ...
                from_dict(original.as_dict());
            testCase.verifyEqual(restored.threshold, 0.02);
            testCase.verifyEqual(restored.probability.alpha, -4);
        end
    end
end
