classdef RemoteProjectBrowserStub < handle
    %REMOTEPROJECTBROWSERSTUB Records Results refresh requests in tests.

    properties
        RefreshCount (1, 1) double = 0
        LastItem = []
    end

    methods
        function refreshUIAfterItemCreation(this, item)
            this.RefreshCount = this.RefreshCount + 1;
            this.LastItem = item;
        end
    end
end
