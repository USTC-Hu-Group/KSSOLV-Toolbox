classdef BrowserSessionTest < matlab.unittest.TestCase
    methods (Test)
        function refreshesOnlyForAValidClaimedRequest(testCase)
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            filename = string(fullfile(folder, 'session.json'));
            publish = @() "http://localhost:1234/fresh?snc=second";
            kssolv.ui.browser.BrowserSession.publish(filename, "http://localhost:1234/old");
            original = fileread(filename);
            testCase.verifyFalse(kssolv.ui.browser.BrowserSession.respond(filename, publish));
            testCase.verifyEqual(fileread(filename), original);
            writelines('invalid', filename + ".request");
            testCase.verifyFalse(kssolv.ui.browser.BrowserSession.respond(filename, publish));
            testCase.verifyEqual(fileread(filename), original);
            identity = repmat('a', 1, 32);
            writelines(identity, filename + ".request");
            testCase.verifyTrue(kssolv.ui.browser.BrowserSession.respond(filename, publish));
            result = jsondecode(fileread(filename));
            testCase.verifyEqual(result.request_id, identity);
            testCase.verifyEqual(string(result.url), publish());
            testCase.verifyFalse(isfile(filename + ".request"));
            testCase.verifyNumElements(dir(folder), 3);
        end
    end
end
