classdef MoleculeSceneBuilderTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function configureKssolvPaths(~)
            addpath(fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+core", "kssolv-3o"));
            KSSOLV.startup();
        end
    end

    methods (Test)
        function xyzUsesOpenBabelAndIsSerializable(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["O", "H", "H"], ...
                [0, 0, 0; 0.9572, 0, 0; -0.239, 0.927, 0]);
            molecule.properties.input_format = "xyz";
            scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                molecule, requestId = "water");
            testCase.verifyEqual(scene.schemaVersion, "2.0");
            testCase.verifyEqual(scene.kind, "molecule");
            testCase.verifyEqual(scene.molecule.atomCount, 3);
            testCase.verifyEqual(scene.analysis.algorithm, "OpenBabelNN");
            testCase.verifyNumElements(scene.bondInstances, 2);
            testCase.verifyEqual([scene.bondInstances.order], [1, 1]);
            testCase.verifyEqual(string({scene.bondInstances.origin}), ...
                ["OpenBabelNN", "OpenBabelNN"]);
            jsondecode(jsonencode(scene));
        end

        function sourceTopologyHasPriority(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["C", "C"], [-0.67, 0, 0; 0.67, 0, 0]);
            molecule.properties.topology = struct( ...
                "bonds", [1, 2, 2], "origin", "source");
            scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build(molecule);
            testCase.verifyEqual(scene.analysis.algorithm, "Source");
            testCase.verifyEqual(scene.bondRelations.order, 2);
            testCase.verifyEqual(scene.bondRelations.origin, "source");
        end

        function molecularFixturesRenderThroughStructureIO(testCase)
            root = fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+services", "+fileparser", "+test", ...
                "Structure");
            files = ["water.xyz", "water.pdb", ...
                "water.mol2", "water.sdf"];
            expectedAlgorithms = ["OpenBabelNN", "OpenBabelNN", ...
                "Source", "Source"];
            for index = 1:numel(files)
                input = kssolv.services.fileparser.StructureIO( ...
                    fullfile(root, files(index)));
                scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                    input.MatgenlabObject);
                testCase.verifyEqual(scene.molecule.inputFormat, ...
                    erase(extractAfter(files(index), "."), "."));
                testCase.verifyEqual(scene.analysis.algorithm, ...
                    expectedAlgorithms(index));
                testCase.verifyNumElements(scene.atomInstances, 3);
                testCase.verifyNumElements(scene.bondInstances, 2);
            end
        end

        function rejectsCrystalOnlyMetadata(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                ["H", "H"], [0, 0, 0; 0, 0, 0.74]);
            scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build(molecule);
            scene.structure = struct("lattice", eye(3));
            testCase.verifyError(@() ...
                kssolv.ui.scene.atomic.CrystalSceneValidator.validate(scene), ...
                "KSSOLV:CrystalViewer:SceneSchema");
        end

        function everyRegisteredMoleculeFixtureBuildsScene(testCase)
            root = fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+services", "+fileparser", "+test", ...
                "Structure");
            formats = [ ...
                "cml", "com", "g03", "g09", "gaussian", ...
                "gaussian-out", "gjf", "inp", "mdl", "ml2", ...
                "mol", "mol2", "mrv", "pdb", "sd", "sdf", ...
                "sy2", "xyz"];
            for format = formats
                input = kssolv.services.fileparser.StructureIO( ...
                    fullfile(root, "water." + format), format);
                scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                    input.MatgenlabObject);
                testCase.verifyEqual(scene.kind, "molecule");
                testCase.verifyGreaterThan(scene.molecule.atomCount, 0);
                testCase.verifyEqual(scene.molecule.inputFormat, format);
            end
        end

        function multipleXyzFramesUseFirstFrameAndWarn(testCase)
            source = fullfile(KSSOLV_Toolbox.RootDirectory, ...
                "+kssolv", "+analysis", "+matgenlab", "+test", ...
                "+io", "+fixtures", "+xyz", "multiple_frame.xyz");
            input = kssolv.services.fileparser.StructureIO(source, "xyz");
            scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                input.MatgenlabObject, includeConnectivity = false);
            testCase.verifyEqual(scene.molecule.frameIndex, 1);
            testCase.verifyGreaterThan(scene.molecule.frameCount, 1);
            testCase.verifyEqual(scene.molecule.atomCount, 62);
            testCase.verifyTrue(any(string({scene.warnings.code}) == ...
                "MULTIFRAME_FIRST_FRAME"));
        end

        function singletonTransportCollectionsRemainArrays(testCase)
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                "He", [0, 0, 0], charge_spin_check = false);
            scene = kssolv.ui.scene.atomic.MoleculeSceneBuilder.build( ...
                molecule, includeConnectivity = false);
            transport = ...
                kssolv.ui.scene.atomic.CrystalSceneSerializer. ...
                transportScene(scene);
            encoded = string(jsonencode(transport));

            testCase.verifyTrue(contains(encoded, '"sites":['));
            testCase.verifyTrue(contains(encoded, '"atomInstances":['));
            testCase.verifyTrue(contains(encoded, '"bondRelations":['));
            testCase.verifyTrue(contains(encoded, '"bondInstances":['));
            testCase.verifyTrue(contains(encoded, '"polyhedra":['));
            testCase.verifyTrue(contains(encoded, '"warnings":['));
        end
    end
end
