classdef HHITest < matlab.unittest.TestCase
    methods (Test)
        function officialValues(testCase)
            model = kssolv.analysis.matgenlab.analysis.HHIModel();
            [production, reserve] = model.get_hhi("He");
            testCase.verifyEqual([production, reserve], [3200, 3900]);
            testCase.verifyEqual(model.get_hhi_production("Li2O"), ...
                1614.96, AbsTol=0.1);
            testCase.verifyEqual(model.get_hhi_reserve("Li2O"), ...
                2218.90, AbsTol=0.1);
        end

        function designationAndErrors(testCase)
            model = kssolv.analysis.matgenlab.analysis.HHIModel();
            testCase.verifyEqual(model.get_hhi_designation(1400), "low");
            testCase.verifyEqual(model.get_hhi_designation(1800), "medium");
            testCase.verifyEqual(model.get_hhi_designation(3000), "high");
            testCase.verifyEmpty(model.get_hhi_designation([]));
            [production, reserve] = model.get_hhi("Xx2");
            testCase.verifyEmpty(production);
            testCase.verifyEmpty(reserve);
        end
    end
end
