classdef EnumerateStructureTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        min_cell_size (1,1) double
        max_cell_size
        symm_prec (1,1) double
        refine_structure (1,1) logical
        enum_precision_parameter (1,1) double
        check_ordered_symmetry (1,1) logical
        max_disordered_sites
        sort_criteria
        timeout
        n_jobs (1,1) double
    end
    properties (Hidden,Access=private)
        state
    end
    methods
        function obj=EnumerateStructureTransformation( ...
                minCell,maxCell,symmPrec,refineStructure, ...
                enumPrecision,checkOrdered,maxDisordered,sortCriteria, ...
                timeout,nJobs)
            if nargin<1,minCell=1;end
            if nargin<2,maxCell=1;end
            if nargin<3,symmPrec=.1;end
            if nargin<4,refineStructure=false;end
            if nargin<5,enumPrecision=.001;end
            if nargin<6,checkOrdered=true;end
            if nargin<7,maxDisordered=[];end
            if nargin<8,sortCriteria="ewald";end
            if nargin<9,timeout=[];end
            if nargin<10,nJobs=-1;end
            if ~isempty(maxCell)&&~isempty(maxDisordered)
                error("KSSOLV:Matgenlab:EnumerateStructure:CellLimits", ...
                    "Cannot set both max_cell_size and max_disordered_sites.");
            end
            obj.min_cell_size=minCell;obj.max_cell_size=maxCell;
            obj.symm_prec=symmPrec;obj.refine_structure=refineStructure;
            obj.enum_precision_parameter=enumPrecision;
            obj.check_ordered_symmetry=checkOrdered;
            obj.max_disordered_sites=maxDisordered;
            obj.sort_criteria=sortCriteria;obj.timeout=timeout;obj.n_jobs=nJobs;
            obj.state=kssolv.analysis.matgenlab.transformations.internal.State();
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            if obj.refine_structure
                analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure,obj.symm_prec);
                structure=analyzer.get_refined_structure();
            end
            if structure.is_ordered
                ranked={struct("structure",structure.copy(), ...
                    "num_sites",structure.num_sites)};
            else
                disordered=sum(~cellfun(@(site)site.is_ordered, ...
                    structure.sites));
                if ~isempty(obj.max_disordered_sites)
                    if disordered>obj.max_disordered_sites
                        error("KSSOLV:Matgenlab:EnumerateStructure:TooManySites", ...
                            "Too many disordered sites.");
                    end
                    maximum=floor(obj.max_disordered_sites/disordered);
                else
                    maximum=obj.max_cell_size;
                end
                ranked=cell(1,0);
                for scale=obj.min_cell_size:maximum
                    matrices=kssolv.analysis.matgenlab.transformations. ...
                        EnumerateStructureTransformation.hnfMatrices(scale);
                    for matrixIndex=1:numel(matrices)
                        candidate=structure*matrices{matrixIndex};
                        ordering=kssolv.analysis.matgenlab.transformations. ...
                            OrderDisorderedStructureTransformation( ...
                            kssolv.analysis.matgenlab.transformations. ...
                            OrderDisorderedStructureTransformation.ALGO_COMPLETE);
                        try
                            values=ordering.apply_transformation(candidate,Inf);
                        catch exception
                            if exception.identifier== ...
                                    "KSSOLV:Matgenlab:OrderDisordered:Occupancy"
                                continue
                            end
                            rethrow(exception)
                        end
                        if ~iscell(values)
                            values={struct("structure",values)};
                        end
                        for index=1:numel(values)
                            entry=values{index};
                            if ~isfield(entry,"num_sites")
                                entry.num_sites=entry.structure.num_sites;
                            end
                            ranked{end+1}=entry; %#ok<AGROW>
                        end
                    end
                    if ~isempty(ranked),break,end
                end
            end
            if isempty(ranked)
                error("KSSOLV:Matgenlab:EnumerateStructure:Unable", ...
                    "Unable to enumerate the input structure.");
            end
            uniqueEntries=cell(1,0);
            if numel(ranked)>50
                signatures=containers.Map("KeyType","char","ValueType","any");
                matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
                for index=1:numel(ranked)
                    signature=kssolv.analysis.matgenlab.transformations. ...
                        EnumerateStructureTransformation. ...
                        structureSignature(ranked{index}.structure);
                    if ~isKey(signatures,signature)
                        signatures(signature)=numel(uniqueEntries)+1;
                        uniqueEntries{end+1}=ranked{index}; %#ok<AGROW>
                    else
                        representatives=signatures(signature);
                        duplicate=false;
                        for representative=reshape(representatives,1,[])
                            if matcher.fit( ...
                                    uniqueEntries{representative}.structure, ...
                                    ranked{index}.structure)
                                duplicate=true;break
                            end
                        end
                        if ~duplicate
                            uniqueEntries{end+1}=ranked{index}; %#ok<AGROW>
                            signatures(signature)=[representatives, ...
                                numel(uniqueEntries)];
                        end
                    end
                end
            else
                matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
                for index=1:numel(ranked)
                    duplicate=any(cellfun(@(entry)matcher.fit( ...
                        entry.structure,ranked{index}.structure),uniqueEntries));
                    if ~duplicate
                        uniqueEntries{end+1}=ranked{index}; %#ok<AGROW>
                    end
                end
            end
            ranked=uniqueEntries;
            criterion=lower(string(obj.sort_criteria));
            if ~isa(obj.sort_criteria,"function_handle")&& ...
                    startsWith(criterion,"m3gnet")
                error("KSSOLV:Matgenlab:EnumerateStructure:M3GNet", ...
                    "M3GNet sorting requires an external MATGL model; " + ...
                    "supply a MATLAB sort_criteria function handle.");
            end
            useEnergy=isa(obj.sort_criteria,"function_handle")|| ...
                criterion=="ewald";
            for index=1:numel(ranked)
                if isa(obj.sort_criteria,"function_handle")
                    [candidate,energy]=obj.sort_criteria( ...
                        ranked{index}.structure);
                    ranked{index}.structure=candidate;
                    ranked{index}.energy=energy;
                elseif lower(string(obj.sort_criteria))=="ewald"
                    try
                        ranked{index}.energy= ...
                            kssolv.analysis.matgenlab.core. ...
                            EwaldSummation(ranked{index}.structure).total_energy;
                    catch
                        useEnergy=false;
                    end
                end
                ranked{index}.num_sites=ranked{index}.structure.num_sites;
            end
            if useEnergy
                scores=cellfun(@(entry)entry.energy/entry.num_sites,ranked);
            else
                for index=1:numel(ranked)
                    if isfield(ranked{index},"energy")
                        ranked{index}=rmfield(ranked{index},"energy");
                    end
                    if isfield(ranked{index},"energy_above_minimum")
                        ranked{index}=rmfield( ...
                            ranked{index},"energy_above_minimum");
                    end
                end
                scores=cellfun(@(entry)entry.num_sites,ranked);
            end
            [~,order]=sort(scores);ranked=ranked(order);
            obj.state.data=ranked;
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            if count==0,result=ranked{1}.structure;
            else,result=ranked(1:min(count,numel(ranked)));end
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static,Access=private)
        function matrices=hnfMatrices(determinant)
            matrices=cell(1,0);
            for a=1:determinant
                if mod(determinant,a)~=0,continue,end
                remaining=determinant/a;
                for d=1:remaining
                    if mod(remaining,d)~=0,continue,end
                    f=remaining/d;
                    for b=0:a-1
                        for c=0:a-1
                            for e=0:d-1
                                % Row Hermite normal form. The off-diagonal
                                % bounds are set by the pivot in their column.
                                matrices{end+1}= ...
                                    [a,0,0;b,d,0;c,e,f]; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end
        function value=structureSignature(structure)
            labels=strings(structure.num_sites,1);
            for index=1:structure.num_sites
                labels(index)=structure(index).species_string;
            end
            tokens=strings(1,0);
            for first=1:structure.num_sites-1
                for second=first+1:structure.num_sites
                    pair=sort([labels(first),labels(second)]);
                    distance=round(structure.get_distance(first,second),5);
                    tokens(end+1)=pair(1)+"|"+pair(2)+":"+ ...
                        compose("%.5f",distance); %#ok<AGROW>
                end
            end
            value=char(strjoin(sort(tokens),";"));
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                EnumerateStructureTransformation(value.min_cell_size, ...
                value.max_cell_size,value.symm_prec,value.refine_structure, ...
                value.enum_precision_parameter,value.check_ordered_symmetry, ...
                value.max_disordered_sites,value.sort_criteria, ...
                value.timeout,value.n_jobs);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                EnumerateStructureTransformation.from_dict(value);end
    end
end
