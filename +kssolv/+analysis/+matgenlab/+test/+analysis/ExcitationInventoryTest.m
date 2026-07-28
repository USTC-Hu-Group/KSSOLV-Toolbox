classdef ExcitationInventoryTest < matlab.unittest.TestCase
    methods (Test)
        function subclassUsesEnergyLabelsAndSpectrumBehavior(testCase)
            x = (1:4).';
            y = [2; 4; 6; 8];
            spectrum = kssolv.analysis.matgenlab.analysis. ...
                ExcitationSpectrum(x, y);
            testCase.verifyEqual(spectrum.x, x);
            testCase.verifyEqual(spectrum.y, y);
            testCase.verifyEqual(spectrum.XLABEL, "Energy (eV)");
            testCase.verifyEqual(spectrum.YLABEL, "Intensity");
            testCase.verifyTrue(contains(string(spectrum), "Energy (eV)"));
            doubled = spectrum * 2;
            testCase.verifyClass(doubled, ...
                "kssolv.analysis.matgenlab.analysis.ExcitationSpectrum");
            testCase.verifyEqual(doubled.y, y * 2);
        end
    end
end
