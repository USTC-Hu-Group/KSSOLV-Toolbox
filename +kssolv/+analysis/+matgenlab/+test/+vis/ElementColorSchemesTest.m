classdef ElementColorSchemesTest < matlab.unittest.TestCase
    %ELEMENTCOLORSCHEMESTEST Authoritative element-palette regression tests.

    methods (Test)
        function schemesCoverEveryElementAndNamedHydrogenIsotope(testCase)
            schemes=testCase.schemes();
            expected=kssolv.analysis.matgenlab.core. ...
                PeriodicTableData.symbols(true);
            testCase.verifyEqual(sort(string(fieldnames(schemes.Jmol))), ...
                sort(expected));
            testCase.verifyEqual(sort(string(fieldnames(schemes.VESTA))), ...
                sort(expected));
        end

        function jmolMatchesOfficialCpkPalette(testCase)
            % https://jmol.sourceforge.net/jscolors/
            schemes=testCase.schemes();
            testCase.verifyEqual(reshape(schemes.Jmol.C,1,[]), ...
                [144,144,144]);
            testCase.verifyEqual(reshape(schemes.Jmol.Na,1,[]), ...
                [171,92,242]);
            testCase.verifyEqual(reshape(schemes.Jmol.D,1,[]), ...
                [255,255,192]);
            testCase.verifyEqual(reshape(schemes.Jmol.Mt,1,[]), ...
                [235,0,38]);
            testCase.verifyEqual(reshape(schemes.Jmol.Og,1,[]), ...
                [255,20,147]);
        end

        function vestaMatchesStableElementsFile(testCase)
            % VESTA 3.5.8 elements.ini, converted to nearest 8-bit RGB.
            % https://jp-minerals.org/vesta/en/download.html
            schemes=testCase.schemes();
            testCase.verifyEqual(reshape(schemes.VESTA.C,1,[]), ...
                [129,73,41]);
            testCase.verifyEqual(reshape(schemes.VESTA.Na,1,[]), ...
                [250,221,61]);
            testCase.verifyEqual(reshape(schemes.VESTA.Ag,1,[]), ...
                [184,188,190]);
            testCase.verifyEqual(reshape(schemes.VESTA.U,1,[]), ...
                [122,162,170]);
            testCase.verifyEqual(reshape(schemes.VESTA.Og,1,[]), ...
                [77,77,77]);
        end
    end

    methods (Static, Access=private)
        function value=schemes()
            root=fileparts(which( ...
                "kssolv.analysis.matgenlab.vis.StructureVis"));
            value=jsondecode(fileread(fullfile( ...
                root,"ElementColorSchemes.json")));
        end
    end
end
