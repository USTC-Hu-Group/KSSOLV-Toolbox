classdef GulpConvergenceError < MException
    %GULPCONVERGENCEERROR Error raised when GULP does not converge.
    methods
        function obj = GulpConvergenceError(message)
            if nargin < 1, message = ""; end
            obj@MException("KSSOLV:Matgenlab:GULP:Convergence", ...
                string(message));
        end
    end
end
