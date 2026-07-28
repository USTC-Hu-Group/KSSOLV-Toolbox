classdef MPRestError < MException
    %MPRESTERROR Materials Project request or response failure.

    methods
        function obj = MPRestError(message)
            if nargin < 1, message = "Malformed Materials Project query."; end
            obj@MException("KSSOLV:Matgenlab:MPRestError", "%s", ...
                string(message));
        end
    end
end
