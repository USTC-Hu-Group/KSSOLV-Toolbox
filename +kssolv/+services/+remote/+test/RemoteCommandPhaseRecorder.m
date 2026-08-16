classdef RemoteCommandPhaseRecorder < handle
    properties
        Phases string = strings(0, 1)
        Details string = strings(0, 1)
    end

    methods
        function report(this, phase, detail)
            this.Phases(end + 1, 1) = string(phase);
            this.Details(end + 1, 1) = string(detail);
        end
    end
end
