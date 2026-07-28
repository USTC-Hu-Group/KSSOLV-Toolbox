classdef AdfInputError < MException
    %ADFINPUTERROR Error raised for invalid ADF input settings.
    methods
        function obj = AdfInputError(message)
            obj@MException("KSSOLV:Matgenlab:ADF:Input", message);
        end
    end
end
