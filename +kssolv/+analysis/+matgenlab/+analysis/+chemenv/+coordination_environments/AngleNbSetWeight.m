classdef AngleNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.NbSetWeight
    properties
        aa (1,1) double=1
    end
    methods
        function obj=AngleNbSetWeight(aa),if nargin>0,obj.aa=double(aa);end,end
        function value=weight(obj,nbSet,varargin)
            value=obj.angle_sumn(nbSet);
        end
        function value=angle_sumn(obj,nbSet)
            value=obj.angle_sum(nbSet).^obj.aa;
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="AngleNbSetWeight",aa=obj.aa);
        end
    end
    methods (Static)
        function value=angle_sum(nbSet),value=sum(nbSet.angles)/(4*pi);end
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AngleNbSetWeight(value.aa);
        end
    end
end
