classdef PiezoSensitivityInventoryTest < matlab.unittest.TestCase
    properties
        oracle
        structure
        pointops
        sharedops
    end
    methods (TestMethodSetup)
        function loadOracle(testCase)
            testCase.oracle=jsondecode(fileread(fullfile(pwd,"dev", ...
                "matgenlab","oracles", ...
                "piezo_sensitivity_2026.5.4.json")));
            testCase.structure=kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(testCase.oracle.structure);
            testCase.pointops=decodePointOperations( ...
                testCase.oracle.pointops);
            testCase.sharedops=decodeSharedOperations( ...
                testCase.oracle.sharedops);
            rng(71342,"twister");
        end
    end
    methods (Test)
        function microscopicContainersPreserveFrozenData(testCase)
            bec=kssolv.analysis.matgenlab.analysis. ...
                BornEffectiveCharge(testCase.structure, ...
                testCase.oracle.bec,testCase.pointops);
            ist=kssolv.analysis.matgenlab.analysis. ...
                InternalStrainTensor(testCase.structure, ...
                testCase.oracle.ist,testCase.pointops);
            fcm=kssolv.analysis.matgenlab.analysis. ...
                ForceConstantMatrix(testCase.structure, ...
                testCase.oracle.fcm,testCase.pointops, ...
                testCase.sharedops);
            testCase.verifyEqual(bec.bec,testCase.oracle.bec);
            testCase.verifyEqual(ist.ist,testCase.oracle.ist);
            testCase.verifyEqual(fcm.fcm,testCase.oracle.fcm);
        end

        function bornOperationsAndRandomTensorObeySymmetry(testCase)
            object=kssolv.analysis.matgenlab.analysis. ...
                BornEffectiveCharge(testCase.structure, ...
                testCase.oracle.bec,testCase.pointops);
            operations=object.get_BEC_operations();
            relations=zeros(numel(operations),3);
            for index=1:numel(operations)
                relation=operations{index};
                relations(index,:)=[relation.target-1, ...
                    relation.source-1,numel(relation.operations)];
            end
            testCase.verifyEqual(relations, ...
                testCase.oracle.bec_relations);
            random=object.get_rand_BEC();
            testCase.verifyEqual(squeeze(sum(random,1)),zeros(3), ...
                AbsTol=2e-14);
            verifyBecRelations(testCase,random,operations,1e-12);
        end

        function internalStrainOperationsAndRandomTensorObeySymmetry(testCase)
            object=kssolv.analysis.matgenlab.analysis. ...
                InternalStrainTensor(testCase.structure, ...
                testCase.oracle.ist,testCase.pointops);
            operations=object.get_IST_operations();
            random=object.get_rand_IST();
            for atom=1:numel(operations)
                for index=1:numel(operations{atom})
                    mapping=operations{atom}{index};
                    expected=mapping.operation.transform_tensor( ...
                        squeeze(random(mapping.source,:,:,:)));
                    testCase.verifyEqual(squeeze(random(atom,:,:,:)), ...
                        expected,AbsTol=2e-12);
                end
                for direction=1:3
                    slice=squeeze(random(atom,direction,:,:));
                    testCase.verifyEqual(slice,slice.',AbsTol=2e-12);
                end
            end
        end

        function forceOperationsMatchFrozenRelations(testCase)
            object=makeFcm(testCase);
            operations=object.get_FCM_operations();
            relations=zeros(numel(operations),5);
            for index=1:numel(operations)
                relation=operations{index};
                relations(index,:)=[relation.a-1,relation.b-1, ...
                    relation.c-1,relation.d-1, ...
                    numel(relation.operations)];
            end
            testCase.verifyEqual(relations, ...
                testCase.oracle.fcm_relations);
        end

        function forceGenerationSymmetryStabilityAndSumRules(testCase)
            object=makeFcm(testCase);object.get_FCM_operations();
            raw=object.get_unstable_FCM();
            symmetric=object.get_symmetrized_FCM(rand(30));
            verifyFcmRelations(testCase,symmetric, ...
                object.FCM_operations,1e-11);
            acoustic=object.get_asum_FCM(raw);
            blocks=matrixToBlocks(acoustic);
            for index=1:10
                testCase.verifyEqual( ...
                    squeeze(sum(blocks(index,:,:,:),2)), ...
                    zeros(3),AbsTol=2e-5);
                testCase.verifyEqual( ...
                    squeeze(sum(blocks(:,index,:,:),1)), ...
                    zeros(3),AbsTol=2e-5);
            end
            stable=object.get_stable_FCM(raw,10);
            values=eig(stable);[~,order]=sort(abs(values));
            testCase.verifyLessThanOrEqual( ...
                max(values(order(4:end))),1e-6+1e-10);
            forceConstants=object.get_rand_FCM(8,5);
            testCase.verifySize(forceConstants,[10,10,3,3]);
            testCase.verifyTrue(all(isfinite(forceConstants),"all"));
        end

        function piezoAndRandomWorkflowMatch(testCase)
            actual=kssolv.analysis.matgenlab.analysis.get_piezo( ...
                testCase.oracle.bec,testCase.oracle.ist, ...
                testCase.oracle.fcm);
            testCase.verifyEqual(actual,testCase.oracle.piezo, ...
                AbsTol=2e-11);
            [randomBec,randomIst,randomFcm,piezo]= ...
                kssolv.analysis.matgenlab.analysis.rand_piezo( ...
                testCase.structure,testCase.pointops, ...
                testCase.sharedops,testCase.oracle.bec, ...
                testCase.oracle.ist,testCase.oracle.fcm,5);
            testCase.verifySize(randomBec,[10,3,3]);
            testCase.verifySize(randomIst,[10,3,3,3]);
            testCase.verifySize(randomFcm,[10,10,3,3]);
            testCase.verifySize(piezo,[3,3,3]);
            testCase.verifyTrue(all(isfinite(piezo),"all"));
        end
    end
end

function object=makeFcm(testCase)
object=kssolv.analysis.matgenlab.analysis.ForceConstantMatrix( ...
    testCase.structure,testCase.oracle.fcm, ...
    testCase.pointops,testCase.sharedops);
end

function pointops=decodePointOperations(raw)
pointops=cell(1,numel(raw));
for atom=1:numel(raw)
    entries=raw{atom};entries=num2cell(entries);
    pointops{atom}=cellfun(@decodeOperation,entries, ...
        "UniformOutput",false);
end
end

function sharedops=decodeSharedOperations(raw)
count=numel(raw);sharedops=cell(count);
for first=1:count
    row=raw{first};
    for second=1:numel(row)
        entries=row{second};entries=num2cell(entries);
        sharedops{first,second}=cellfun(@decodeOperation,entries, ...
            "UniformOutput",false);
    end
end
end

function operation=decodeOperation(value)
operation=kssolv.analysis.matgenlab.core.SymmOp. ...
    from_rotation_and_translation(value.rotation,value.translation);
end

function verifyBecRelations(testCase,tensor,operations,tolerance)
for atom=1:numel(operations)
    relation=operations{atom};
    for index=1:numel(relation.operations)
        expected=relation.operations{index}.transform_tensor( ...
            squeeze(tensor(relation.source,:,:)));
        testCase.verifyEqual(squeeze(tensor(relation.target,:,:)), ...
            expected,AbsTol=tolerance);
    end
end
end

function verifyFcmRelations(testCase,matrix,operations,tolerance)
for index=1:numel(operations)
    relation=operations{index};
    target=matrix(3*relation.a-2:3*relation.a, ...
        3*relation.b-2:3*relation.b);
    source=matrix(3*relation.c-2:3*relation.c, ...
        3*relation.d-2:3*relation.d);
    for operation=1:numel(relation.operations)
        expected=relation.operations{operation}. ...
            transform_tensor(source);
        testCase.verifyEqual(target,expected,AbsTol=tolerance);
    end
end
end

function blocks=matrixToBlocks(matrix)
blocks=zeros(10,10,3,3);
for first=1:10
    for second=1:10
        blocks(first,second,:,:)=matrix( ...
            3*first-2:3*first,3*second-2:3*second);
    end
end
end
