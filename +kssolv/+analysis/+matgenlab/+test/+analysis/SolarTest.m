classdef SolarTest < matlab.unittest.TestCase
    methods (Test)
        function tensorAndAbsorptionOracles(testCase)
            import kssolv.analysis.matgenlab.analysis.solar.*
            testCase.verifyEqual(to_matrix(1,2,3,4,5,6), ...
                [1,4,6;4,2,5;6,5,3]);
            rows=[2,3,4,.1,.2,.3;4,5,6,.2,.3,.4];
            values=parse_dielectric_data(rows);
            expected=zeros(2,3);
            for index=1:2
                expected(index,:)=sort(eig(to_matrix( ...
                    rows(index,1),rows(index,2),rows(index,3), ...
                    rows(index,4),rows(index,5),rows(index,6)))).';
            end
            testCase.verifyEqual(values,expected,AbsTol=1e-14);
            [energy,coefficient]=absorption_coefficient( ...
                {[1,2],rows,rows/10});
            testCase.verifyEqual(energy,[1;2]);
            testCase.verifyGreaterThan(coefficient(2),coefficient(1));
        end

        function officialSolarFixture(testCase)
            path="/tmp/matgenlab-plan.tMNeV8/pymatgen-2026.5.4/" + ...
                "test-files/analysis/solar/vasprun.xml";
            testCase.assumeTrue(isfile(path), ...
                "Frozen solar vasprun fixture unavailable.");
            [energy,absorption,directGap,indirectGap]= ...
                kssolv.analysis.matgenlab.analysis.solar.optics(path);
            testCase.verifyEqual(numel(energy),5000);
            testCase.verifyEqual(directGap,.8539,AbsTol=1e-12);
            testCase.verifyEqual(indirectGap,.8539,AbsTol=1e-12);
            efficiency=kssolv.analysis.matgenlab.analysis.solar. ...
                slme(energy,absorption*100,indirectGap,indirectGap);
            testCase.verifyEqual(efficiency, ...
                27.730157186840437,AbsTol=2e-9);
        end
    end
end
