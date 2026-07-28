classdef UnitError < MException
    %UNITERROR Exception raised for invalid or incompatible physical units.

    methods
        function obj = UnitError(message, varargin)
            obj@MException("KSSOLV:Matgenlab:UnitError", ...
                sprintf(message, varargin{:}));
        end
    end
end
