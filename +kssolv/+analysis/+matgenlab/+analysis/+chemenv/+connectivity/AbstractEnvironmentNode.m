classdef AbstractEnvironmentNode < handle
    %ABSTRACTENVIRONMENTNODE Site-index identity for connectivity graphs.
    properties (Constant)
        COORDINATION_ENVIRONMENT=0
        NUMBER_OF_NEIGHBORING_COORDINATION_ENVIRONMENTS=1
        NUMBER_OF_NEIGHBORING_CES=1
        NEIGHBORING_COORDINATION_ENVIRONMENTS=2
        NEIGHBORING_CES=2
        NUMBER_OF_LIGANDS_FOR_EACH_NEIGHBORING_COORDINATION_ENVIRONMENT=3
        NUMBER_OF_LIGANDS_FOR_EACH_NEIGHBORING_CE=3
        LIGANDS_ARRANGEMENT=4
        NEIGHBORS_LIGANDS_ARRANGEMENT=5
        ATOM=6
        CE_NNBCES_NBCES_LIGANDS=-1
        DEFAULT_EXTENSIONS=[6 0]
    end
    properties
        central_site
        i_central_site (1,1) double
    end
    properties (Access=protected)
        coordination_environment_value (1,1) string=""
    end
    properties (Dependent)
        isite
        coordination_environment
        ce
        mp_symbol
        ce_symbol
        atom_symbol
    end
    methods
        function obj=AbstractEnvironmentNode(centralSite,index)
            if nargin==0,return,end
            obj.central_site=centralSite;obj.i_central_site=double(index);
        end
        function value=get.isite(obj),value=obj.i_central_site;end
        function value=get.coordination_environment(obj)
            value=obj.coordination_environment_value;
        end
        function value=get.ce(obj),value=obj.coordination_environment;end
        function value=get.mp_symbol(obj),value=obj.coordination_environment;end
        function value=get.ce_symbol(obj),value=obj.coordination_environment;end
        function value=get.atom_symbol(obj)
            value=string(obj.central_site.species_string);
        end
        function value=everything_equal(obj,other)
            value=isa(other,class(obj))&&obj.isite==other.isite&& ...
                obj.central_site.is_periodic_image(other.central_site);
        end
        function value=char(obj)
            value=sprintf("Node #%d %s (%s)",obj.isite, ...
                obj.atom_symbol,obj.coordination_environment);
        end
        function value=string(obj),value=string(char(obj));end
    end
end
