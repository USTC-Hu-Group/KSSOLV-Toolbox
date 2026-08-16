classdef RemoteStatusRecorder < handle
    properties
        Messages string = strings(0, 1)
    end

    methods
        function report(this, text)
            this.Messages(end + 1, 1) = string(text);
        end
    end
end
