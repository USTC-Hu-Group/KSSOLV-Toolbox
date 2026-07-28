classdef AdfOutputError < MException
    %ADFOUTPUTERROR Error raised while parsing ADF output.
    methods
        function obj = AdfOutputError(message)
            obj@MException("KSSOLV:Matgenlab:ADF:Output", message);
        end
    end
end
