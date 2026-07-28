classdef NormalizedAngleDistanceNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.NbSetWeight
    properties
        average_type (1,1) string
        aa (1,1) double
        bb (1,1) double
    end
    methods
        function obj=NormalizedAngleDistanceNbSetWeight(averageType,aa,bb)
            if ~ismember(string(averageType),["geometric","arithmetic"])
                error("KSSOLV:Matgenlab:ChemEnv:AverageType", ...
                    "Average type must be geometric or arithmetic.");
            end
            obj.average_type=string(averageType);obj.aa=aa;obj.bb=bb;
        end
        function value=invdist(~,nbSet),value=1./nbSet.normalized_distances;end
        function value=invndist(obj,nbSet)
            value=1./nbSet.normalized_distances.^obj.bb;
        end
        function value=ang(~,nbSet),value=nbSet.normalized_angles;end
        function value=angn(obj,nbSet),value=nbSet.normalized_angles.^obj.aa;end
        function value=anginvdist(~,nbSet)
            value=nbSet.normalized_angles./nbSet.normalized_distances;
        end
        function value=anginvndist(obj,nbSet)
            value=nbSet.normalized_angles./nbSet.normalized_distances.^obj.bb;
        end
        function value=angninvdist(obj,nbSet)
            value=nbSet.normalized_angles.^obj.aa./nbSet.normalized_distances;
        end
        function value=angninvndist(obj,nbSet)
            value=nbSet.normalized_angles.^obj.aa./ ...
                nbSet.normalized_distances.^obj.bb;
        end
        function value=weight(obj,nbSet,varargin)
            values=obj.angninvndist(nbSet);
            if obj.average_type=="geometric",value=obj.gweight(values);
            else,value=obj.aweight(values);end
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="NormalizedAngleDistanceNbSetWeight", ...
                average_type=obj.average_type,aa=obj.aa,bb=obj.bb);
        end
    end
    methods (Static)
        function value=gweight(values),value=exp(mean(log(values)));end
        function value=aweight(values),value=mean(values);end
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.NormalizedAngleDistanceNbSetWeight( ...
                value.average_type,value.aa,value.bb);
        end
    end
end
