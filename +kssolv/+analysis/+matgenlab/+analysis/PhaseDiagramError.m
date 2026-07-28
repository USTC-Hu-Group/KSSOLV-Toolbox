classdef PhaseDiagramError < MException
    methods
        function obj=PhaseDiagramError(message)
            obj@MException("KSSOLV:Matgenlab:PhaseDiagramError",message);
        end
    end
end
