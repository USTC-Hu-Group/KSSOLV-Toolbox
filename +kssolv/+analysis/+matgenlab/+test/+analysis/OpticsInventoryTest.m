classdef OpticsInventoryTest < matlab.unittest.TestCase
    properties
        fixture
        oracle
    end

    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.fixture = fullfile(pwd, "+kssolv", "+analysis", ...
                "+matgenlab", "+test", "+analysis", "+fixtures", ...
                "+optics", "vasprun.dielectric_6.0.8.xml.gz");
            testCase.oracle = jsondecode(fileread(fullfile(pwd, "dev", ...
                "matgenlab", "oracles", "optics_2026.5.4.json")));
        end
    end

    methods (Test)
        function officialVasprunMatchesFrozenOracle(testCase)
            vasprun = kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
                testCase.fixture, "parse_dos", false, ...
                "parse_eigen", false, "parse_potcar_file", false);
            analysis = kssolv.analysis.matgenlab.analysis. ...
                DielectricAnalysis.from_vasprun(vasprun);
            testCase.verifyEqual(size(analysis.n), ...
                reshape(testCase.oracle.shape, 1, []));
            indices = reshape(testCase.oracle.energy_indices, 1, []) + 1;
            testCase.verifyEqual(analysis.energies(indices), ...
                reshape(testCase.oracle.energies, 1, []), AbsTol = 1e-14);
            testCase.verifyEqual(analysis.wavelengths(indices), ...
                reshape(testCase.oracle.wavelengths, 1, []), ...
                RelTol = 1e-14);
            for index = 1:numel(testCase.oracle.samples)
                sample = testCase.oracle.samples(index);
                row = sample.index(1) + 1;
                column = sample.index(2) + 1;
                for name = ["eps_real", "eps_imag", "n", ...
                        "k", "R", "L", "T"]
                    actual = analysis.(name)(row, column);
                    testCase.verifyEqual(actual, sample.(name), ...
                        AbsTol = 1e-13);
                end
            end
        end

        function directConstructionUsesElementwiseEquations(testCase)
            energies = [1, 2];
            realPart = [4, 9; 1, -1];
            imaginaryPart = zeros(2);
            analysis = kssolv.analysis.matgenlab.analysis. ...
                DielectricAnalysis(energies, realPart, imaginaryPart);
            testCase.verifyEqual(analysis.wavelengths, ...
                [1239.8419843320028, 619.9209921660014], RelTol = 1e-15);
            testCase.verifyEqual(analysis.n(1, :), [2, 3], ...
                AbsTol = 1e-15);
            testCase.verifyEqual(analysis.k(2, 2), 1, ...
                AbsTol = 1e-15);
            testCase.verifyEqual(analysis.T, 1 - analysis.R - analysis.L);
        end
    end
end
