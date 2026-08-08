classdef ProjectTest < matlab.unittest.TestCase
    %PROJECTTEST 测试 Project 类

    %   开发者：杨柳
    %   版权 2024 合肥瀚海量子科技有限公司

    properties
        ksFilePath string = 'ks.ks'
    end

    methods(Test)
        function project = generateKsFileTest(testCase)
            % 测试项目文件生成
            import kssolv.services.filemanager.*
            
            project = Project();
            
            workflowParent = project.children{1, 1};
            workflow1 = Workflow('Workflow1');
            workflow2 = Workflow('Workflow2');
            workflowParent.addChildrenItem(workflow1);
            workflowParent.addChildrenItem(workflow2);
            
            structureParent = project.children{2, 1};
            structure1 = Structure('Structure1');
            structure2 = Structure('Structure2');
            structureParent.addChildrenItem(structure1);
            structureParent.addChildrenItem(structure2);
            
            project.saveToKsFile(testCase.ksFilePath);
        end

        function project = loadKsFileTest(testCase)
            % 测试项目文件加载
            import kssolv.services.filemanager.Project
            project = Project.loadKsFile(testCase.ksFilePath);
        end

        function json = encodeProjectToJSONTest(testCase)
            % 测试将项目文件编码为 JSON
            import kssolv.services.filemanager.Project
            project = testCase.loadKsFileTest();
            json = project.encodeToJSON(1);
            fprintf(json);
        end

        function importsMaterialsProjectStructure(testCase)
            project = kssolv.services.filemanager.Project();
            structureRoot = project.findChildrenItem("Structure");
            model = kssolv.analysis.matgenlab.core.Structure( ...
                4 * eye(3), {"Si"}, [0, 0, 0]);

            item = structureRoot.importMaterialsProjectStructure( ...
                model, "mp-149", "Si", false);

            testCase.verifyEqual(item.label, "Si (mp-149)");
            testCase.verifyEqual(item.description, ...
                "Materials Project: mp-149");
            testCase.verifyEqual(item.parent, structureRoot);
            testCase.verifyEqual(string( ...
                item.data.MatgenlabObject.composition.reduced_formula), ...
                "Si");
            testCase.verifyTrue(project.isDirty);
        end
    end
end
