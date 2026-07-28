classdef TransformedPDEntryError < MException
    methods
        function obj=TransformedPDEntryError(message)
            obj@MException("KSSOLV:Matgenlab:TransformedPDEntryError",message);
        end
    end
end
