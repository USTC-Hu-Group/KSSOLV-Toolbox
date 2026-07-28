classdef DisorderTest < matlab.unittest.TestCase
    methods (Test)
        function officialCsClOracles(testCase)
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_prototype("CsCl", {"Mo", "W"}, a=4);
            parameters = kssolv.analysis.matgenlab.analysis. ...
                get_warren_cowley_parameters(structure, 3.4, 0.3);
            testCase.verifyEqual(parameters("Mo|W"), -1, AbsTol=1e-14);
            parameters = kssolv.analysis.matgenlab.analysis. ...
                get_warren_cowley_parameters(structure, 4, 0.2);
            testCase.verifyEqual(parameters("Mo|Mo"), 1, AbsTol=1e-14);

            structure = structure.make_supercell(4);
            structure = structure.replace(1, "W");
            structure = structure.replace(structure.num_sites, "Mo");
            parameters = kssolv.analysis.matgenlab.analysis. ...
                get_warren_cowley_parameters(structure, 3.4, 0.3);
            testCase.verifyEqual(parameters("Mo|W"), ...
                -0.9453125, AbsTol=1e-14);
            testCase.verifyEqual(parameters("Mo|W"), ...
                parameters("W|Mo"), AbsTol=1e-14);
        end
    end
end
