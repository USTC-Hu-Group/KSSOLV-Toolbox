classdef TensorTest < matlab.unittest.TestCase
    % Port of non-fixture pymatgen-core v2026.7.24 tensor tests.

    methods (Test)
        function constructionShapeAndIndexing(testCase)
            rank1 = kssolv.analysis.matgenlab.core.Tensor([1,0,0]);
            rank3 = kssolv.analysis.matgenlab.core.Tensor(zeros(3,3,3));
            testCase.verifyEqual(rank1.rank,1);
            testCase.verifyEqual(rank3.rank,3);
            testCase.verifyEqual(rank1(1),1);
            rank1(2) = 2;
            testCase.verifyEqual(double(rank1),[1,2,0]);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.core.Tensor(zeros(4)), ...
                "KSSOLV:Matgenlab:Tensor:InvalidDimension");
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.core.SquareTensor(zeros(3,3,3)), ...
                "KSSOLV:Matgenlab:Tensor:RankMismatch");
        end

        function zeroingArithmeticAndRound(testCase)
            low = kssolv.analysis.matgenlab.core.Tensor( ...
                [1e-6,1+1e-5,1e-6;1+1e-6,1e-6,1e-6; ...
                1e-7,1e-7,1+1e-5]);
            expected = [0,1+1e-5,0;1+1e-6,0,0;0,0,1+1e-5];
            testCase.verifyEqual(double(low.zeroed()),expected);
            original = kssolv.analysis.matgenlab.core.SquareTensor( ...
                [.1,.2,.3;.4,.5,.6;.2,.5,.5]);
            shifted = original+0.01;
            rounded = shifted.round(1);
            testCase.verifyClass(rounded, ...
                "kssolv.analysis.matgenlab.core.SquareTensor");
            testCase.verifyEqual(double(rounded),double(original), ...
                AbsTol=1e-15);
            testCase.verifyEqual(double(3*original),3*double(original));
        end

        function transformationsAndRotation(testCase)
            values = permute(reshape(0:26,[3,3,3]),[3,2,1]);
            tensor = kssolv.analysis.matgenlab.core.Tensor(values);
            operation = ...
                kssolv.analysis.matgenlab.core.SymmOp. ...
                from_axis_angle_and_translation([0,0,1],30, ...
                translation_vec=[0,0,1]);
            transformed = double(tensor.transform(operation));
            expected = cat(3, ...
                [-0.871,-2.152,-1.026;0.044,4.263,5.170;1.679,9.268,8.285], ...
                [-2.884,-6.665,-2.830;1.531,21.008,23.026;7.268,38.321,33.651], ...
                [-1.928,-4.196,-1.572;1.804,17.928,18.722;5.821,29.919,26]);
            % expected above is arranged by MATLAB pages.
            testCase.verifyEqual(transformed,expected,AbsTol=5e-4);
            vector = kssolv.analysis.matgenlab.core.Tensor([1,0,0]);
            rotated = vector.rotate([0,-1,0;1,0,0;0,0,1]);
            testCase.verifyEqual(double(rotated),[0,1,0],AbsTol=1e-15);
            testCase.verifyError(@() vector.rotate(ones(3)), ...
                "KSSOLV:Matgenlab:Tensor:InvalidRotation");
        end

        function contractionsProjectionAndSphereAverage(testCase)
            values = permute(reshape(0:80,[3,3,3,3]),[4,3,2,1]);
            tensor = kssolv.analysis.matgenlab.core.Tensor(values);
            testCase.verifyEqual(tensor.einsum_sequence( ...
                {[1,0,0],[1,0,0],[1,0,0]}),[0,27,54]);
            testCase.verifyEqual(tensor.einsum_sequence( ...
                {eye(3),eye(3)}),360);
            rank2 = kssolv.analysis.matgenlab.core.Tensor(reshape(1:9,3,3));
            testCase.verifyEqual(rank2.project([1,0,0]),rank2(1,1));
            testCase.verifyEqual(rank2.project([1,1,1]), ...
                sum(double(rank2),"all")/3,AbsTol=1e-13);
            onesTensor = kssolv.analysis.matgenlab.core.Tensor(ones(3));
            testCase.verifyEqual(onesTensor.average_over_unit_sphere(), ...
                1,AbsTol=1e-13);
        end

        function symmetryAndSummaryMethods(testCase)
            random = kssolv.analysis.matgenlab.core.Tensor( ...
                reshape(sin(1:27),3,3,3));
            testCase.verifyTrue(random.symmetrized.is_symmetric());
            symmetric = kssolv.analysis.matgenlab.core.Tensor( ...
                [1,2,3;2,4,5;3,5,6]);
            testCase.verifyTrue(symmetric.is_symmetric());
            nonsymmetric = kssolv.analysis.matgenlab.core.Tensor( ...
                [1,2,3;4,5,6;7,8,9]);
            testCase.verifyFalse(nonsymmetric.is_symmetric());
            onesTensor = kssolv.analysis.matgenlab.core.Tensor(ones(3));
            fullGroups = onesTensor.get_grouped_indices();
            voigtGroups = onesTensor.get_grouped_indices(true);
            testCase.verifyEqual(size(fullGroups{1},1),9);
            testCase.verifyEqual(size(voigtGroups{1},1),6);
            testCase.verifyEqual(onesTensor.get_symbol_dict(), ...
                struct("T_1",1));
            testCase.verifyEqual(onesTensor.get_symbol_dict(false), ...
                struct("T_11",1));
        end

        function voigtRoundTrips(testCase)
            matrix = [ ...
                59.33,28.08,28.08,0,0,0
                28.08,59.31,28.07,0,0,0
                28.08,28.07,59.32,0,0,0
                0,0,0,26.35,0,0
                0,0,0,0,26.35,0
                0,0,0,0,0,26.35];
            rank4 = ...
                kssolv.analysis.matgenlab.core.Tensor.from_voigt(matrix);
            testCase.verifyEqual(rank4.rank,4);
            testCase.verifyEqual(rank4.voigt,matrix,AbsTol=1e-14);
            rank3Input = reshape(1:18,3,6);
            rank3 = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                from_voigt(rank3Input);
            testCase.verifyEqual(rank3.rank,3);
            testCase.verifyEqual(rank3.voigt,rank3Input);
            rank2Input = 0:5;
            rank2 = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                from_voigt(rank2Input);
            testCase.verifyEqual(rank2.voigt,rank2Input);
            map = ...
                kssolv.analysis.matgenlab.core.Tensor.get_voigt_dict(2);
            testCase.verifyEqual(size(map.standard_indices),[9,2]);
            testCase.verifyEqual(size(map.voigt_indices),[9,1]);
        end

        function voigtSymmetrizationAndSerialization(testCase)
            input = reshape(sin(1:36),6,6);
            tensor = ...
                kssolv.analysis.matgenlab.core.Tensor.from_voigt(input);
            symmetrized = tensor.voigt_symmetrized;
            testCase.verifyEqual(symmetrized.voigt, ...
                (input+input.')/2,AbsTol=1e-14);
            fullDictionary = symmetrized.as_dict();
            fullRoundTrip = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                from_dict(fullDictionary);
            testCase.verifyEqual(double(fullRoundTrip), ...
                double(symmetrized),AbsTol=1e-14);
            voigtDictionary = symmetrized.as_dict(true);
            voigtRoundTrip = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                from_dict(voigtDictionary);
            testCase.verifyEqual(double(voigtRoundTrip), ...
                double(symmetrized),AbsTol=1e-14);
        end

        function squareTensorProperties(testCase)
            tensor = kssolv.analysis.matgenlab.core.SquareTensor( ...
                [.1,.2,.3;.4,.5,.6;.2,.5,.5]);
            testCase.verifyEqual(double(tensor.trans),double(tensor).');
            testCase.verifyEqual(double(tensor.inv),inv(double(tensor)), ...
                AbsTol=1e-13);
            testCase.verifyEqual(tensor.det,0.009,AbsTol=1e-15);
            testCase.verifyEqual(tensor.principal_invariants, ...
                [1.1,-0.09,0.009],AbsTol=1e-15);
            testCase.verifyEqual(double(tensor.symmetrized), ...
                [.1,.3,.25;.3,.5,.55;.25,.55,.5],AbsTol=1e-15);
            singular = kssolv.analysis.matgenlab.core.SquareTensor( ...
                [.1,0,0;.2,0,0;0,0,0]);
            testCase.verifyError(@() singular.inv, ...
                "KSSOLV:Matgenlab:SquareTensor:NonInvertible");
        end

        function squareTensorRotationPolarAndScale(testCase)
            angle = 3.14*42.5/180;
            rotation = kssolv.analysis.matgenlab.core.SquareTensor( ...
                [cos(angle),0,sin(angle);0,1,0;-sin(angle),0,cos(angle)]);
            testCase.verifyTrue(rotation.is_rotation());
            perturbed = rotation;
            perturbed(3,3) = perturbed(3,3)+0.02;
            testCase.verifyFalse(perturbed.is_rotation());
            testCase.verifyEqual(double(perturbed.refine_rotation()), ...
                double(rotation),AbsTol=1e-14);
            tensor = kssolv.analysis.matgenlab.core.SquareTensor( ...
                [.1,.2,.3;.4,.5,.6;.2,.5,.5]);
            testCase.verifyEqual(double(tensor.get_scaled(10)), ...
                [1,2,3;4,5,6;2,5,5]);
            [unitary,positive] = tensor.polar_decomposition();
            testCase.verifyEqual(unitary*positive,double(tensor), ...
                AbsTol=1e-13);
            testCase.verifyEqual(unitary*unitary',eye(3),AbsTol=1e-13);
        end

        function collectionAndMapping(testCase)
            collection = ...
                kssolv.analysis.matgenlab.core.TensorCollection( ...
                {1e-4*eye(3),ones(3),ones(3,3,3)});
            testCase.verifyEqual(collection.ranks,[2,2,3]);
            testCase.verifyTrue(collection.is_symmetric());
            zeroed = collection.zeroed();
            testCase.verifyEqual(double(zeroed(1)),zeros(3));
            roundTrip = ...
                kssolv.analysis.matgenlab.core.TensorCollection. ...
                from_dict(collection.as_dict());
            testCase.verifyEqual(double(roundTrip(2)),ones(3));

            key = ...
                kssolv.analysis.matgenlab.core.Tensor.from_voigt( ...
                [0.01,0,0,0,0,0]);
            mapping = ...
                kssolv.analysis.matgenlab.core.TensorMapping({key},{42});
            testCase.verifyEqual(mapping(key),42);
            equivalent = key + 1e-7;
            testCase.verifyTrue(mapping.contains(equivalent));
            mapping(equivalent) = "updated";
            testCase.verifyEqual(mapping(key),"updated");
            [keys,values] = mapping.items();
            testCase.verifyEqual(numel(keys),1);
            testCase.verifyEqual(values,{"updated"});
        end

        function valuesIndicesAndUnitVector(testCase)
            tensor = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                from_values_indices([2,3],[0,0;1,1]);
            testCase.verifyEqual(tensor(1,1),2);
            testCase.verifyEqual(tensor(2,2),3);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.get_uvec([3,0,0]), ...
                [1,0,0]);
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.get_uvec([0,0,0]), ...
                [0,0,0]);
        end

        function structureFitPopulateAndReduce(testCase)
            testCase.assumeTrue(spglibAvailable(), ...
                "The bundled spglib MEX is unavailable in this MATLAB runtime.");
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                3*eye(3),{"Si"},[0,0,0]);
            operations = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                symmetry_operations(structure,0.1);
            testCase.verifyEqual(numel(operations),48);
            input = kssolv.analysis.matgenlab.core.Tensor( ...
                [1,2,3;2,4,5;3,5,6]);
            fitted = input.fit_to_structure(structure);
            testCase.verifyEqual(double(fitted),(11/3)*eye(3), ...
                AbsTol=1e-13);
            testCase.verifyTrue(fitted.is_fit_to_structure(structure));
            testCase.verifyFalse(input.is_fit_to_structure(structure));
            partial = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                from_values_indices(2,[0,0]);
            populated = partial.populate(structure);
            testCase.verifyEqual(double(populated),2*eye(3),AbsTol=1e-13);

            bases = cell(1,6);
            for index = 1:6
                voigt = zeros(1,6);
                voigt(index) = 0.01;
                bases{index} = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    from_voigt(voigt);
            end
            reduced = ...
                kssolv.analysis.matgenlab.core.symmetry_reduce( ...
                bases,structure);
            testCase.verifyEqual(length(reduced),2);
            testCase.verifyEqual(cellfun(@numel,reduced.values()),[2,2]);
            ieee = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                get_ieee_rotation(structure);
            testCase.verifyEqual(double(ieee),eye(3),AbsTol=1e-14);
        end
    end
end

function available = spglibAvailable()
try
    kssolv.analysis.spglib.Spglib.getVersion();
    available = true;
catch
    available = false;
end
end
