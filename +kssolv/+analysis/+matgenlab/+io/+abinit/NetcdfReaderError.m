classdef NetcdfReaderError < MException
    methods
        function obj=NetcdfReaderError(message)
            obj@MException("KSSOLV:Matgenlab:Abinit:NetcdfReader",message);
        end
    end
end
