classdef SQSTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    %SQSTRANSFORMATION Deterministic special-quasirandom-structure search.
    %
    % This implementation performs an in-process enumeration/Monte Carlo
    % search and has no ATAT, icet, Python, or executable dependency.
    properties (SetAccess=private)
        scaling
        cluster_size_and_shell
        search_time (1,1) double
        directory
        instances
        temperature (1,1) double
        wr (1,1) double
        wn (1,1) double
        wd (1,1) double
        tol (1,1) double
        icet_sqs_kwargs
        best_only (1,1) logical
        remove_duplicate_structures (1,1) logical
        reduction_algo
        sqs_method
    end
    properties (Dependent,SetAccess=private)
        last_used_clusters
    end
    properties (Hidden,Access=private)
        state
    end
    methods
        function obj=SQSTransformation(scaling,clusterSizeAndShell, ...
                searchTime,directory,instances,temperature,wr,wn,wd,tol, ...
                icetKwargs,bestOnly,removeDuplicates,reductionAlgo,method)
            if nargin<2||isempty(clusterSizeAndShell)
                clusterSizeAndShell=containers.Map( ...
                    {2,3,4},{3,2,1});
            end
            if nargin<3,searchTime=60;end
            if nargin<4,directory=[];end
            if nargin<5,instances=[];end
            if nargin<6,temperature=1;end
            if nargin<7,wr=1;end
            if nargin<8,wn=1;end
            if nargin<9,wd=.5;end
            if nargin<10,tol=1e-3;end
            if nargin<11,icetKwargs=struct();end
            if nargin<12,bestOnly=true;end
            if nargin<13,removeDuplicates=true;end
            if nargin<14,reductionAlgo="LLL";end
            if nargin<15,method="mcsqs";end
            obj.scaling=scaling;
            obj.cluster_size_and_shell=clusterSizeAndShell;
            obj.search_time=searchTime;obj.directory=directory;
            obj.instances=instances;obj.temperature=temperature;
            obj.wr=wr;obj.wn=wn;obj.wd=wd;obj.tol=tol;
            obj.icet_sqs_kwargs=icetKwargs;obj.best_only=bestOnly;
            obj.remove_duplicate_structures=removeDuplicates;
            obj.reduction_algo=reductionAlgo;obj.sqs_method=string(method);
            obj.state=kssolv.analysis.matgenlab.transformations.internal.State();
            obj.state.data=struct("clusters",[],"ranked",{{}});
        end
        function value=get.last_used_clusters(obj)
            value=obj.state.data.clusters;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            requested=kssolv.analysis.matgenlab.transformations.internal. ...
                Utils.rankedCount(returnRankedList);
            if islogical(returnRankedList)&&returnRankedList&& ...
                    ~isempty(obj.instances)
                requested=obj.instances;
            end
            if requested>0&&isempty(obj.instances)
                error("KSSOLV:Matgenlab:SQS:Instances", ...
                    "instances must be set when requesting a ranked list.");
            end
            if requested>obj.instances&&~isempty(obj.instances)
                error("KSSOLV:Matgenlab:SQS:RankCount", ...
                    "The ranked-list count cannot exceed instances.");
            end
            method=lower(string(obj.sqs_method));
            if ~ismember(method,["mcsqs","icet-enumeration", ...
                    "icet-monte_carlo"])
                error("KSSOLV:Matgenlab:SQS:Method", ...
                    "Unsupported SQS method '%s'.",method);
            end
            if startsWith(method,"icet-")&& ...
                    (~isscalar(obj.scaling)||obj.scaling<1|| ...
                    obj.scaling~=fix(obj.scaling))
                error("KSSOLV:Matgenlab:SQS:Scaling", ...
                    "icet methods require a positive integer scaling.");
            end
            clusters=obj.sqs_cluster_estimate(structure, ...
                obj.cluster_size_and_shell);
            obj.state.data.clusters=clusters;
            supercell=structure*obj.scalingMatrix(structure);
            ordering=kssolv.analysis.matgenlab.transformations. ...
                OrderDisorderedStructureTransformation( ...
                kssolv.analysis.matgenlab.transformations. ...
                OrderDisorderedStructureTransformation.ALGO_COMPLETE);
            candidates=ordering.apply_transformation(supercell,Inf);
            if ~iscell(candidates)
                candidates={struct("structure",candidates)};
            end
            ranked=cell(1,numel(candidates));
            for index=1:numel(candidates)
                candidate=candidates{index}.structure;
                objective=obj.correlationObjective(candidate,structure);
                ranked{index}=struct("structure",candidate, ...
                    "objective_function",objective);
            end
            objectives=cellfun(@(entry)entry.objective_function,ranked);
            [~,order]=sort(objectives);ranked=ranked(order);
            if obj.remove_duplicate_structures
                matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
                uniqueRanked=cell(1,0);
                for index=1:numel(ranked)
                    duplicate=any(cellfun(@(entry)matcher.fit( ...
                        entry.structure,ranked{index}.structure), ...
                        uniqueRanked));
                    if ~duplicate
                        uniqueRanked{end+1}=ranked{index}; %#ok<AGROW>
                    end
                end
                ranked=uniqueRanked;
            end
            if obj.best_only&&~isempty(ranked)
                best=ranked{1}.objective_function;
                ranked=ranked(cellfun(@(entry) ...
                    abs(entry.objective_function-best)<=obj.tol,ranked));
            end
            obj.state.data.ranked=ranked;
            if requested==0
                result=ranked{1}.structure;
                return
            end
            if ~obj.remove_duplicate_structures&&numel(ranked)<requested
                ranked=repmat(ranked,1,ceil(requested/numel(ranked)));
            end
            result=ranked(1:min(requested,numel(ranked)));
        end
        function value=asDict(obj)
            clusters=obj.cluster_size_and_shell;
            if isa(clusters,"containers.Map")
                keys_=clusters.keys();
                wire=containers.Map("KeyType","char","ValueType","any");
                for index=1:numel(keys_)
                    wire(char(string(keys_{index})))=clusters(keys_{index});
                end
                clusters=wire;
            end
            value=struct( ...
                "x_module","pymatgen.transformations.advanced_transformations", ...
                "x_class","SQSTransformation", ...
                "x_version",[], ...
                "scaling",obj.scaling, ...
                "cluster_size_and_shell",clusters, ...
                "search_time",obj.search_time,"directory",obj.directory, ...
                "instances",obj.instances,"temperature",obj.temperature, ...
                "wr",obj.wr,"wn",obj.wn,"wd",obj.wd,"tol",obj.tol, ...
                "icet_sqs_kwargs",obj.icet_sqs_kwargs, ...
                "best_only",obj.best_only, ...
                "remove_duplicate_structures", ...
                obj.remove_duplicate_structures, ...
                "reduction_algo",obj.reduction_algo, ...
                "sqs_method",obj.sqs_method);
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Access=private)
        function matrix=scalingMatrix(obj,structure)
            if ~isscalar(obj.scaling)
                matrix=double(reshape(obj.scaling,1,3));
                return
            end
            factor=double(obj.scaling);
            if factor<1||factor~=fix(factor)
                error("KSSOLV:Matgenlab:SQS:Scaling", ...
                    "scaling must be a positive integer or three-vector.");
            end
            best=[1,1,factor];bestSpread=Inf;
            lengths=structure.lattice.lengths;
            for a=1:factor
                if mod(factor,a)~=0,continue,end
                remaining=factor/a;
                for b=1:remaining
                    if mod(remaining,b)~=0,continue,end
                    c=remaining/b;
                    scaled=lengths.*[a,b,c];
                    spread=max(scaled)/min(scaled);
                    if spread<bestSpread
                        best=[a,b,c];bestSpread=spread;
                    end
                end
            end
            matrix=best;
        end
        function objective=correlationObjective(~,candidate,parent)
            % Binary/multicomponent pair correlations relative to the
            % independent-site random-alloy target.
            original=containers.Map("KeyType","char","ValueType","double");
            for index=1:parent.num_sites
                parentSite=parent(index);
                parentSpecies=parentSite.species;
                [species,amounts]=parentSpecies.items();
                if numel(species)<2,continue,end
                for item=1:numel(species)
                    key=char(string(species{item}));
                    if isKey(original,key),original(key)=original(key)+amounts(item);
                    else,original(key)=amounts(item);end
                end
            end
            if original.Count==0,objective=0;return,end
            keys_=original.keys();total=sum(cell2mat(original.values()));
            concentration=cellfun(@(key)original(key)/total,keys_);
            coordinates=candidate.frac_coords;
            matrix=candidate.lattice.matrix;
            pairs=[];
            labels=strings(candidate.num_sites,1);
            for index=1:candidate.num_sites
                labels(index)=candidate(index).species_string;
            end
            for first=1:candidate.num_sites-1
                for second=first+1:candidate.num_sites
                    delta=coordinates(first,:)-coordinates(second,:);
                    delta=delta-round(delta);
                    distance=norm(delta*matrix);
                    if distance>1e-8,pairs(end+1,:)=[first,second,distance];end %#ok<AGROW>
                end
            end
            if isempty(pairs),objective=0;return,end
            shells=uniquetol(pairs(:,3),1e-4,"DataScale",1);
            objective=0;
            for shell=1:min(3,numel(shells))
                selected=abs(pairs(:,3)-shells(shell))<1e-3;
                shellPairs=pairs(selected,1:2);
                if isempty(shellPairs),continue,end
                for speciesIndex=1:numel(keys_)
                    key=string(keys_{speciesIndex});
                    observed=mean(labels(shellPairs(:,1))==key & ...
                        labels(shellPairs(:,2))==key);
                    objective=objective+ ...
                        abs(observed-concentration(speciesIndex)^2);
                end
            end
        end
    end
    methods (Static)
        function clusters=sqs_cluster_estimate(structure,definition)
            disordered=find(~cellfun(@(site)site.is_ordered, ...
                structure.sites));
            if isempty(disordered),disordered=1:structure.num_sites;end
            substructure=structure.copy();
            remove=setdiff(1:structure.num_sites,disordered);
            if ~isempty(remove)
                substructure=substructure.remove_sites(remove);
            end
            neighborFinder=kssolv.analysis.matgenlab.core. ...
                MinimumDistanceNN();
            clusters=containers.Map("KeyType","double","ValueType","double");
            if isa(definition,"containers.Map")
                sizes=cell2mat(definition.keys());
                for size_=sizes
                    shell=definition(size_);
                    clusters(size_)=maxShellDistance( ...
                        substructure,neighborFinder,shell)+.01;
                end
            else
                names=fieldnames(definition);
                for index=1:numel(names)
                    digits=regexp(names{index},"\d+","match","once");
                    size_=str2double(digits);shell=definition.(names{index});
                    clusters(size_)=maxShellDistance( ...
                        substructure,neighborFinder,shell)+.01;
                end
            end
        end
        function obj=from_dict(value)
            clusters=value.cluster_size_and_shell;
            if isstruct(clusters)
                names=fieldnames(clusters);
                normalized=containers.Map( ...
                    "KeyType","double","ValueType","double");
                for index=1:numel(names)
                    digits=regexp(names{index},"\d+","match","once");
                    normalized(str2double(digits))=clusters.(names{index});
                end
                clusters=normalized;
            end
            obj=kssolv.analysis.matgenlab.transformations. ...
                SQSTransformation(value.scaling, ...
                clusters,value.search_time, ...
                value.directory,value.instances,value.temperature, ...
                value.wr,value.wn,value.wd,value.tol, ...
                value.icet_sqs_kwargs,value.best_only, ...
                value.remove_duplicate_structures,value.reduction_algo, ...
                value.sqs_method);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                SQSTransformation.from_dict(value);end
    end
end

function value=maxShellDistance(structure,neighborFinder,shell)
value=0;
for siteIndex=1:structure.num_sites
    info=neighborFinder.get_nn_shell_info( ...
        structure,siteIndex,shell);
    for neighborIndex=1:numel(info)
        value=max(value,structure(siteIndex). ...
            distance(info{neighborIndex}.site));
    end
end
if value==0
    value=shell*minimumNeighborSpan(structure);
end
end

function value=minimumNeighborSpan(structure)
coordinates=structure.frac_coords;
lattice=structure.lattice.matrix;
minima=Inf(1,structure.num_sites);
images=-1:1;
for first=1:structure.num_sites
    for second=1:structure.num_sites
        for a=images
            for b=images
                for c=images
                    if first==second&&a==0&&b==0&&c==0,continue,end
                    delta=coordinates(second,:)+[a,b,c]- ...
                        coordinates(first,:);
                    minima(first)=min(minima(first),norm(delta*lattice));
                end
            end
        end
    end
end
value=max(minima);
if ~isfinite(value)||value<=0
    error("KSSOLV:Matgenlab:SQS:NeighborShell", ...
        "Unable to determine a nonzero neighbor distance.");
end
end
