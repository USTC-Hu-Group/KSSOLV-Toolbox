classdef XYZTest < matlab.unittest.TestCase
    methods (Test)
        function writesPymatgenCompatibleText(testCase)
            coordinates = [
                0, 0, 0
                0, 0, 1.089
                1.026719, 0, -0.363
                -0.513360, -0.889165, -0.363
                -0.513360, 0.889165, -0.363
                ];
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["C", "H", "H", "H", "H"], coordinates);
            xyz = kssolv.analysis.matgenlab.io.xyz.XYZ(molecule);
            expected = strjoin([
                "5"
                "H4 C1"
                "C 0.000000 0.000000 0.000000"
                "H 0.000000 0.000000 1.089000"
                "H 1.026719 0.000000 -0.363000"
                "H -0.513360 -0.889165 -0.363000"
                "H -0.513360 0.889165 -0.363000"
                ], newline);
            testCase.verifyEqual(string(xyz), expected);
        end

        function parsesAlternateScientificNotation(testCase)
            contents = strjoin([
                "2"
                "Random"
                "C 2.39132145462 -0.700993488928 -7.222*^-06"
                "C 1.16730636786 -1.38166622735 -2.771D-06"
                ], newline);
            xyz = kssolv.analysis.matgenlab.io.xyz.XYZ.from_str(contents);
            testCase.verifyEqual(xyz.molecule(1).z, -7.222e-6, AbsTol = 1e-15);
            testCase.verifyEqual(xyz.molecule(2).z, -2.771e-6, AbsTol = 1e-15);
        end

        function multiFrameRoundTrip(testCase)
            first = kssolv.analysis.matgenlab.core.Molecule( ...
                "He", [0, 0, 0]);
            second = kssolv.analysis.matgenlab.core.Molecule( ...
                "He", [1, 2, 3]);
            original = kssolv.analysis.matgenlab.io.xyz.XYZ( ...
                {first, second}, 3);
            restored = kssolv.analysis.matgenlab.io.xyz.XYZ.from_str( ...
                string(original));
            testCase.verifyEqual(numel(restored.all_molecules), 2);
            testCase.verifyEqual(restored.molecule(1).coords, [1, 2, 3]);
        end
    end
end
