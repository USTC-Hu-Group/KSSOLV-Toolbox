classdef DiffractionTest < matlab.unittest.TestCase
    methods (Test)
        function familyGrouping(testCase)
            hkls = [ ...
                1,0,0; -1,0,0; 0,1,0; 0,-1,0; 0,0,1; 0,0,-1; ...
                1,1,0; -1,-1,0];
            families = kssolv.analysis.matgenlab.analysis. ...
                get_unique_families(hkls);
            testCase.verifyEqual(numel(families), 2);
            testCase.verifyEqual([families.multiplicity], [6, 2]);
            testCase.verifyEqual(families(1).hkl, [1, 0, 0]);
        end

        function patternsMatchFrozenPymatgen(testCase)
            testCase.assumeTrue( ...
                kssolv.analysis.matgenlab.test.support. ...
                PymatgenOracle.isAvailable());
            import kssolv.analysis.matgenlab.core.Lattice
            import kssolv.analysis.matgenlab.core.Structure
            import kssolv.analysis.matgenlab.analysis.XRDCalculator
            import kssolv.analysis.matgenlab.analysis.NDCalculator
            structure = Structure(Lattice.cubic(4.2), ...
                {"Cs", "Cl"}, [0,0,0; 0.5,0.5,0.5]);
            calculators = {XRDCalculator("CuKa"), NDCalculator(1.54184)};
            modules = [ ...
                "pymatgen.analysis.diffraction.xrd", ...
                "pymatgen.analysis.diffraction.neutron"];
            symbols = ["XRDCalculator", "NDCalculator"];
            arguments = {{"CuKa"}, {1.54184}};
            for index = 1:2
                request = struct( ...
                    "module", modules(index), ...
                    "symbol", symbols(index), ...
                    "construct", struct("args", {arguments{index}}), ...
                    "operations", {{struct( ...
                        "kind", "call", ...
                        "name", "get_pattern", ...
                        "args", {{structure.as_dict(), true, [0,90]}})}});
                reference = ...
                    kssolv.analysis.matgenlab.test.support. ...
                    PymatgenOracle.execute(request);
                if iscell(reference.results)
                    expected = reference.results{1};
                else
                    expected = reference.results(1);
                end
                actual = calculators{index}.get_pattern(structure);
                testCase.verifyEqual(actual.x, expected.x, AbsTol=2e-10);
                testCase.verifyEqual(actual.y, expected.y, AbsTol=2e-9);
                testCase.verifyEqual(actual.d_hkls, ...
                    expected.d_hkls, AbsTol=2e-12);
                testCase.verifyEqual(numel(actual.hkls), ...
                    numel(expected.hkls));
                for peakIndex = 1:numel(actual.hkls)
                    actualFamilies = actual.hkls{peakIndex};
                    expectedFamilies = expected.hkls{peakIndex};
                    testCase.verifyEqual( ...
                        [actualFamilies.multiplicity], ...
                        reshape([expectedFamilies.multiplicity], 1, []));
                    for familyIndex = 1:numel(actualFamilies)
                        testCase.verifyEqual( ...
                            actualFamilies(familyIndex).hkl, ...
                            reshape(expectedFamilies(familyIndex).hkl,1,[]));
                    end
                end
            end
        end

        function patternRoundTripAndUnscaled(testCase)
            pattern = kssolv.analysis.matgenlab.analysis. ...
                DiffractionPattern([10,20], [1,2], ...
                {{struct("hkl",[1,0,0],"multiplicity",6)}, ...
                 {struct("hkl",[1,1,0],"multiplicity",12)}}, ...
                [3,2]);
            restored = kssolv.analysis.matgenlab.analysis. ...
                DiffractionPattern.from_dict(pattern.as_dict());
            testCase.verifyEqual(restored.x, pattern.x);
            testCase.verifyEqual(restored.y, pattern.y);
            testCase.verifyEqual(restored.d_hkls, pattern.d_hkls);
            scaled = pattern.copy();
            scaled.normalize("max", 100);
            testCase.verifyEqual(scaled.y, [50;100]);
        end

        function sharedPlottingApi(testCase)
            import kssolv.analysis.matgenlab.analysis.XRDCalculator
            import kssolv.analysis.matgenlab.core.*
            original = get(groot, "defaultFigureVisible");
            cleanup = onCleanup(@() ...
                set(groot, "defaultFigureVisible", original));
            set(groot, "defaultFigureVisible", "off");
            structure = Structure(Lattice.cubic(4.2), ...
                {"Cs", "Cl"}, [0,0,0; .5,.5,.5]);
            calculator = XRDCalculator("CuKa");
            axesHandle = calculator.get_plot(structure);
            testCase.verifyTrue(isgraphics(axesHandle, "axes"));
            calculator.show_plot(structure, "annotate_peaks", "none");
            figureHandle = calculator.plot_structures({structure});
            testCase.verifyTrue(isgraphics(figureHandle, "figure"));
            close all force
            clear cleanup
        end
    end
end
