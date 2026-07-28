classdef SpglibMexCompatibilityTest < matlab.unittest.TestCase
    methods (Test)
        function mexLoadsAndReportsVersion(testCase)
            version = kssolv.analysis.spglib.Spglib.getVersion("full");
            testCase.verifyNotEmpty(string(version));
            testCase.verifyMatches(string(version), "^\d+\.\d+\.\d+");
        end

        function macBinaryHasRelocatableRpaths(testCase)
            testCase.assumeTrue(ismac);
            root = KSSOLV_Toolbox.RootDirectory;
            binary = fullfile(root, "+kssolv", "+analysis", ...
                "+spglib", "symspg.mexmaca64");
            [status, output] = system(sprintf( ...
                '/usr/bin/otool -l "%s"', binary));
            testCase.assertEqual(status, 0);
            testCase.verifyFalse(contains(string(output), ...
                "/Applications/MATLAB_R"));
            testCase.verifyTrue(contains(string(output), "@executable_path"));
        end
    end
end
