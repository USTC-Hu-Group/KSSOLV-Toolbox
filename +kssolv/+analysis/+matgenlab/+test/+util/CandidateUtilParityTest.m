classdef CandidateUtilParityTest < matlab.unittest.TestCase
    % Frozen pymatgen-core v2026.7.24 edge coverage for candidate utilities.

    methods (Test)
        function periodicMembershipAndSimplexRoundTrip(testCase)
            util = "kssolv.analysis.matgenlab.util.";
            testCase.verifyTrue(feval(util + "in_coord_list_pbc", ...
                [0, 0, 0; 0.5, 0.5, 0.5], [0.99, 0.99, 0.99], 0.02));
            testCase.verifyFalse(feval(util + "in_coord_list_pbc", ...
                [0, 0, 0], [0.99, 0.99, 0.99], 0.005));
            simplex = kssolv.analysis.matgenlab.util.Simplex( ...
                [0, 0; 2, 0; 0, 2]);
            barycentric = [0.2, 0.3, 0.5];
            point = simplex.point_from_bary_coords(barycentric);
            testCase.verifyEqual(point, [0.6, 1.0], AbsTol=1e-14);
            testCase.verifyEqual(simplex.bary_coords(point), ...
                barycentric, AbsTol=1e-14);
        end

        function textAndNonTtyBehavior(testCase)
            fixture = kssolv.analysis.matgenlab.test.util. ...
                StringifyFixture("Fe8O12");
            testCase.verifyEqual(fixture.to_pretty_string(), "Fe8O12");
            testCase.verifyFalse( ...
                kssolv.analysis.matgenlab.util.stream_has_colors(1));
            withHeader = kssolv.analysis.matgenlab.util.str_delimited( ...
                {1, 2; 3, 4}, ["a", "b"], ",");
            testCase.verifyEqual(withHeader, ...
                "a,b" + newline + "1,2" + newline + "3,4");
        end
    end
end
