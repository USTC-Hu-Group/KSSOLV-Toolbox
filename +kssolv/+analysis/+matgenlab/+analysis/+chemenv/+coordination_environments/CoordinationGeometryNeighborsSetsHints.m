classdef CoordinationGeometryNeighborsSetsHints
    %COORDINATIONGEOMETRYNEIGHBORSSETSHINTS Lower-CN cap hints.
    properties
        hints_type (1,1) string
        options struct
    end
    methods
        function obj=CoordinationGeometryNeighborsSetsHints(hintsType,options)
            allowed=["single_cap","double_cap","triple_cap"];
            if ~ismember(string(hintsType),allowed)
                error("KSSOLV:Matgenlab:ChemEnv:HintType", ...
                    "Hint type '%s' is not allowed.",string(hintsType));
            end
            obj.hints_type=string(hintsType);obj.options=options;
        end
        function value=hints(obj,info)
            if info.csm>obj.options.csm_max,value={};return,end
            value=obj.(char(obj.hints_type+"_hints"))(info);
        end
        function value=single_cap_hints(obj,info)
            value={removeCaps(obj,info,obj.options.cap_index)};
        end
        function value=double_cap_hints(obj,info)
            a=obj.options.first_cap_index;b=obj.options.second_cap_index;
            value={removeCaps(obj,info,a),removeCaps(obj,info,b), ...
                removeCaps(obj,info,[a b])};
        end
        function value=triple_cap_hints(obj,info)
            a=obj.options.first_cap_index;b=obj.options.second_cap_index;
            c=obj.options.third_cap_index;
            value={removeCaps(obj,info,a),removeCaps(obj,info,b), ...
                removeCaps(obj,info,c),removeCaps(obj,info,[b c]), ...
                removeCaps(obj,info,[a c]),removeCaps(obj,info,[a b]), ...
                removeCaps(obj,info,[a b c])};
        end
        function value=as_dict(obj)
            value=struct(hints_type=obj.hints_type,options=obj.options);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments. ...
                CoordinationGeometryNeighborsSetsHints( ...
                value.hints_type,value.options);
        end
    end
    methods (Access=private)
        function value=removeCaps(~,info,indices)
            aligned=info.nb_set.get_neighb_voronoi_indices( ...
                "permutation",info.permutation);
            % Hint options originate on the zero-based MSON wire.
            caps=aligned(reshape(double(indices),1,[])+1);
            value=reshape(double(info.nb_set.site_voronoi_indices),1,[]);
            value=value(~ismember(value,caps));
        end
    end
end
