classdef LatticeTest < matlab.unittest.TestCase
    % Differential values are from pymatgen-core v2026.7.24 test_lattice.py.

    methods (Test)
        function constructorsAndProperties(testCase)
            cubic = kssolv.analysis.matgenlab.core.Lattice.cubic(10);
            testCase.verifyEqual(cubic.matrix, 10 * eye(3), AbsTol = 1e-14);
            testCase.verifyEqual(cubic.lengths, [10, 10, 10], AbsTol = 1e-14);
            testCase.verifyEqual(cubic.angles, [90, 90, 90], AbsTol = 1e-12);
            testCase.verifyEqual(cubic.volume, 1000, AbsTol = 1e-12);
            testCase.verifyTrue(cubic.is_orthogonal);
            testCase.verifyTrue(cubic.is_3d_periodic);

            monoclinic = ...
                kssolv.analysis.matgenlab.core.Lattice.monoclinic(10, 20, 30, 66);
            testCase.verifyEqual(monoclinic.lengths, [10, 20, 30], ...
                AbsTol = 1e-12);
            testCase.verifyEqual(monoclinic.angles, [90, 66, 90], ...
                AbsTol = 1e-12);

            partial = kssolv.analysis.matgenlab.core.Lattice.cubic( ...
                10, pbc = [true, true, false]);
            testCase.verifyFalse(partial.is_3d_periodic);
            testCase.verifyNotEqual(partial, cubic);
        end

        function validatesInputs(testCase)
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.core.Lattice(eye(2)), ...
                "KSSOLV:Matgenlab:Lattice:InvalidMatrix");
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.core.Lattice(zeros(3)), ...
                "KSSOLV:Matgenlab:Lattice:SingularMatrix");
            testCase.verifyError( ...
                @() kssolv.analysis.matgenlab.core.Lattice(eye(3), [1, 1, 1]), ...
                "KSSOLV:Matgenlab:Lattice:InvalidPbc");
        end

        function flatMatrixUsesPythonRowOrder(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice(1:9);
            testCase.verifyEqual(lattice.matrix, [1,2,3;4,5,6;7,8,9]);
        end

        function parameterRoundTrip(testCase)
            expectedLengths = [3.840198, 3.84019885, 3.8401976];
            expectedAngles = [119.99998575, 90, 60.00000728];
            matrix = [3.840198, 0, 0; 1.920099, 3.325710, 0; ...
                0, -2.217138, 3.135509];
            lattice = kssolv.analysis.matgenlab.core.Lattice(matrix);
            testCase.verifyEqual(lattice.lengths, expectedLengths, AbsTol = 1e-6);
            testCase.verifyEqual(lattice.angles, expectedAngles, AbsTol = 1e-6);
            reconstructed = ...
                kssolv.analysis.matgenlab.core.Lattice.from_parameters( ...
                lattice.a, lattice.b, lattice.c, lattice.alpha, ...
                lattice.beta, lattice.gamma);
            testCase.verifyEqual(reconstructed.lengths, expectedLengths, ...
                AbsTol = 1e-6);
            testCase.verifyEqual(reconstructed.angles, expectedAngles, ...
                AbsTol = 1e-6);
        end

        function coordinateTransformsAndReciprocal(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.tetragonal(10, 20);
            fractional = [0.15, 0.3, 0.4; 1.2, -0.1, 0.25];
            cartesian = lattice.get_cartesian_coords(fractional);
            testCase.verifyEqual(cartesian, [1.5,3,8;12,-1,5], ...
                AbsTol = 1e-12);
            testCase.verifyEqual(lattice.get_fractional_coords(cartesian), ...
                fractional, AbsTol = 1e-12);
            testCase.verifyEqual(lattice.reciprocal_lattice.matrix, ...
                diag([0.628318530717959, 0.628318530717959, ...
                0.314159265358979]), AbsTol = 1e-12);
            testCase.verifyEqual( ...
                lattice.reciprocal_lattice_crystallographic.matrix, ...
                diag([0.1, 0.1, 0.05]), AbsTol = 1e-14);
            testCase.verifyEqual(lattice.d_hkl([1, 2, 3]), ...
                1 / sqrt(0.01 + 0.04 + 0.0225), AbsTol = 1e-12);
        end

        function scalePreservesShape(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(4, 5, 6, 70, 80, 100);
            scaled = lattice.scale(10);
            testCase.verifyEqual(scaled.volume, 10, AbsTol = 1e-10);
            testCase.verifyEqual(scaled.angles, lattice.angles, AbsTol = 1e-10);
            testCase.verifyEqual(scaled.lengths / scaled.c, ...
                lattice.lengths / lattice.c, AbsTol = 1e-12);
        end

        function minimumImageAndAllDistances(testCase)
            cubic = kssolv.analysis.matgenlab.core.Lattice.cubic(10);
            [distance, image] = cubic.get_distance_and_image( ...
                [0, 0, 0.1], [0, 0, 0.9]);
            testCase.verifyEqual(distance, 2, AbsTol = 1e-12);
            testCase.verifyEqual(image, [0, 0, -1]);

            coords = [0.3,0.3,0.5; 0.1,0.1,0.3; 0.9,0.9,0.8; ...
                0.1,0,0.5; 0.9,0.7,0];
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(8, 8, 4, 90, 76, 58);
            expected = [0,3.015,4.072,3.519,3.245; ...
                3.015,0,3.207,1.131,4.453; ...
                4.072,3.207,0,2.251,1.788; ...
                3.519,1.131,2.251,0,3.852; ...
                3.245,4.453,1.788,3.852,0];
            testCase.verifyEqual(lattice.get_all_distances(coords, coords), ...
                expected, AbsTol = 1e-3);
        end

        function partialPbcDistance(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                eye(3), [true, true, false]);
            [distance, image] = lattice.get_distance_and_image( ...
                [0,0,0], [0.9,0.9,0.9]);
            testCase.verifyEqual(distance, sqrt(0.83), AbsTol = 1e-12);
            testCase.verifyEqual(image, [-1,-1,0]);
        end

        function pointsInSphere(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(1);
            points = [0,0,0; 0.2,0,0];
            [fractional, distances, indices, images] = ...
                lattice.get_points_in_sphere(points, [0,0,0], 0.20001);
            testCase.verifyEqual(numel(distances), 2);
            testCase.verifyEqual(distances, [0; 0.2], AbsTol = 1e-12);
            testCase.verifyEqual(indices, [1; 2]);
            testCase.verifyEqual(fractional, [0,0,0;0.2,0,0], ...
                AbsTol = 1e-12);
            testCase.verifyEqual(images, zeros(2,3));
            zipped = lattice.get_points_in_sphere( ...
                points, [0,0,0], 0.20001);
            testCase.verifySize(zipped, [2,4]);
            testCase.verifyEqual(zipped{2,1}, [0.2,0,0], AbsTol = 1e-12);
            unzipped = lattice.get_points_in_sphere( ...
                points, [0,0,0], 0.20001, zip_results = false);
            testCase.verifyEqual(unzipped{2}, [0;0.2], AbsTol = 1e-12);
        end

        function lllReductionAndCoordinates(testCase)
            a = [1, 0.1, 0];
            b = [0, 2, 0];
            c = [0, 0, 3];
            first = kssolv.analysis.matgenlab.core.Lattice([a;b;c]);
            second = kssolv.analysis.matgenlab.core.Lattice([a+b;b+c;c]);
            testCase.verifyEqual(second.lll_matrix, first.matrix, AbsTol = 1e-12);
            testCase.verifyEqual(second.lll_mapping * second.matrix, ...
                first.matrix, AbsTol = 1e-12);
            frac = second.get_fractional_coords([1,1,2;2,2,1.5]);
            lllFrac = second.get_lll_frac_coords(frac);
            testCase.verifyEqual(second.get_frac_coords_from_lll(lllFrac), ...
                frac, AbsTol = 1e-12);
        end

        function latticeMapping(testCase)
            matrix = [0.1,0.2,0.3; -0.1,0.2,0.7; 0.6,0.9,0.2];
            lattice = kssolv.analysis.matgenlab.core.Lattice(matrix);
            operation = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_origin_axis_angle([0,0,0], [2,3,3], 35);
            scale = [1,1,0;0,1,0;0,0,1];
            transformed = (operation.rotation_matrix * ...
                (scale * matrix).').';
            other = kssolv.analysis.matgenlab.core.Lattice(transformed);
            [aligned, rotation, scaleOut] = other.find_mapping(lattice);
            testCase.verifyNotEmpty(aligned);
            testCase.verifyEqual(aligned.parameters, lattice.parameters, ...
                AbsTol = 1e-8);
            testCase.verifyEqual(scaleOut * other.matrix, aligned.matrix, ...
                AbsTol = 1e-12);
            rotated = ...
                kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(rotation).operate_multi(lattice.matrix);
            testCase.verifyEqual(rotated, aligned.matrix, AbsTol = 1e-12);

            orthorhombic = ...
                kssolv.analysis.matgenlab.core.Lattice.orthorhombic(9,9,5);
            mappings = orthorhombic.find_all_mappings(orthorhombic);
            testCase.verifyEqual(size(mappings, 1), 16);
        end

        function niggliReduction(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(3, 5.196, 2, ...
                103+55/60, 109+28/60, 134+53/60);
            reduced = lattice.get_niggli_reduced_lattice();
            testCase.verifyEqual(reduced.lengths, [2,3,3], AbsTol = 1e-3);
            testCase.verifyEqual(reduced.angles, ...
                [116.382855225,94.769790288,109.466666667], AbsTol = 1e-3);

            cubicBasis = [1,1,1;1,1,0;0,1,1] * (5 * eye(3));
            reducedCubic = ...
                kssolv.analysis.matgenlab.core.Lattice(cubicBasis). ...
                get_niggli_reduced_lattice();
            testCase.verifyEqual(reducedCubic.lengths, [5,5,5], AbsTol = 1e-8);
            testCase.verifyEqual(reducedCubic.angles, [90,90,90], AbsTol = 1e-8);
        end

        function wignerSeitzAndBrillouinCells(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice(diag([10,5,1]));
            facets = lattice.get_wigner_seitz_cell();
            testCase.verifyEqual(numel(facets), 6);
            for idx = 1:numel(facets)
                testCase.verifyEqual(abs(facets{idx}), ...
                    repmat([5,2.5,0.5], size(facets{idx},1), 1), ...
                    AbsTol = 1e-10);
            end
            testCase.verifyEqual( ...
                numel(lattice.get_brillouin_zone()), 6);
        end

        function wignerSeitzMergesCoplanarTriangles(testCase)
            matrix = [ ...
                -0.1315582766583831, 0.32889479254503001, ...
                0.18477464588139864; ...
                0.059096720783089994, 0.023495436356213435, ...
                -0.0070269996842483601; ...
                -0.67403725598345854, 0.726688312106062, ...
                -3.4036609657731893];
            facets = kssolv.analysis.matgenlab.core.Lattice(matrix). ...
                get_wigner_seitz_cell();

            testCase.verifyNumElements(facets, 10);
            vertexCount = size(uniquetol(vertcat(facets{:}), 1e-10, ...
                "ByRows", true), 1);
            edgeCount = sum(cellfun(@(face) size(face, 1), facets)) / 2;
            testCase.verifyEqual(vertexCount - edgeCount + numel(facets), 2);
        end

        function sellingReductionAndDistance(testCase)
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(10). ...
                selling_vector, [0,0,0,-100,-100,-100], AbsTol = 1e-12);
            first = kssolv.analysis.matgenlab.core.Lattice.hexagonal(5,8);
            second = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(4,10,11,100,110,80);
            testCase.verifyEqual(first.selling_dist(second), ...
                75.9276485284, AbsTol = 1e-10);
            first = kssolv.analysis.matgenlab.core.Lattice.cubic(5);
            second = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(8,10,12,80,90,95);
            testCase.verifyEqual(first.selling_dist(second), ...
                125.992223131, AbsTol = 1e-9);
        end

        function crystalSystemAndMillerIndex(testCase)
            testCase.verifyTrue( ...
                kssolv.analysis.matgenlab.core.Lattice.hexagonal(10,20). ...
                is_hexagonal());
            testCase.verifyFalse( ...
                kssolv.analysis.matgenlab.core.Lattice.cubic(10). ...
                is_hexagonal());
            cubic = kssolv.analysis.matgenlab.core.Lattice.cubic(1);
            sites = [0.5,-1.5,3; 0.5,3,-1.5; 2.5,1.5,-4];
            testCase.verifyEqual( ...
                cubic.get_miller_index_from_coords(sites), [2,1,1]);
        end

        function serializationRoundTrip(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.tetragonal(10, 20);
            dictionary = lattice.as_dict(1);
            testCase.verifyEqual(dictionary.x_module, "pymatgen.core.lattice");
            testCase.verifyEqual(dictionary.x_class, "Lattice");
            testCase.verifyEqual(dictionary.volume, 2000, AbsTol = 1e-12);
            reconstructed = ...
                kssolv.analysis.matgenlab.core.Lattice.from_dict(dictionary);
            testCase.verifyEqual(reconstructed, lattice);
            json = lattice.toJSON();
            testCase.verifySubstring(json, '"@module":"pymatgen.core.lattice"');
        end
    end
end
