%#ok<*STOUT>
classdef AbstractChemenvStrategy < handle
    %ABSTRACTCHEMENVSTRATEGY Shared structure/symmetry strategy services.
    properties (Constant)
        DEFAULT_SYMMETRY_MEASURE_TYPE="csm_wcs_ctwcc"
    end
    properties
        structure_environments=[]
        symops cell={}
    end
    properties (Dependent)
        symmetry_measure_type
        uniquely_determines_coordination_environments
    end
    properties (Access=protected)
        symmetry_measure_type_value (1,1) string="csm_wcs_ctwcc"
        unique_value (1,1) logical=true
    end
    methods
        function obj=AbstractChemenvStrategy(varargin)
            opts=parseOptions(struct(structure_environments=[], ...
                symmetry_measure_type=obj.DEFAULT_SYMMETRY_MEASURE_TYPE), ...
                varargin{:});
            obj.symmetry_measure_type_value=string(opts.symmetry_measure_type);
            if ~isempty(opts.structure_environments)
                obj.set_structure_environments(opts.structure_environments);
            end
        end
        function value=get.symmetry_measure_type(obj)
            value=obj.symmetry_measure_type_value;
        end
        function value=get.uniquely_determines_coordination_environments(obj)
            value=obj.unique_value;
        end
        function set_structure_environments(obj,value)
            obj.structure_environments=value;obj.prepare_symmetries();
        end
        function prepare_symmetries(obj)
            obj.symops={kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(eye(3),[0 0 0])};
        end
        function [isite,dequiv,dthis,sym]= ...
                equivalent_site_index_and_transform(obj,site)
            structure=obj.structure_environments.structure;isite=[];
            for ii=1:structure.num_sites
                if site.is_periodic_image(structure.sites{ii})
                    isite=ii;break
                end
            end
            if isempty(isite),error("KSSOLV:Matgenlab:ChemEnv:EquivalentSite", ...
                    "Equivalent site could not be found.");end
            mapped=obj.structure_environments.sites_map(isite);
            dequiv=[0 0 0];dthis=site.frac_coords- ...
                structure.sites{isite}.frac_coords;
            sym=obj.symops{1};
            if mapped~=isite
                % Symmetry operation lookup is intentionally delegated to
                % the repository's symmetry layer when nontrivial.
                for candidate=obj.symops
                    operated=candidate{1}.operate( ...
                        structure.sites{mapped}.frac_coords);
                    if norm(mod(operated-structure.sites{isite}.frac_coords+.5,1)-.5)<1e-6
                        sym=candidate{1};break
                    end
                end
            end
        end
        function value=get_site_ce_fractions_and_neighbors(obj,site,varargin)
            opts=parseOptions(struct(full_ce_info=false,strategy_info=false), ...
                varargin{:}); %#ok<NASGU>
            [isite,dequiv,dthis,sym]= ...
                obj.equivalent_site_index_and_transform(site);
            values=obj.get_site_coordination_environments_fractions(site, ...
                "isite",isite,"dequivsite",dequiv,"dthissite",dthis, ...
                "mysym",sym,"return_maps",true, ...
                "return_strategy_dict_info",true);
            if isempty(values),value=[];return,end
            value=values;
            for ii=1:numel(value)
                map=value{ii}.ce_map;sets= ...
                    obj.structure_environments.neighbors_sets{isite}(map(1));
                value{ii}.neighbors=sets{map(2)}.neighb_sites_and_indices;
            end
        end
        function set_option(obj,name,value),obj.(char(string(name)))=value;end
        function setup_options(obj,values)
            if isa(values,"containers.Map"),names=values.keys;
            else,names=fieldnames(values).';end
            for ii=1:numel(names)
                if isa(values,"containers.Map"),value=values(names{ii});
                else,value=values.(names{ii});end
                obj.set_option(names{ii},value);
            end
        end
        function value=get_site_neighbors(~,~)
            error("KSSOLV:Matgenlab:NotImplemented","Abstract strategy.");
        end
        function value=get_site_coordination_environment(~,~)
            error("KSSOLV:Matgenlab:NotImplemented","Abstract strategy.");
        end
        function value=get_site_coordination_environments(~,~)
            error("KSSOLV:Matgenlab:NotImplemented","Abstract strategy.");
        end
        function value=get_site_coordination_environments_fractions(~,~)
            error("KSSOLV:Matgenlab:NotImplemented","Abstract strategy.");
        end
        function value=as_dict(obj)
            parts=split(string(class(obj)),".");
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.chemenv_strategies", ...
                x_class=parts(end), ...
                symmetry_measure_type=obj.symmetry_measure_type);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            className=string(value.x_class);
            constructor=str2func("kssolv.analysis.matgenlab.analysis."+ ...
                "chemenv.coordination_environments."+className);
            obj=constructor(value);
        end
    end
end
function opts=parseOptions(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    opts.(names{pos})=varargin{pos};pos=pos+1;
end
for ii=pos:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
