classdef PWInputError < MException
    %PWINPUTERROR Invalid Quantum ESPRESSO PW input specification.
    methods
        function obj = PWInputError(message)
            obj@MException("KSSOLV:Matgenlab:PWSCF:Input", message);
        end
    end
end
