classdef SettingsTest < matlab.unittest.TestCase
    properties
        OriginalConfig string
        ConfigPath string
    end

    methods (TestMethodSetup)
        function createConfig(testCase)
            testCase.OriginalConfig = string(getenv("PMG_CONFIG_FILE"));
            testCase.ConfigPath = string(tempname) + ".yaml";
            fid = fopen(testCase.ConfigPath, "w");
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, "PMG_DEFAULT_FUNCTIONAL: PBE\n");
            fprintf(fid, "CUSTOM_NUMBER: 3.5\n");
            fprintf(fid, "CUSTOM_BOOL: true\n");
            fprintf(fid, "PMG_TEST_DIR: '~/matgenlab-test' # comment\n");
            clear cleanup
            setenv("PMG_CONFIG_FILE", testCase.ConfigPath);
            kssolv.analysis.matgenlab.core.Settings.refresh();
        end
    end

    methods (TestMethodTeardown)
        function restoreConfig(testCase)
            setenv("PMG_CONFIG_FILE", testCase.OriginalConfig);
            kssolv.analysis.matgenlab.core.Settings.refresh();
            if isfile(testCase.ConfigPath)
                delete(testCase.ConfigPath);
            end
        end
    end

    methods (Test)
        function loadsFlatYamlAndExpandsDirectories(testCase)
            testCase.verifyEqual( ...
                string(kssolv.analysis.matgenlab.core.Settings.get( ...
                    "PMG_DEFAULT_FUNCTIONAL")), "PBE");
            testCase.verifyEqual( ...
                kssolv.analysis.matgenlab.core.Settings.get("CUSTOM_NUMBER"), 3.5);
            testCase.verifyTrue( ...
                kssolv.analysis.matgenlab.core.Settings.get("CUSTOM_BOOL"));
            testCase.verifyTrue(contains(string( ...
                kssolv.analysis.matgenlab.core.Settings.get("PMG_TEST_DIR")), ...
                "matgenlab-test"));
        end
    end
end
