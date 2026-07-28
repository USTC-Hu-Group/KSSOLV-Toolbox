classdef IOUtilsTest < matlab.unittest.TestCase
    methods (Test)
        function cleansCommentsAndWhitespace(testCase)
            lines = ["  first # comment", " ", "  second  "];
            result = kssolv.analysis.matgenlab.util.clean_lines(lines);
            testCase.verifyEqual(result, ["first", "second"]);
        end

        function comparesArrayValuedMappings(testCase)
            first = struct("a", [1, 2], "b", NaN);
            second = struct("b", NaN, "a", [1, 2]);
            testCase.verifyTrue( ...
                kssolv.analysis.matgenlab.util.is_np_dict_equal(first, second));
        end
    end
end
