%#ok<*ALIGN,*ISCL>
classdef ConnectivityFinder < handle
    %CONNECTIVITYFINDER Build connectivity from light structure environments.
    properties
        multiple_environments_choice=[]
    end
    methods
        function obj=ConnectivityFinder(varargin)
            opts=parseNamed(struct(multiple_environments_choice=[]),varargin{:});
            obj.setup_parameters(opts.multiple_environments_choice);
        end
        function setup_parameters(obj,value)
            if ~isempty(value)&&string(value)~="TAKE_HIGHEST_FRACTION"
                error("KSSOLV:Matgenlab:ChemEnv:ConnectivityChoice", ...
                    "Unsupported multiple-environments choice.");
            end
            obj.multiple_environments_choice=value;
        end
        function value=get_structure_connectivity(obj,lse)
            value=kssolv.analysis.matgenlab.analysis.chemenv. ...
                connectivity.StructureConnectivity(lse);
            value.add_sites();
            for isite=1:lse.structure.num_sites
                sets=lse.neighbors_sets{isite};
                if isempty(sets),continue,end
                if numel(sets)>1
                    if isempty(obj.multiple_environments_choice)
                        error("KSSOLV:Matgenlab:ChemEnv:MixedEnvironment", ...
                            "Site %d has mixed environments.",isite);
                    end
                    ces=lse.coordination_environments{isite};
                    [~,index]=max(cellfun(@(x)x.ce_fraction,ces));
                else,index=1;end
                value.add_bonds(isite,sets{index});
            end
        end
    end
end
function opts=parseNamed(opts,varargin)
if numel(varargin)==1&&~(ischar(varargin{1})||isstring(varargin{1}))
    opts.multiple_environments_choice=varargin{1};return
end
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
