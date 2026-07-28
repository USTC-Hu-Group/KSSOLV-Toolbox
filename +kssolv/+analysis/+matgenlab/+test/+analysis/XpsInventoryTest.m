classdef XpsInventoryTest < matlab.unittest.TestCase
    methods (Test)
        function officialLiFDosMatchesFrozenOracle(testCase)
            fixture = fullfile(pwd, "+kssolv", "+analysis", ...
                "+matgenlab", "+test", "+analysis", "+fixtures", ...
                "+xps", "vasprun.LiF.xml.gz");
            expected = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "xps_2026.5.4.json")));
            vasprun = kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
                fixture, "parse_potcar_file", false);
            spectrum = kssolv.analysis.matgenlab.analysis.XPS. ...
                from_dos(vasprun.complete_dos);
            testCase.verifyEqual(length(spectrum), expected.length);
            indices = reshape(expected.indices, 1, []) + 1;
            testCase.verifyEqual(spectrum.x(indices).', ...
                reshape(expected.x, 1, []), AbsTol = 1e-13);
            testCase.verifyEqual(spectrum.y(indices).', ...
                reshape(expected.y, 1, []), AbsTol = 1e-13);
            testCase.verifyEqual(max(spectrum.y), expected.maximum);
            testCase.verifyEqual(sum(spectrum.y), expected.sum, ...
                AbsTol = 1e-13);
            testCase.verifyEqual(spectrum.XLABEL, "Binding Energy (eV)");
            testCase.verifyEqual(spectrum.YLABEL, "Intensity");
            spectrum.smear(0.3);
            testCase.verifyEqual(length(spectrum), expected.length);
        end
    end
end
