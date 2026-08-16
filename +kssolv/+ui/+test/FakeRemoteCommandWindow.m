classdef FakeRemoteCommandWindow < handle
    %FAKEREMOTECOMMANDWINDOW Minimal Command Window remote-mode test double.

    properties
        RemoteExecutionEnabled (1, 1) logical = false
    end

    methods
        function setRemoteExecutionEnabled(this, value)
            this.RemoteExecutionEnabled = logical(value);
        end
    end
end
