classdef StructureTest < matlab.unittest.TestCase
    %STRUCTURETEST Project structure creation contracts.

    methods (Test)
        function createsNamedBlankMoleculeWithExplicitTopology(testCase)
            folder = kssolv.services.filemanager.Structure("Structure");
            item = folder.createBlankMolecule(false);
            model = item.data.MatgenlabObject;
            testCase.verifyClass(model, ...
                "kssolv.analysis.matgenlab.core.Molecule");
            testCase.verifyEqual(model.num_sites, 0);
            testCase.verifyEqual(model.properties.topology.bonds, zeros(0,3));
            testCase.verifyEqual(string(model.properties.topology.origin), ...
                "source");
            testCase.verifyEqual(string(item.label), "Molecule 1");
        end
        function blankStructureIsEmptyAndEditable(testCase)
            project = kssolv.services.filemanager.Project();
            folder = project.findChildrenItem("Structure");

            item = folder.createBlankStructure(false);

            testCase.verifySameHandle(item.parent, folder);
            testCase.verifyEqual(item.label, "Structure 1");
            testCase.verifyEqual(item.data.MatgenlabObject.num_sites, 0);
            testCase.verifyEqual( ...
                item.data.MatgenlabObject.lattice.matrix, eye(3) * 10, ...
                AbsTol = 1e-12);
            testCase.verifyEmpty(item.data.KSSOLVSetupObject.atomList);
            testCase.verifyEmpty(item.data.KSSOLVSetupObject.xyzList);
            testCase.verifyTrue(project.isDirty);

            result = kssolv.modeling.CommandExecutor.execute( ...
                item.data.MatgenlabObject, "add_atom", ...
                struct("species", "Si", "coordinates", [0, 0, 0]));
            testCase.verifyEqual(result.model.num_sites, 1);
            testCase.verifyEqual(result.model(1).specie.symbol, "Si");
        end

        function blankStructureUsesNextAvailableDefaultName(testCase)
            project = kssolv.services.filemanager.Project();
            folder = project.findChildrenItem("Structure");

            first = folder.createBlankStructure(false);
            second = folder.createBlankStructure(false);

            testCase.verifyEqual(first.label, "Structure 1");
            testCase.verifyEqual(second.label, "Structure 2");
        end
    end
end
