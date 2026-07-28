classdef NwInputError < MException
    %NWINPUTERROR Invalid NWChem input settings.
    methods
        function obj=NwInputError(message)
            obj@MException("KSSOLV:Matgenlab:NWChem:Input",message);
        end
    end
end
