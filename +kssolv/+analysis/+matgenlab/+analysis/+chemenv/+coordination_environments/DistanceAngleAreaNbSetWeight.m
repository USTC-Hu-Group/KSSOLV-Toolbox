classdef DistanceAngleAreaNbSetWeight < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.NbSetWeight
    properties
        weight_type (1,1) string="has_intersection"
        surface_definition struct
        nb_sets_from_hints (1,1) string="fallback_to_source"
        other_nb_sets (1,1) string="0_weight"
        additional_condition (1,1) double=1
        smoothstep_distance=[]
        smoothstep_angle=[]
        dmin
        dmax
        amin
        amax
        f_lower
        f_upper
    end
    methods
        function obj=DistanceAngleAreaNbSetWeight(varargin)
            opts=parseOptions(varargin{:});
            if string(opts.weight_type)~="has_intersection"
                error("KSSOLV:Matgenlab:ChemEnv:AreaWeight", ...
                    "Only has_intersection is supported.");
            end
            names=fieldnames(opts);
            for ii=1:numel(names),obj.(names{ii})=opts.(names{ii});end
            obj.dmin=opts.surface_definition.distance_bounds.lower;
            obj.dmax=opts.surface_definition.distance_bounds.upper;
            obj.amin=opts.surface_definition.angle_bounds.lower;
            obj.amax=opts.surface_definition.angle_bounds.upper;
            funcs=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                get_lower_and_upper_f(opts.surface_definition);
            obj.f_lower=funcs.lower;obj.f_upper=funcs.upper;
        end
        function value=weight(obj,nbSet,se,varargin)
            opts=parseNamed(struct(cn_map=[],additional_info=[]),varargin{:});
            value=obj.w_area_has_intersection(nbSet,se,opts.cn_map, ...
                opts.additional_info);
        end
        function value=w_area_has_intersection(obj,nbSet,se,cnMap,info)
            value=obj.w_area_intersection_nbsfh_fbs_onb0( ...
                nbSet,se,cnMap,info);
        end
        function value=w_area_intersection_nbsfh_fbs_onb0( ...
                obj,nbSet,se,cnMap,info) %#ok<INUSD>
            value=0;
            for source=nbSet.sources
                src=source{1};
                if string(src.origin)=="dist_ang_ac_voronoi"&& ...
                        src.ac==obj.additional_condition&& ...
                        obj.rectangle_crosses_area(src.dp_dict.min, ...
                        src.dp_dict.next,src.ap_dict.next,src.ap_dict.max)
                    value=1;return
                end
            end
        end
        function value=rectangle_crosses_area(obj,d1,d2,a1,a2)
            if d2<=obj.dmin||d1>=obj.dmax,value=false;return,end
            left=max(d1,obj.dmin);right=min(d2,obj.dmax);
            low=max([obj.f_lower(left),obj.f_lower(right)]);
            high=min([obj.f_upper(left),obj.f_upper(right)]);
            value=~(a2<=low||a1>=high);
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class="DistanceAngleAreaNbSetWeight", ...
                weight_type=obj.weight_type, ...
                surface_definition=obj.surface_definition, ...
                nb_sets_from_hints=obj.nb_sets_from_hints, ...
                other_nb_sets=obj.other_nb_sets, ...
                additional_condition=obj.additional_condition);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.DistanceAngleAreaNbSetWeight( ...
                value.weight_type,value.surface_definition, ...
                value.nb_sets_from_hints,value.other_nb_sets, ...
                value.additional_condition);
        end
    end
end
function opts=parseOptions(varargin)
surface=struct(type="standard_elliptic", ...
    distance_bounds=struct(lower=1.2,upper=1.8), ...
    angle_bounds=struct(lower=.1,upper=.8));
opts=struct(weight_type="has_intersection",surface_definition=surface, ...
    nb_sets_from_hints="fallback_to_source",other_nb_sets="0_weight", ...
    additional_condition=1,smoothstep_distance=[],smoothstep_angle=[]);
opts=parseNamed(opts,varargin{:});
end
function opts=parseNamed(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    if ~isempty(varargin{pos}),opts.(names{pos})=varargin{pos};end;pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
