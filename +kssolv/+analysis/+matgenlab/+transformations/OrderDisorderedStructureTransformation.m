classdef OrderDisorderedStructureTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (Constant)
        ALGO_FAST=0
        ALGO_COMPLETE=1
        ALGO_BEST_FIRST=2
        ALGO_RANDOM=-1
    end
    properties (SetAccess=private)
        algo (1,1) double
        symmetrized_structures (1,1) logical
        no_oxi_states (1,1) logical
        occ_tol (1,1) double
        symprec
        angle_tolerance
    end
    properties (Dependent,SetAccess=private)
        lowest_energy_structure
    end
    properties (Hidden,Access=private)
        state
    end
    methods
        function obj=OrderDisorderedStructureTransformation( ...
                algo,symmetrizedStructures,noOxiStates,occTol, ...
                symprec,angleTolerance)
            if nargin<1,algo=obj.ALGO_FAST;end
            if nargin<2,symmetrizedStructures=false;end
            if nargin<3,noOxiStates=false;end
            if nargin<4,occTol=.25;end
            if nargin<5,symprec=[];end
            if nargin<6,angleTolerance=[];end
            obj.algo=algo;
            obj.symmetrized_structures=symmetrizedStructures;
            obj.no_oxi_states=noOxiStates;obj.occ_tol=occTol;
            obj.symprec=symprec;obj.angle_tolerance=angleTolerance;
            obj.state=kssolv.analysis.matgenlab.transformations.internal.State();
        end

        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            if obj.symmetrized_structures&&~isa(structure, ...
                    "kssolv.analysis.matgenlab.symmetry.structure.SymmetrizedStructure")
                tolerance=.01;
                angleTolerance=5;
                if ~isempty(obj.symprec),tolerance=obj.symprec;end
                if ~isempty(obj.angle_tolerance)
                    angleTolerance=obj.angle_tolerance;
                end
                analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure,tolerance,angleTolerance);
                structure=analyzer.get_symmetrized_structure();
            end
            symmetryLabels=[];
            if obj.symmetrized_structures&&isa(structure, ...
                    "kssolv.analysis.matgenlab.symmetry.structure.SymmetrizedStructure")
                symmetryLabels=structure.site_labels;
            end
            groups={};exemplars={};
            for index=1:structure.num_sites
                site=structure(index);
                if site.is_ordered,continue,end
                matched=0;
                for group=1:numel(exemplars)
                    sameSymmetry=isempty(symmetryLabels)|| ...
                        symmetryLabels(index)== ...
                        symmetryLabels(groups{group}(1));
                    if sameSymmetry&&site.species. ...
                            almost_equals(exemplars{group}.species)
                        matched=group;break
                    end
                end
                if matched==0
                    exemplars{end+1}=site; %#ok<AGROW>
                    groups{end+1}=index; %#ok<AGROW>
                else
                    groups{matched}(end+1)=index; %#ok<AGROW>
                end
            end
            if isempty(groups)
                obj.state.data={struct("structure",structure.copy(), ...
                    "energy",0,"energy_above_minimum",0)};
                if returnRankedList,result=obj.state.data;else,result=structure.copy();end
                return
            end
            assignments=cell(1,numel(groups));speciesLists=cell(1,numel(groups));
            for group=1:numel(groups)
                [species,amounts]=exemplars{group}.species.items();
                count=numel(groups{group});
                counts=round(amounts*count);
                if any(abs(amounts*count-counts)>obj.occ_tol)
                    error("KSSOLV:Matgenlab:OrderDisordered:Occupancy", ...
                        "Occupancy fractions are not consistent with the " + ...
                        "size of the unit cell.");
                end
                vacancy=count-sum(counts);
                if vacancy<0
                    error("KSSOLV:Matgenlab:OrderDisordered:Occupancy", ...
                        "Site occupancies exceed one.");
                end
                occupied=arrayfun(@(index) ...
                    repmat(index,1,counts(index)),1:numel(counts), ...
                    "UniformOutput",false);
                multiset=[zeros(1,vacancy),occupied{:}];
                assignments{group}= ...
                    kssolv.analysis.matgenlab.transformations. ...
                    OrderDisorderedStructureTransformation. ...
                    uniquePermutations(multiset);
                speciesLists{group}=species;
            end
            combinations= ...
                kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                productChoices(assignments);
            if obj.algo==obj.ALGO_RANDOM
                stream=RandStream("mt19937ar","Seed",0);
                combinations=combinations(randperm(stream,numel(combinations)));
            end
            ranked=cell(1,numel(combinations));
            groupLengths=cellfun(@numel,groups);
            for combinationIndex=1:numel(combinations)
                selected=combinations{combinationIndex};
                candidate=kssolv.analysis.matgenlab.core.Structure. ...
                    from_sites(structure.sites);
                remove=[];offset=0;
                for group=1:numel(groups)
                    values=selected(offset+(1:groupLengths(group)));
                    offset=offset+groupLengths(group);
                    for position=1:numel(values)
                        siteIndex=groups{group}(position);
                        if values(position)==0
                            remove(end+1)=siteIndex; %#ok<AGROW>
                        else
                            replacement=speciesLists{group}{values(position)};
                            if obj.no_oxi_states
                                replacement=kssolv.analysis.matgenlab.core. ...
                                    Element(replacement.symbol);
                            end
                            candidate=candidate.replace(siteIndex,replacement);
                        end
                    end
                end
                if ~isempty(remove),candidate=candidate.remove_sites(remove);end
                if obj.no_oxi_states
                    candidate=candidate.remove_oxidation_states();
                end
                candidate=candidate.get_sorted_structure();
                try
                    matrix=kssolv.analysis.matgenlab.core. ...
                        EwaldSummation(candidate).total_energy_matrix;
                    energy=sum(matrix,"all");
                catch
                    energy=0;
                end
                ranked{combinationIndex}=struct( ...
                    "structure",candidate,"energy",energy, ...
                    "energy_above_minimum",0);
            end
            energies=cellfun(@(entry)entry.energy,ranked);
            [~,order]=sort(energies);ranked=ranked(order);
            minimum=ranked{1}.energy;
            atoms=max(1,ranked{1}.structure.num_sites);
            for index=1:numel(ranked)
                ranked{index}.energy_above_minimum= ...
                    (ranked{index}.energy-minimum)/atoms;
            end
            obj.state.data=ranked;
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            if count==0,result=ranked{1}.structure;
            else,result=ranked(1:min(count,numel(ranked)));end
        end

        function value=get.lowest_energy_structure(obj)
            if isempty(obj.state)||isempty(obj.state.data)
                error("KSSOLV:Matgenlab:OrderDisordered:NotApplied", ...
                    "Apply the transformation before requesting its minimum.");
            end
            value=obj.state.data{1}.structure;
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                OrderDisorderedStructureTransformation(value.algo, ...
                value.symmetrized_structures,value.no_oxi_states, ...
                value.occ_tol,value.symprec,value.angle_tolerance);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                OrderDisorderedStructureTransformation.from_dict(value);end
    end
    methods (Static,Access=private)
        function values=uniquePermutations(multiset)
            if isempty(multiset),values=zeros(1,0);return,end
            [symbols,~,locations]=unique(multiset,"stable");
            counts=accumarray(locations(:),1).';
            width=numel(multiset);
            number=round(exp(gammaln(width+1)- ...
                sum(gammaln(counts+1))));
            values=zeros(number,width);
            current=zeros(1,width);
            cursor=0;
            build(1);

            function build(position)
                if position>width
                    cursor=cursor+1;
                    values(cursor,:)=current;
                    return
                end
                for symbolIndex=1:numel(symbols)
                    if counts(symbolIndex)==0,continue,end
                    counts(symbolIndex)=counts(symbolIndex)-1;
                    current(position)=symbols(symbolIndex);
                    build(position+1);
                    counts(symbolIndex)=counts(symbolIndex)+1;
                end
            end
        end
    end
end
