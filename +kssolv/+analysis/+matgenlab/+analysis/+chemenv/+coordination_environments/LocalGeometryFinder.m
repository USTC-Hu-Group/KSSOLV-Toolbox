%#ok<*ALIGN,*PROP>
classdef LocalGeometryFinder < handle
    %LOCALGEOMETRYFINDER Continuous-symmetry local environment analyzer.
    properties (Constant)
        DEFAULT_BVA_DISTANCE_SCALE_FACTOR=1
        STRUCTURE_REFINEMENT_NONE="none"
        STRUCTURE_REFINEMENT_REFINED="refined"
        STRUCTURE_REFINEMENT_SYMMETRIZED="symmetrized"
    end
    properties
        allcg
        permutations_safe_override (1,1) logical=false
        plane_ordering_override (1,1) logical=true
        plane_safe_permutations (1,1) logical=false
        centering_type (1,1) string="centroid"
        include_central_site_in_centroid (1,1) logical=true
        bva_distance_scale_factor (1,1) double=1
        structure_refinement (1,1) string="none"
        spg_analyzer_options struct=struct(symprec=1e-3,angle_tolerance=5)
        initial_structure=[]
        structure=[]
        local_geometry=[]
        perfect_geometry=[]
        valences="undefined"
        detailed_voronoi=[]
        equivalent_sites cell={}
        sites_map=[]
        struct_sites_to_irreducible_site_list_map=[]
        icentral_site=[]
        indices=[]
    end
    methods
        function obj=LocalGeometryFinder(varargin)
            opts=parseNamed(struct(permutations_safe_override=false, ...
                plane_ordering_override=true,plane_safe_permutations=false, ...
                only_symbols=[]),varargin{:});
            obj.permutations_safe_override=opts.permutations_safe_override;
            obj.plane_ordering_override=opts.plane_ordering_override;
            obj.plane_safe_permutations=opts.plane_safe_permutations;
            obj.allcg=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AllCoordinationGeometries( ...
                "permutations_safe_override", ...
                opts.permutations_safe_override,"only_symbols", ...
                opts.only_symbols);
            obj.setup_parameters("centering_type","centroid", ...
                "include_central_site_in_centroid",true, ...
                "structure_refinement","none");
        end
        function setup_parameters(obj,varargin)
            opts=parseNamed(struct(centering_type="standard", ...
                include_central_site_in_centroid=false, ...
                bva_distance_scale_factor=[], ...
                structure_refinement="refined", ...
                spg_analyzer_options=[]),varargin{:});
            obj.centering_type=string(opts.centering_type);
            obj.include_central_site_in_centroid= ...
                logical(opts.include_central_site_in_centroid);
            if isempty(opts.bva_distance_scale_factor)
                obj.bva_distance_scale_factor= ...
                    obj.DEFAULT_BVA_DISTANCE_SCALE_FACTOR;
            else,obj.bva_distance_scale_factor=opts.bva_distance_scale_factor;end
            obj.structure_refinement=string(opts.structure_refinement);
            if isempty(opts.spg_analyzer_options)
                obj.spg_analyzer_options= ...
                    struct(symprec=1e-3,angle_tolerance=5);
            else,obj.spg_analyzer_options=opts.spg_analyzer_options;end
        end
        function setup_parameter(obj,parameter,value)
            name=char(string(parameter));
            if ~isprop(obj,name)
                error("KSSOLV:Matgenlab:ChemEnv:Parameter", ...
                    "Unknown LocalGeometryFinder parameter '%s'.",name);
            end
            obj.(name)=value;
        end
        function setup_structure(obj,structure)
            obj.initial_structure=structure.copy();
            % The MATLAB symmetry layer does not mutate the supplied
            % structure; refinement modes retain the same physical sites.
            obj.structure=structure.copy();
        end
        function value=get_structure(obj),value=obj.structure;end
        function set_structure(obj,lattice,species,coords,coordsAreCartesian)
            obj.setup_structure(kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,coords, ...
                "coords_are_cartesian",logical(coordsAreCartesian)));
        end
        function setup_local_geometry(obj,isite,coords,varargin)
            isite=normalizeSite(isite,obj.structure.num_sites);
            obj.local_geometry=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractGeometry( ...
                "central_site",obj.structure.sites{isite}.coords, ...
                "bare_coords",coords,"centering_type",obj.centering_type, ...
                "include_central_site_in_centroid", ...
                obj.include_central_site_in_centroid);
        end
        function setup_test_perfect_environment(obj,symbol,varargin)
            opts=parseNamed(struct(randomness=false,max_random_dist=.1, ...
                symbol_type="mp_symbol",indices="RANDOM", ...
                random_translation="NONE",random_rotation="NONE", ...
                random_scale="NONE",points=[]),varargin{:});
            if string(opts.symbol_type)=="IUPAC"
                cg=obj.allcg.get_geometry_from_IUPAC_symbol(symbol);
            elseif string(opts.symbol_type)=="CoordinationGeometry",cg=symbol;
            else,cg=obj.allcg.get_geometry_from_mp_symbol(symbol);end
            if isempty(opts.points),neighbors=double(cg.points);
            else,neighbors=double(opts.points);end
            center=[0 0 0];
            if opts.randomness
                center=center+randomBall(opts.max_random_dist);
                for ii=1:size(neighbors,1)
                    neighbors(ii,:)=neighbors(ii,:)+ ...
                        randomBall(opts.max_random_dist);
                end
            end
            if ischar(opts.indices)||isstring(opts.indices)
                if string(opts.indices)=="RANDOM"
                    neighbors=neighbors(randperm(size(neighbors,1)),:);
                elseif string(opts.indices)~="ORDERED"
                    error("KSSOLV:Matgenlab:ChemEnv:Indices", ...
                        "indices must be RANDOM, ORDERED, or a permutation.");
                end
            else,neighbors=neighbors(normalizePermutation( ...
                    opts.indices,size(neighbors,1)),:);end
            scale=opts.random_scale;
            if ischar(scale)||isstring(scale)
                if string(scale)=="RANDOM",scale=.95+.1*rand();
                else,scale=1;end
            end
            center=center*scale;neighbors=neighbors*scale;
            rotation=rotationValue(opts.random_rotation);
            center=(rotation*center.').';
            neighbors=(rotation*neighbors.').';
            translation=opts.random_translation;
            if ischar(translation)||isstring(translation)
                if string(translation)=="RANDOM",translation=20*rand(1,3)-10;
                else,translation=[0 0 0];end
            end
            coords=[center;neighbors]+reshape(double(translation),1,3);
            span=max(max(coords,[],1)-min(coords,[],1));
            lattice=kssolv.analysis.matgenlab.core.Lattice.cubic(max(1,5*span));
            species=[{"Cu"},repmat({"O"},1,size(neighbors,1))];
            obj.setup_structure(kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,coords,"coords_are_cartesian",true));
            obj.setup_local_geometry(1,coords(2:end,:));
            obj.perfect_geometry=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractGeometry.from_cg(cg);
        end
        function setup_random_structure(obj,coordination)
            coords=.4*rand(coordination+1,3)-.2;
            obj.set_structure(eye(3)*10,repmat({"Si"},1,coordination+1), ...
                coords,false);
            obj.setup_random_indices_local_geometry(coordination);
            obj.setup_local_geometry(1,obj.structure.cart_coords( ...
                obj.indices,:));
        end
        function setup_random_indices_local_geometry(obj,coordination)
            obj.icentral_site=1;obj.indices=1+randperm(coordination);
        end
        function setup_ordered_indices_local_geometry(obj,coordination)
            obj.icentral_site=1;obj.indices=2:coordination+1;
        end
        function setup_explicit_indices_local_geometry(obj,explicitIndices)
            obj.icentral_site=1;obj.indices=normalizeWireIndices( ...
                explicitIndices)+1;
        end
        function value=get_coordination_symmetry_measures( ...
                obj,varargin)
            opts=parseNamed(struct(only_minimum=true,all_csms=true, ...
                optimization=[]),varargin{:});
            value=obj.computeAll(opts.only_minimum,opts.all_csms, ...
                opts.optimization);
        end
        function value=get_coordination_symmetry_measures_optim( ...
                obj,varargin)
            opts=parseNamed(struct(only_minimum=true,all_csms=true, ...
                nb_set=[],optimization=[]),varargin{:});
            value=obj.computeAll(opts.only_minimum,opts.all_csms, ...
                opts.optimization);
        end
        function [results,permutations,algos,l2p,p2l]= ...
                coordination_geometry_symmetry_measures( ...
                obj,cg,varargin)
            opts=parseNamed(struct(tested_permutations=false, ...
                points_perfect=[],optimization=[]),varargin{:});
            [results,permutations,algos,l2p,p2l]= ...
                obj.evaluateGeometry(cg,opts.points_perfect);
        end
        function [results,permutations,algos,l2p,p2l]= ...
                coordination_geometry_symmetry_measures_sepplane_optim( ...
                obj,cg,varargin)
            opts=parseNamed(struct(points_perfect=[],nb_set=[], ...
                optimization=[]),varargin{:});
            [results,permutations,algos,l2p,p2l]= ...
                obj.evaluateGeometry(cg,opts.points_perfect);
        end
        function [results,permutations,algos,l2p,p2l]= ...
                coordination_geometry_symmetry_measures_standard( ...
                obj,cg,algo,varargin)
            opts=parseNamed(struct(points_perfect=[],optimization=[]), ...
                varargin{:});
            [results,permutations,algos,l2p,p2l]= ...
                obj.evaluatePermutations(cg,algo.permutations, ...
                opts.points_perfect,char(algo));
        end
        function varargout= ...
                coordination_geometry_symmetry_measures_separation_plane( ...
                obj,cg,algo,varargin)
            opts=parseNamed(struct(testing=false,tested_permutations=false, ...
                points_perfect=[]),varargin{:});
            permutations=permutationsForAlgorithm(algo,cg.coordination_number);
            [varargout{1:nargout}]=obj.evaluatePermutations( ...
                cg,permutations,opts.points_perfect,char(algo));
        end
        function varargout= ...
                coordination_geometry_symmetry_measures_separation_plane_optim( ...
                obj,cg,algo,varargin)
            [varargout{1:nargout}]=obj. ...
                coordination_geometry_symmetry_measures_separation_plane( ...
                cg,algo,varargin{:});
        end
        function varargout= ...
                coordination_geometry_symmetry_measures_fallback_random( ...
                obj,cg,varargin)
            opts=parseNamed(struct(points_perfect=[],n_random=10),varargin{:});
            permutations=cell(1,opts.n_random);
            for ii=1:opts.n_random
                permutations{ii}=randperm(cg.coordination_number);
            end
            [varargout{1:nargout}]=obj.evaluatePermutations(cg, ...
                permutations,opts.points_perfect,"RANDOM");
        end
        function value=compute_structure_environments(obj,varargin)
            opts=parseNamed(struct(excluded_atoms=[],only_atoms=[], ...
                only_cations=true,only_indices=[],maximum_distance_factor=2, ...
                minimum_angle_factor=.05,max_cn=[],min_cn=[], ...
                only_symbols=[],valences="undefined", ...
                additional_conditions=[0 1],info=struct(),timelimit=[], ...
                initial_structure_environments=[],get_from_hints=false, ...
                voronoi_normalized_distance_tolerance=.05, ...
                voronoi_normalized_angle_tolerance=.03, ...
                voronoi_distance_cutoff=10,recompute=[],optimization=2), ...
                varargin{:});
            if ~isempty(opts.only_symbols)
                obj.allcg=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments.AllCoordinationGeometries( ...
                    "only_symbols",opts.only_symbols);
            end
            n=obj.structure.num_sites;
            if isempty(opts.only_indices),sites=1:n;
            else,sites=normalizeSites(opts.only_indices,n);end
            obj.valences=opts.valences;
            obj.equivalent_sites=cellfun(@(x){x},obj.structure.sites, ...
                "UniformOutput",false);
            obj.sites_map=1:n;
            obj.struct_sites_to_irreducible_site_list_map=1:n;
            obj.detailed_voronoi=kssolv.analysis.matgenlab.analysis. ...
                chemenv.coordination_environments.DetailedVoronoiContainer( ...
                "structure",obj.structure,"isites",sites, ...
                "valences",obj.valences, ...
                "maximum_distance_factor",opts.maximum_distance_factor, ...
                "minimum_angle_factor",opts.minimum_angle_factor, ...
                "additional_conditions",opts.additional_conditions, ...
                "normalized_distance_tolerance", ...
                opts.voronoi_normalized_distance_tolerance, ...
                "normalized_angle_tolerance", ...
                opts.voronoi_normalized_angle_tolerance, ...
                "voronoi_cutoff",opts.voronoi_distance_cutoff);
            if isempty(opts.initial_structure_environments)
                value=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments.StructureEnvironments( ...
                    obj.detailed_voronoi,obj.valences,1:n, ...
                    obj.equivalent_sites,cell(1,n),obj.structure, ...
                    "info",opts.info);
            else,value=opts.initial_structure_environments;end
            minCn=1;if ~isempty(opts.min_cn),minCn=opts.min_cn;end
            maxCn=20;if ~isempty(opts.max_cn),maxCn=opts.max_cn;end
            for isite=sites
                value.init_neighbors_sets(isite,"additional_conditions", ...
                    opts.additional_conditions,"valences",obj.valences);
                maps=value.neighbors_sets{isite};
                if isempty(maps),continue,end
                for cn=maps.keys
                    if cn{1}<minCn||cn{1}>maxCn,continue,end
                    sets=maps(cn{1});
                    for ii=1:numel(sets)
                        obj.update_nb_set_environments(value,isite, ...
                            cn{1},ii,sets{ii});
                    end
                end
            end
        end
        function value=compute_coordination_environments( ...
                obj,structure,varargin)
            opts=parseNamed(struct(indices=[],only_cations=true, ...
                strategy=[],valences="undefined", ...
                initial_structure_environments=[]),varargin{:});
            obj.setup_structure(structure);
            se=obj.compute_structure_environments( ...
                "only_indices",opts.indices,"only_cations", ...
                opts.only_cations,"valences",opts.valences, ...
                "initial_structure_environments", ...
                opts.initial_structure_environments);
            if isempty(opts.strategy)
                strategy=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments.MultiWeightsChemenvStrategy. ...
                    stats_article_weights_parameters();
            else,strategy=opts.strategy;end
            lse=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.LightStructureEnvironments. ...
                from_structure_environments(strategy,se);
            value=lse.coordination_environments;
        end
        function value=update_nb_set_environments( ...
                obj,se,isite,cn,inbSet,nbSet,varargin)
            opts=parseNamed(struct(recompute=false,optimization=[]),varargin{:});
            value=se.get_coordination_environments(isite,cn,nbSet);
            if ~isempty(value)&&~opts.recompute,return,end
            obj.setup_local_geometry(isite,nbSet.neighb_coords);
            measures=obj.get_coordination_symmetry_measures();
            value=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.ChemicalEnvironments();
            for key=measures.keys
                symbol=key{1};data=measures(symbol);
                other=extractOtherMeasures(data);
                value.add_coord_geom(symbol,data.csm,"algo",data.algo, ...
                    "permutation",data.indices, ...
                    "local2perfect_map",data.local2perfect_map, ...
                    "perfect2local_map",data.perfect2local_map, ...
                    "detailed_voronoi_index", ...
                    struct(cn=cn,index=inbSet-1), ...
                    "other_symmetry_measures",other, ...
                    "rotation_matrix",data.rotation_matrix, ...
                    "scaling_factor",data.scaling_factor);
            end
            se.update_coordination_environments(isite,cn,nbSet,value);
        end
    end
    methods (Access=private)
        function value=computeAll(obj,onlyMinimum,allCsms,optimization) %#ok<INUSD>
            value=containers.Map("KeyType","char","ValueType","any");
            cn=obj.local_geometry.cn;
            geometries=obj.allcg.get_implemented_geometries( ...
                "coordination",cn);
            for ii=1:numel(geometries)
                cg=geometries{ii};
                obj.perfect_geometry=kssolv.analysis.matgenlab.analysis. ...
                    chemenv.coordination_environments.AbstractGeometry. ...
                    from_cg(cg,"centering_type",obj.centering_type, ...
                    "include_central_site_in_centroid", ...
                    obj.include_central_site_in_centroid);
                [results,perms,algos,l2p,p2l]=obj.evaluateGeometry(cg,[]);
                if isempty(results),continue,end
                csms=cellfun(@(x)x.symmetry_measure,results);
                if onlyMinimum,[~,indices]=min(csms);
                else,indices=1:numel(results);end
                if onlyMinimum
                    jj=indices;entry=results{jj};
                    entry.csm=entry.symmetry_measure;
                    entry.indices=perms{jj};entry.algo=algos{jj};
                    entry.local2perfect_map=l2p{jj};
                    entry.perfect2local_map=p2l{jj};
                    entry.scaling_factor=reciprocal(entry.scaling_factor);
                    entry.rotation_matrix=invertOrEmpty(entry.rotation_matrix);
                    if allCsms,entry=addAllMeasures(obj,entry,perms{jj});end
                    value(char(cg.mp_symbol))=entry;
                else
                    value(char(cg.mp_symbol))=struct(results={results}, ...
                        indices={perms},algo={algos}, ...
                        local2perfect_map={l2p},perfect2local_map={p2l});
                end
            end
        end
        function [results,permutations,algos,l2p,p2l]= ...
                evaluateGeometry(obj,cg,pointsPerfect)
            permutations={};algoNames={};
            for ii=1:numel(cg.algorithms)
                algo=cg.algorithms{ii};
                current=permutationsForAlgorithm(algo,cg.coordination_number);
                permutations=[permutations,current]; %#ok<AGROW>
                algoNames=[algoNames,repmat({char(algo)},1,numel(current))]; %#ok<AGROW>
            end
            if isempty(permutations)
                permutations={1:cg.coordination_number};
                algoNames={"IDENTITY"};
            end
            [results,permutations,~,l2p,p2l]=obj.evaluatePermutations( ...
                cg,permutations,pointsPerfect,"");
            algos=algoNames;
        end
        function [results,permutations,algos,l2p,p2l]= ...
                evaluatePermutations(obj,cg,permutations, ...
                pointsPerfect,algorithmName)
            if isempty(pointsPerfect)
                if isempty(obj.perfect_geometry)
                    obj.perfect_geometry=kssolv.analysis.matgenlab.analysis. ...
                        chemenv.coordination_environments.AbstractGeometry. ...
                        from_cg(cg,"centering_type",obj.centering_type, ...
                        "include_central_site_in_centroid", ...
                        obj.include_central_site_in_centroid);
                end
                pointsPerfect=obj.perfect_geometry.points_wcs_ctwcc();
            end
            results=cell(1,numel(permutations));l2p=cell(size(results));
            p2l=cell(size(results));algos=repmat({algorithmName},size(results));
            for ii=1:numel(permutations)
                perm=normalizePermutation(permutations{ii},cg.coordination_number);
                distorted=obj.local_geometry.points_wcs_ctwcc(perm);
                item=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments.symmetry_measure( ...
                    distorted,pointsPerfect);
                item.translation_vector=obj.local_geometry.centroid_with_centre;
                results{ii}=item;permutations{ii}=perm;
                l2p{ii}=inverseMap(perm);p2l{ii}=forwardMap(perm);
            end
        end
    end
end
function value=addAllMeasures(obj,value,permutation)
types=["wocs_ctwocc","wocs_ctwcc","wocs_csc", ...
    "wcs_ctwocc","wcs_ctwcc","wcs_csc"];
translations={obj.local_geometry.centroid_without_centre, ...
    obj.local_geometry.centroid_with_centre,obj.local_geometry.bare_centre, ...
    obj.local_geometry.centroid_without_centre, ...
    obj.local_geometry.centroid_with_centre,obj.local_geometry.bare_centre};
for ii=1:numel(types)
    name=char(types(ii));
    distorted=obj.local_geometry.("points_"+name)(permutation);
    perfect=obj.perfect_geometry.("points_"+name)();
    item=kssolv.analysis.matgenlab.analysis.chemenv. ...
        coordination_environments.symmetry_measure(distorted,perfect);
    value.("csm_"+name)=item.symmetry_measure;
    value.("rotation_matrix_"+name)=invertOrEmpty(item.rotation_matrix);
    value.("scaling_factor_"+name)=reciprocal(item.scaling_factor);
    value.("translation_vector_"+name)=translations{ii};
end
end
function value=extractOtherMeasures(data)
value=struct();names=fieldnames(data);
for ii=1:numel(names)
    if startsWith(names{ii},"csm_")|| ...
            startsWith(names{ii},"rotation_matrix_")|| ...
            startsWith(names{ii},"scaling_factor_")|| ...
            startsWith(names{ii},"translation_vector_")
        value.(names{ii})=data.(names{ii});
    end
end
end
function value=permutationsForAlgorithm(algo,cn)
value=algo.permutations;
if ~isempty(value),return,end
if cn<=8
    raw=perms(1:cn);
    value=mat2cell(raw,ones(1,size(raw,1)),cn).';
else,value={1:cn};end
end
function value=rotationValue(input)
if isnumeric(input),value=double(input);return,end
if string(input)~="RANDOM",value=eye(3);return,end
axis=rand(1,3);axis=axis/norm(axis);angle=pi*rand();
k=[0 -axis(3) axis(2);axis(3) 0 -axis(1);-axis(2) axis(1) 0];
value=eye(3)+sin(angle)*k+(1-cos(angle))*(k*k);
end
function value=randomBall(radius)
value=2*rand(1,3)-1;
while norm(value)>1,value=2*rand(1,3)-1;end
value=radius*value;
end
function value=normalizePermutation(value,n)
value=reshape(double(value),1,[]);
if any(value==0),value=value+1;end
if numel(value)~=n||any(sort(value)~=(1:n))
    error("KSSOLV:Matgenlab:ChemEnv:Permutation","Invalid permutation.");
end
end
function value=normalizeWireIndices(value)
value=reshape(double(value),1,[]);
if any(value==0),value=value+1;end
end
function value=normalizeSite(value,n)
value=double(value);
if value==0,value=1;end
if value<1||value>n,error("KSSOLV:Matgenlab:ChemEnv:Site","Invalid site.");end
end
function value=normalizeSites(value,n)
value=reshape(double(value),1,[]);
if any(value==0),value=value+1;end
if any(value<1|value>n),error("KSSOLV:Matgenlab:ChemEnv:Site","Invalid site.");end
end
function value=forwardMap(perm)
value=containers.Map("KeyType","double","ValueType","double");
for ii=1:numel(perm),value(ii)=perm(ii);end
end
function value=inverseMap(perm)
value=containers.Map("KeyType","double","ValueType","double");
for ii=1:numel(perm),value(perm(ii))=ii;end
end
function value=reciprocal(input)
if isempty(input)||input==0,value=[];else,value=1/input;end
end
function value=invertOrEmpty(input)
if isempty(input),value=[];else,value=inv(input);end
end
function opts=parseNamed(opts,varargin)
if ~isempty(varargin)&&isstruct(varargin{1})
    names=fieldnames(varargin{1});
    for ii=1:numel(names),opts.(names{ii})=varargin{1}.(names{ii});end
    varargin(1)=[];
end
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
