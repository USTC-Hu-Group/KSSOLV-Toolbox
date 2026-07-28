classdef GulpError < MException
    %GULPERROR Error raised for GULP configuration or execution failures.
    methods
        function obj = GulpError(message)
            obj@MException("KSSOLV:Matgenlab:GULP:Error", ...
                "GulpError : " + string(message));
        end
    end
end
