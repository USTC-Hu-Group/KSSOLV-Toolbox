classdef BasicAbinitInputError < MException
    methods
        function obj = BasicAbinitInputError(message)
            obj@MException("KSSOLV:Matgenlab:Abinit:Input", message);
        end
    end
end
