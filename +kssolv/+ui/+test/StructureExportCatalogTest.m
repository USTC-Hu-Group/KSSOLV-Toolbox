classdef StructureExportCatalogTest < matlab.unittest.TestCase
    %STRUCTUREEXPORTCATALOGTEST Writable matgenlab format discovery.

    methods (Test)
        function listsWritableAlternativeStructureFormats(testCase)
            model = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            formats = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                list(model, "cif");
            names = string({formats.format});

            testCase.verifyNotEmpty(formats);
            testCase.verifyFalse(any(names == "cif"));
            testCase.verifyTrue(any(names == "poscar"));
            testCase.verifyTrue(any(names == "xyz"));
            testCase.verifyTrue(all(strlength(string({formats.extension})) > 0));
            testCase.verifyEqual(names(1:3), ...
                ["poscar", "vasp", "xyz"]);
        end

        function prioritizesCommonCrystalFormats(testCase)
            model = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            formats = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                list(model);

            testCase.verifyEqual(string({formats(1:4).format}), ...
                ["cif", "poscar", "vasp", "xyz"]);
            testCase.verifyEqual(string({formats(1:4).extension}), ...
                ["cif", "poscar", "vasp", "xyz"]);
        end

        function listsMoleculeFormatsFromMoleculeRegistry(testCase)
            model = kssolv.analysis.matgenlab.core.Molecule( ...
                {"H", "H"}, [0, 0, 0; 0, 0, 0.74]);
            formats = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                list(model, "xyz");
            names = string({formats.format});

            testCase.verifyFalse(any(names == "xyz"));
            testCase.verifyTrue(any(names == "gaussian"));
            testCase.verifyTrue(any(names == "pdb"));
        end

        function everyListedMoleculeFormatCanBeSerialized(testCase)
            model = kssolv.analysis.matgenlab.core.Molecule( ...
                {"H", "H"}, [0, 0, 0; 0, 0, 0.74]);
            formats = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                list(model);

            for index = 1:numel(formats)
                text = model.to("", formats(index).format);
                testCase.verifyGreaterThan(strlength(string(text)), 0, ...
                    "Format did not serialize: " + formats(index).format);
            end
        end

        function validatesWritableFormatsAndSafeFilenames(testCase)
            model = kssolv.analysis.matgenlab.core.Structure( ...
                eye(3) * 4, {"Si"}, [0, 0, 0]);
            descriptor = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                writableFormat(model, "poscar");
            filename = kssolv.ui.scene.atomic.StructureExportCatalog. ...
                defaultFilename("Si/unsafe", "poscar", descriptor);

            testCase.verifyEqual(filename, "Si-unsafe.poscar");
            testCase.verifyError(@()kssolv.ui.scene.atomic. ...
                StructureExportCatalog.writableFormat(model, "chgcar"), ...
                "KSSOLV:CrystalViewer:ExportFormat");
        end
    end
end
