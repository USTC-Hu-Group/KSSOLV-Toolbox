classdef DisorderInventoryTest < matlab.unittest.TestCase
    properties
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "disorder_2026.5.4.json")));
        end
    end

    methods (Test)
        function orderedCsClMatchesFrozenOracle(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_prototype("CsCl", {"Mo", "W"}, "a", 4);
            cross = kssolv.analysis.matgenlab.analysis. ...
                get_warren_cowley_parameters(structure, 3.4, 0.3);
            same = kssolv.analysis.matgenlab.analysis. ...
                get_warren_cowley_parameters(structure, 4, 0.2);
            testCase.verifyEqual(cross("Mo|W"), ...
                testCase.oracle.ordered_cross, AbsTol = 1e-14);
            testCase.verifyEqual(cross("W|Mo"), ...
                testCase.oracle.ordered_cross, AbsTol = 1e-14);
            testCase.verifyEqual(same("Mo|Mo"), ...
                testCase.oracle.ordered_same, AbsTol = 1e-14);
        end

        function swappedSupercellMatchesFrozenOracle(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_prototype("CsCl", {"Mo", "W"}, "a", 4);
            structure = structure.make_supercell([4, 4, 4]);
            structure = structure.replace(1, "W");
            structure = structure.replace(structure.num_sites, "Mo");
            values = kssolv.analysis.matgenlab.analysis. ...
                get_warren_cowley_parameters(structure, 3.4, 0.3);
            testCase.verifyEqual(values("Mo|W"), ...
                testCase.oracle.swapped_cross, AbsTol = 1e-14);
            testCase.verifyEqual(values("W|Mo"), ...
                testCase.oracle.swapped_reverse, AbsTol = 1e-14);
        end

        function emptyShellHasStableError(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_prototype("CsCl", {"Mo", "W"}, "a", 4);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.analysis. ...
                get_warren_cowley_parameters(structure, 2, 0.01), ...
                "KSSOLV:Matgenlab:Disorder:EmptyShell");
        end
    end
end
