classdef SymmOpTest < matlab.unittest.TestCase
    % Differential values are from pymatgen-core v2026.7.24 test_operations.py.

    methods (Test)
        function axisAnglePropertiesAndOperation(testCase)
            op = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_axis_angle_and_translation([0,0,1], 30, ...
                translation_vec = [0,0,1]);
            expectedRotation = [0.866025403784439,-0.5,0; ...
                0.5,0.866025403784439,0;0,0,1];
            testCase.verifyEqual(op.rotation_matrix, expectedRotation, ...
                AbsTol = 1e-14);
            testCase.verifyEqual(op.translation_vector, [0,0,1]);
            testCase.verifyEqual(op.operate([1,2,3]), ...
                [-0.133974596215561,2.232050807568877,4], AbsTol = 1e-14);
            testCase.verifyEqual(op.operate_multi([1,2,3;1,2,3]), ...
                repmat([-0.133974596215561,2.232050807568877,4],2,1), ...
                AbsTol = 1e-14);
        end

        function inverseAndComposition(testCase)
            first = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_axis_angle_and_translation([1,2,3], 37, ...
                translation_vec = [1,-2,0.5]);
            second = kssolv.analysis.matgenlab.core.SymmOp.reflection( ...
                [1,1,0], [0.1,0.2,0.3]);
            point = [0.2,-0.8,1.1];
            testCase.verifyEqual(first.inverse.operate(first.operate(point)), ...
                point, AbsTol = 1e-12);
            composition = first * second;
            testCase.verifyEqual(composition.operate(point), ...
                first.operate(second.operate(point)), AbsTol = 1e-12);
        end

        function reflectionInversionAndRotoreflection(testCase)
            normal = [0.2,0.5,0.7];
            origin = [0.4,-0.2,0.1];
            point = [1.2,0.3,-0.5];
            reflection = ...
                kssolv.analysis.matgenlab.core.SymmOp.reflection(normal, origin);
            reflected = reflection.operate(point);
            testCase.verifyEqual(dot(reflected-origin,normal), ...
                -dot(point-origin,normal), AbsTol = 1e-12);
            inversion = ...
                kssolv.analysis.matgenlab.core.SymmOp.inversion(origin);
            testCase.verifyEqual(inversion.operate(point)-origin, ...
                -(point-origin), AbsTol = 1e-12);
            roto = kssolv.analysis.matgenlab.core.SymmOp. ...
                rotoreflection([0,0,1], 90, origin);
            testCase.verifyEqual(roto.operate(origin), origin, AbsTol = 1e-12);
        end

        function tensorTransformation(testCase)
            op = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_axis_angle_and_translation([0,0,1], 30, ...
                translation_vec = [0,0,1]);
            tensor = reshape(0:8, 3, 3).';
            expected = [-0.732050807568877,-1.732050807568877,-0.767949192431123; ...
                0.267949192431123,4.732050807568877,5.330127018922194; ...
                1.696152422706632,9.062177826491071,8];
            testCase.verifyEqual(op.transform_tensor(tensor), expected, ...
                AbsTol = 1e-12);
            vector = [1,2,3];
            testCase.verifyEqual(op.transform_tensor(vector), ...
                op.apply_rotation_only(vector), AbsTol = 1e-12);

            rankThree = permute(reshape(0:26, 3, 3, 3), [3,2,1]);
            expectedThree = zeros(3,3,3);
            rotation = op.rotation_matrix;
            for i = 1:3
                for j = 1:3
                    for k = 1:3
                        for a = 1:3
                            for b = 1:3
                                for c = 1:3
                                    expectedThree(i,j,k) = expectedThree(i,j,k) + ...
                                        rotation(i,a) * rotation(j,b) * ...
                                        rotation(k,c) * rankThree(a,b,c);
                                end
                            end
                        end
                    end
                end
            end
            testCase.verifyEqual(op.transform_tensor(rankThree), ...
                expectedThree, AbsTol = 1e-12);
            testCase.verifyError(@() op.transform_tensor(zeros(2,3)), ...
                "KSSOLV:Matgenlab:SymmOp:InvalidTensor");
        end

        function symmetricRelations(testCase)
            op = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_axis_angle_and_translation([0,0,1], 30, ...
                translation_vec = [0,0,1]);
            point = [0.23,0.41,0.67];
            transformed = op.operate(point);
            testCase.verifyTrue(op.are_symmetrically_related(point, transformed));
            fromA = [0.1,0.2,0.3];
            toA = [0.4,0.5,0.6];
            rA = [1,2,3];
            transformedVector = [op.operate(fromA); op.operate(toA)];
            floored = floor(transformedVector);
            closeToUpper = abs(transformedVector - floored) > 1 - 0.001;
            floored(closeToUpper) = floored(closeToUpper) + 1;
            rB = op.apply_rotation_only(rA) - floored(1,:) + floored(2,:);
            [related, reversed] = op.are_symmetrically_related_vectors( ...
                fromA, toA, rA, mod(transformedVector(1,:),1), ...
                mod(transformedVector(2,:),1), rB);
            testCase.verifyTrue(related);
            testCase.verifyFalse(reversed);
        end

        function xyzStringRoundTrip(testCase)
            matrix = [3,-2,-1,0.5; -1,0,0,12/13; ...
                0,0,1,0.5+1e-7; 0,0,0,1];
            op = kssolv.analysis.matgenlab.core.SymmOp(matrix);
            text = op.as_xyz_str();
            testCase.verifyEqual(text, "3x-2y-z+1/2, -x+12/13, z+1/2");
            parsed = kssolv.analysis.matgenlab.core.SymmOp.from_xyz_str(text);
            testCase.verifyTrue(parsed == op);
            reordered = kssolv.analysis.matgenlab.core.SymmOp.from_xyz_str( ...
                "1/2+3X-2y-z, 12/13-x, +1/2+z");
            testCase.verifyTrue(reordered == op);
        end

        function serializationRoundTrip(testCase)
            op = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(eye(3), [0.5,0.25,0.75], ...
                tol = 0.02);
            dictionary = op.as_dict();
            testCase.verifyEqual(dictionary.x_class, "SymmOp");
            reconstructed = ...
                kssolv.analysis.matgenlab.core.SymmOp.from_dict(dictionary);
            testCase.verifyEqual(reconstructed, op);
            testCase.verifyEqual(reconstructed.tol, 0.02);
        end

        function magneticOperation(testCase)
            op = kssolv.analysis.matgenlab.core.MagSymmOp.from_xyzt_str( ...
                "x, -y, z, -1");
            testCase.verifyEqual(op.operate_magmom([1,2,3]), [1,-2,3], ...
                AbsTol = 1e-14);
            testCase.verifyEqual(op.as_xyzt_str(), "x, -y, z, -1");
            inverse = op.inverse;
            testCase.verifyClass(inverse, ...
                "kssolv.analysis.matgenlab.core.MagSymmOp");
            testCase.verifyEqual(inverse.time_reversal, -1);
            reconstructed = ...
                kssolv.analysis.matgenlab.core.MagSymmOp.from_dict(op.as_dict());
            testCase.verifyEqual(reconstructed, op);
        end
    end
end
