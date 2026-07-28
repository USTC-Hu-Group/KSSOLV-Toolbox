classdef SerializationTest < matlab.unittest.TestCase
    methods (Test)
        function msonMetadataUsesReservedJSONKeys(testCase)
            value = kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.core.test", "Example", struct("value", 3));
            text = kssolv.analysis.matgenlab.util.encode(value);

            testCase.verifySubstring(text, '"@module":"pymatgen.core.test"');
            testCase.verifySubstring(text, '"@class":"Example"');
            testCase.verifyFalse(contains(text, '"x_module"'));
        end

        function unknownMSONTypeCanRemainDecoded(testCase)
            text = '{"@module":"pymatgen.unknown","@class":"Missing","value":3}';
            value = kssolv.analysis.matgenlab.util.decode( ...
                text, Strict = false);

            testCase.verifyEqual(string(value.x_module), "pymatgen.unknown");
            testCase.verifyEqual(string(value.x_class), "Missing");
            testCase.verifyEqual(value.value, 3);
        end

        function numericalToleranceHandlesSpecialValues(testCase)
            actual = [1, NaN, Inf, -Inf];
            expected = [1 + 1e-9, NaN, Inf, -Inf];
            testCase.verifyTrue( ...
                kssolv.analysis.matgenlab.internal.Tolerance.isClose( ...
                    actual, expected));
        end

        function registeredCoreObjectRoundTrip(testCase)
            original = kssolv.analysis.matgenlab.core.Lattice.hexagonal(3, 5);
            text = original.toJSON();
            restored = kssolv.analysis.matgenlab.util.decode(text);

            testCase.verifyClass(restored, ...
                "kssolv.analysis.matgenlab.core.Lattice");
            testCase.verifyTrue(restored == original);
        end
    end
end
