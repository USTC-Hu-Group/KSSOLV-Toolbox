classdef FakeRemoteJobManager < handle
    properties
        SubmittedConfigurationId (1, 1) string = ""
        SubmittedSnapshot struct = struct()
        ShouldFail (1, 1) logical = false
    end

    methods
        function record = submitWorkflow(this, configurationId, snapshot, varargin) %#ok<INUSD>
            this.SubmittedConfigurationId = string(configurationId);
            this.SubmittedSnapshot = snapshot;
            if this.ShouldFail
                error("KSSOLV:Test:RemoteSubmissionFailure", ...
                    "simulated footer submission failure");
            end
            record = struct("LocalJobId", "footer-test-job");
        end
    end
end
