classdef TotpTest < matlab.unittest.TestCase
    methods (Test)
        function matchesRfc6238Sha1Vectors(testCase)
            secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";
            unixTimes = [59, 1111111109, 1111111111, ...
                1234567890, 2000000000, 20000000000];
            expected = ["94287082", "07081804", "14050471", ...
                "89005924", "69279037", "65353130"];
            actual = strings(size(expected));
            for index = 1:numel(unixTimes)
                instant = datetime(unixTimes(index), ...
                    "ConvertFrom", "posixtime", "TimeZone", "UTC");
                actual(index) = kssolv.services.remote.security.Totp.generate( ...
                    secret, Time=instant, Digits=8);
            end
            testCase.verifyEqual(actual, expected);
        end

        function generatesSixDigitCode(testCase)
            instant = datetime(59, "ConvertFrom", "posixtime", ...
                "TimeZone", "UTC");
            code = kssolv.services.remote.security.Totp.generate( ...
                "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", Time=instant);
            testCase.verifyEqual(code, "287082");
        end

        function rejectsInvalidBase32(testCase)
            testCase.verifyError(@() ...
                kssolv.services.remote.security.Totp.generate("NOT*BASE32"), ...
                "KSSOLV:Remote:TotpSecretInvalid");
        end
    end
end
