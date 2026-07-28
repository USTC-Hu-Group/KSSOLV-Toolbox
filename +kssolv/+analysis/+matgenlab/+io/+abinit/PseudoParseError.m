classdef PseudoParseError < MException
    methods
        function obj = PseudoParseError(message)
            obj@MException("KSSOLV:Matgenlab:Abinit:PseudoParse", message);
        end
    end
end
