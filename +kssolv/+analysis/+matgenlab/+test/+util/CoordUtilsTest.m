classdef CoordUtilsTest < matlab.unittest.TestCase
    methods (Test)
        function coordinateListOperations(testCase)
            u = "kssolv.analysis.matgenlab.util.";
            coords = [0 0 0; 0.5 0.5 0.5; 0.1 0.1 0.1];
            indices = feval(u + "find_in_coord_list", ...
                coords, [0.1 0.1 0.1], 0.15);
            testCase.verifyEqual(indices, [1; 3]);
            testCase.verifyTrue(feval(u + "in_coord_list", ...
                coords, [0.1 0.1 0.1]));
            testCase.verifyTrue(feval(u + "is_coord_subset", ...
                [0 0 0; 3 2 1], [3-9e-9 2-9e-9 1-9e-9; 0 0 0]));
            mapping = feval(u + "coord_list_mapping", ...
                [0 0.124 0; 0 1.2 -1], ...
                [3 2 1; 0 1.2 -1; 0 0.124 0]);
            testCase.verifyEqual(mapping, [3; 2]);
        end

        function pbcCoordinateOperations(testCase)
            u = "kssolv.analysis.matgenlab.util.";
            c1 = [0.1 0.2 0.3];
            c2 = [0.2 0.3 0.3];
            c3 = [0.5 0.3 0.6];
            c4 = [1.5 -0.7 -1.4];
            mapping = feval(u + "coord_list_mapping_pbc", ...
                [c1; c3; c2], [c4; c2; c1]);
            testCase.verifyEqual(mapping, [3; 1; 2]);
            testCase.verifyEqual(feval(u + "pbc_diff", ...
                [0.1 0.1 0.1], [0.3 0.5 0.9]), ...
                [-0.2 -0.4 0.2], AbsTol=1e-14);
            testCase.verifyEqual(feval(u + "find_in_coord_list_pbc", ...
                [0 0 0; .5 .5 .5], [.99 .99 .99], .02), 1);
            testCase.verifyFalse(feval(u + "is_coord_subset_pbc", ...
                [0 0 0], [.1 .1 .2], [.15 .15 .25], true));
        end

        function interpolationAndDistances(testCase)
            u = "kssolv.analysis.matgenlab.util.";
            value = feval(u + "get_linear_interpolated_value", ...
                0:5, [3 6 7 8 10 12], 3.6);
            testCase.verifyEqual(value, 9.2, AbsTol=1e-14);
            minimum = feval(u + "get_linear_interpolated_value", ...
                0:5, [3 6 7 8 10 12], 0);
            testCase.verifyEqual(minimum, 3);
            distances = feval(u + "all_distances", ...
                [0 0 0; .5 .5 .5], [1 2 -1; 1 0 0; 1 0 0]);
            testCase.verifyEqual(distances, ...
                [2.44948974 1 1; 2.17944947 .8660254 .8660254], ...
                AbsTol=1e-7);
        end

        function supercellAndBarycentricCoordinates(testCase)
            u = "kssolv.analysis.matgenlab.util.";
            matrix = [1 3 5; -3 2 3; -5 3 1];
            points = feval(u + "lattice_points_in_supercell", matrix);
            testCase.verifySize(points, [round(abs(det(matrix))), 3]);
            testCase.verifyGreaterThanOrEqual(min(points, [], "all"), -1e-10);
            testCase.verifyLessThanOrEqual(max(points, [], "all"), 1 - 1e-10);

            simplex = [0 0 1; 0 1 0; 1 0 0; 0 0 0];
            coords = [0 0 1; 0 .5 .5; 1/3 1/3 1/3];
            bary = feval(u + "barycentric_coords", coords, simplex);
            testCase.verifyEqual(bary * simplex, coords, AbsTol=1e-13);
            testCase.verifyEqual(bary(2, :), [.5 .5 0 0], AbsTol=1e-13);
        end

        function shortestVectors(testCase)
            fracCoords = [.3 .3 .5; .1 .1 .3; .9 .9 .8; ...
                .1 0 .5; .9 .7 0];
            lattice = kssolv.analysis.matgenlab.core.Lattice.from_parameters( ...
                8, 8, 4, 90, 76, 58);
            vectors = kssolv.analysis.matgenlab.util.pbc_shortest_vectors( ...
                lattice, fracCoords(1:4, :), fracCoords);
            distances = sqrt(sum(vectors.^2, 3));
            expected = [0 3.015 4.072 3.519 3.245; ...
                3.015 0 3.207 1.131 4.453; ...
                4.072 3.207 0 2.251 1.788; ...
                3.519 1.131 2.251 0 3.852];
            testCase.verifyEqual(distances, expected, RelTol=1e-3);
        end

        function simplexBehavior(testCase)
            simplex = kssolv.analysis.matgenlab.util.Simplex( ...
                [0 0 0; 0 1 0; 0 0 1; 1 0 0]);
            testCase.verifyEqual(simplex.volume, 1/6, AbsTol=1e-14);
            testCase.verifyTrue(simplex.in_simplex([.1 .1 .1]));
            testCase.verifyFalse(simplex.in_simplex([.6 .6 .6]));
            triangle = kssolv.analysis.matgenlab.util.Simplex( ...
                [0 2; 3 1; 1 0]);
            bary = triangle.bary_coords([.7 .5]);
            testCase.verifyEqual(bary, [.26 -.02 .76], AbsTol=1e-13);
            intersections = triangle.line_intersection([.7 .5], [.5 .7]);
            testCase.verifyEqual(intersections, ...
                [1.133333333333333 .066666666666667; .8 .4], ...
                AbsTol=1e-12);
        end

        function angleUnits(testCase)
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.util.get_angle([1 0 0], [1 1 1]), ...
                54.7356103172453, AbsTol=1e-12);
            testCase.verifyError(@() ...
                kssolv.analysis.matgenlab.util.get_angle([1 0 0], ...
                [1 1 1], "gradians"), ...
                "KSSOLV:Matgenlab:Coord:InvalidAngleUnits");
        end
    end
end
