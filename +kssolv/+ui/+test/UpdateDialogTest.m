classdef UpdateDialogTest < matlab.unittest.TestCase
    %UPDATEDIALOGTEST 检查更新对话框的版本比较测试。

    methods (Test)
        function releaseResponseIsValidated(testCase)
            release = kssolv.ui.components.dialog.UpdateDialog.decodeLatestRelease( ...
                struct('tag_name', 'v0.4.2', 'html_url', ...
                'https://github.com/gleamoe/KSSOLV-Toolbox/releases/tag/v0.4.2'));
            testCase.verifyTrue(release.Exists);
            testCase.verifyEqual(release.TagName, "v0.4.2");
            testCase.verifyEmpty(char(release.Name));
            testCase.verifyError(@() ...
                kssolv.ui.components.dialog.UpdateDialog.decodeLatestRelease(struct('message','error')), ...
                'KSSOLV:UpdateDialog:InvalidResponse');
        end

        function newerPatchVersionIsDetected(testCase)
            actual = kssolv.ui.components.dialog.UpdateDialog ...
                .isNewerVersion("v0.2.8", "0.2.7");
            testCase.verifyTrue(actual);
        end

        function newerMinorVersionIsDetected(testCase)
            actual = kssolv.ui.components.dialog.UpdateDialog ...
                .isNewerVersion("0.3.0", "0.2.9");
            testCase.verifyTrue(actual);
        end

        function equalVersionIsNotAnUpdate(testCase)
            actual = kssolv.ui.components.dialog.UpdateDialog ...
                .isNewerVersion("v0.2.7", "0.2.7");
            testCase.verifyFalse(actual);
        end

        function olderVersionIsNotAnUpdate(testCase)
            actual = kssolv.ui.components.dialog.UpdateDialog ...
                .isNewerVersion("0.2.6", "0.2.7");
            testCase.verifyFalse(actual);
        end

        function missingVersionPartsAreZeroFilled(testCase)
            actual = kssolv.ui.components.dialog.UpdateDialog ...
                .isNewerVersion("1.0", "0.9.9");
            testCase.verifyTrue(actual);
        end

        function invalidVersionIsRejected(testCase)
            testCase.verifyError(@() ...
                kssolv.ui.components.dialog.UpdateDialog ...
                .isNewerVersion("latest", "0.2.7"), ...
                'KSSOLV:UpdateDialog:InvalidVersion');
        end
    end
end
