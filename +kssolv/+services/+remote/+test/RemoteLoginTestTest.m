classdef RemoteLoginTestTest < matlab.unittest.TestCase
    methods (Test)
        function connectionTestIgnoresComputeCommandTemplate(testCase)
            configuration = loginConfiguration();
            configuration.PostLoginCommandTemplate = ...
                "ssh gpu6 -- {command}";

            prepared = kssolv.services.remote.diagnostics.RemoteLoginTest. ...
                prepareConfiguration(configuration);

            testCase.verifyEqual(prepared.PostLoginCommandTemplate, ...
                "{command}");
        end

        function runsPostLoginScriptWithoutStartingMatlab(testCase)
            output = join([ ...
                "KSSOLV_LOGIN_HOST=master", ...
                "KSSOLV_LOGIN_TEST_OK"], newline);
            delegate = kssolv.services.remote.test. ...
                FakeEnvironmentProbeAccess(output);
            configuration = kssolv.services.remote.diagnostics. ...
                RemoteLoginTest.prepareConfiguration(loginConfiguration());
            configuration.PostLoginScript = "source /etc/profile";
            access = kssolv.services.remote.transport.RemoteCommandAccess( ...
                delegate, configuration);
            factory = kssolv.services.remote.test. ...
                FakeRemoteAccessFactory(access);

            report = kssolv.services.remote.diagnostics.RemoteLoginTest. ...
                runWithFactory(configuration, factory);

            testCase.verifyTrue(report.Succeeded);
            testCase.verifyEqual(report.Hostname, "master");
            testCase.verifyTrue(contains(delegate.Command, ...
                "source /etc/profile"));
            testCase.verifyTrue(contains(delegate.Command, ...
                "KSSOLV_LOGIN_TEST_OK"));
            testCase.verifyFalse(contains(delegate.Command, ...
                ["command -v matlab", "matlab -batch"]));
        end
    end
end

function value = loginConfiguration()
value = kssolv.services.remote.config.RemoteConfiguration.defaults();
value.ExecutionMode = "Mirror";
value.ConnectionMode = "SSH";
value.Host = "master.example.test";
value.Username = "user";
value.ClusterMatlabRoot = "";
value.RemoteJobStorageLocation = "";
end
