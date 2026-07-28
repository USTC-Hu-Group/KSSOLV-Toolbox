classdef LatticeFunctionsTest < matlab.unittest.TestCase
    methods (Test)
        function integerIndex(testCase)
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.get_integer_index( ...
                    [0.5, 1, -0.5]), [1, 2, -1]);
        end

        function neighborCubes(testCase)
            neighbors = kssolv.analysis.matgenlab.core.find_neighbors( ...
                [0, 0, 0], 3, 3, 3);
            testCase.verifyEqual(size(neighbors{1}, 1), 8);
            testCase.verifyTrue(ismember([1, 1, 1], neighbors{1}, "rows"));
        end

        function sphereSearchUsesPeriodicImages(testCase)
            lattice = kssolv.analysis.matgenlab.core.Lattice.cubic(3);
            neighbors = ...
                kssolv.analysis.matgenlab.core.get_points_in_spheres( ...
                    [2.9, 0, 0], [0.1, 0, 0], 0.3, true, ...
                    1e-8, lattice, false);
            testCase.verifyEqual(numel(neighbors{1}), 1);
            value = neighbors{1}{1};
            testCase.verifyEqual(value{2}, 0.2, "AbsTol", 1e-12);
            testCase.verifyEqual(value{3}, 1);
            testCase.verifyEqual(value{4}, [-1, 0, 0]);
        end
    end
end
