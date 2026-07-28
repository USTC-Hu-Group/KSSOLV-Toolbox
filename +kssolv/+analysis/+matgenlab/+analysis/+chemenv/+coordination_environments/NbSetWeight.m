%#ok<*NASGU>
classdef NbSetWeight < handle
    %NBSETWEIGHT Base neighbor-set weight estimator.
    methods
        function value=weight(~,~,~,varargin)
            value=[];
            error("KSSOLV:Matgenlab:NotImplemented","Abstract neighbor-set weight.");
        end
        function value=as_dict(obj)
            parts=split(string(class(obj)),".");
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class=parts(end));
        end
    end
end
