classdef EnumError < MException
    %ENUMERROR Error raised when enumlib produces no derivative structures.
    methods
        function obj = EnumError(message)
            if nargin == 0
                message = "Unable to enumerate structure.";
            end
            obj@MException("KSSOLV:Matgenlab:Enumlib:Enumeration", ...
                char(string(message)));
        end
    end
end
