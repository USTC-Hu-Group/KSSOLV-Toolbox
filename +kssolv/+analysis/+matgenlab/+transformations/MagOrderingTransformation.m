classdef MagOrderingTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        mag_species_spin cell
        order_parameter cell
        energy_model
        enum_kwargs (1,1) struct
    end
    methods
        function obj=MagOrderingTransformation( ...
                speciesSpin,orderParameter,energyModel,varargin)
            if nargin<2,orderParameter=.5;end
            if nargin<3||isempty(energyModel)
                energyModel=kssolv.analysis.matgenlab.core.SymmetryModel();
            end
            if isa(speciesSpin,"containers.Map")
                names=speciesSpin.keys();pairs=cell(numel(names),2);
                for index=1:numel(names)
                    pairs(index,:)={names{index},speciesSpin(names{index})};
                end
            elseif isstruct(speciesSpin)
                names=fieldnames(speciesSpin);pairs=cell(numel(names),2);
                for index=1:numel(names)
                    pairs(index,:)={names{index},speciesSpin.(names{index})};
                end
            else
                pairs=speciesSpin;
                if iscell(pairs)&&isvector(pairs)&&numel(pairs)==2
                    pairs=reshape(pairs,1,2);
                end
            end
            if isnumeric(orderParameter)&&isscalar(orderParameter)
                constraints={kssolv.analysis.matgenlab.transformations. ...
                    MagOrderParameterConstraint(orderParameter,pairs(:,1))};
            elseif iscell(orderParameter)
                constraints=orderParameter;
                if ~any(cellfun(@(item)isa(item, ...
                        "kssolv.analysis.matgenlab.transformations." + ...
                        "MagOrderParameterConstraint"),constraints))
                    error("KSSOLV:Matgenlab:MagOrdering:OrderParameter", ...
                        "Order parameter is not correctly defined.");
                end
            else
                error("KSSOLV:Matgenlab:MagOrdering:OrderParameter", ...
                    "order_parameter must be scalar or a cell of constraints.");
            end
            options=struct();
            for index=1:2:numel(varargin)
                options.(char(string(varargin{index})))=varargin{index+1};
            end
            obj.mag_species_spin=pairs;
            obj.order_parameter=constraints;
            obj.energy_model=energyModel;obj.enum_kwargs=options;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:MagOrdering:Disordered", ...
                    "Create an ordered approximation first.");
            end
            groups=cell(1,numel(obj.order_parameter));
            for index=1:structure.num_sites
                matches=cellfun(@(constraint) ...
                    constraint.satisfies_constraint(structure(index)), ...
                    obj.order_parameter);
                if nnz(matches)>1
                    error("KSSOLV:Matgenlab:MagOrdering:Conflict", ...
                        "Order parameter constraints conflict for a site.");
                elseif any(matches)
                    group=find(matches,1);
                    groups{group}(end+1)=index;
                end
            end
            choices=cell(1,numel(groups));
            for group=1:numel(groups)
                count=numel(groups{group});
                up=round(count*obj.order_parameter{group}.order_parameter);
                if abs(up-count*obj.order_parameter{group}.order_parameter)>1e-8
                    scale=kssolv.analysis.matgenlab.transformations. ...
                        MagOrderingTransformation.denominator( ...
                        obj.order_parameter{group}.order_parameter);
                    structure=structure*[scale,1,1];
                    returnResult=obj.apply_transformation( ...
                        structure,returnRankedList);
                    result=returnResult;return
                end
                choices{group}= ...
                    kssolv.analysis.matgenlab.transformations.internal. ...
                    Utils.choose(groups{group},up);
            end
            combinations=kssolv.analysis.matgenlab.transformations. ...
                internal.Utils.productChoices(choices);
            ranked=cell(1,numel(combinations));
            for item=1:numel(combinations)
                upIndices=combinations{item};
                candidate=structure.copy();
                for index=1:candidate.num_sites
                    mappingIndex=find(cellfun(@(name) ...
                        string(candidate(index).specie)==string(name), ...
                        obj.mag_species_spin(:,1)),1);
                    if isempty(mappingIndex),continue,end
                    magnitude=double(obj.mag_species_spin{mappingIndex,2});
                    signValue=2*ismember(index,upIndices)-1;
                    current=candidate(index).specie;
                    oxidation=NaN;
                    if isa(current,"kssolv.analysis.matgenlab.core.Species")
                        oxidation=current.oxi_state;
                    end
                    replacement=kssolv.analysis.matgenlab.core. ...
                        Species(current.symbol,oxidation, ...
                        "spin",signValue*magnitude);
                    candidate=candidate.replace(index,replacement);
                end
                ranked{item}=struct("structure",candidate, ...
                    "energy",obj.energy_model.get_energy(candidate));
            end
            [~,order]=sort(cellfun(@(entry)entry.energy,ranked));
            ranked=ranked(order);
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            if count==0||count==1,result=ranked{1}.structure;
            else,result=ranked(1:min(count,numel(ranked)));end
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function value=determine_min_cell(structure)
            orderParameters=containers.Map( ...
                "KeyType","char","ValueType","double");
            occurrences=containers.Map( ...
                "KeyType","char","ValueType","double");
            for index=1:structure.num_sites
                if structure(index).is_ordered,continue,end
                orderingSite=structure(index);
                [species,amounts]=orderingSite.species.items();
                name=char(string(species{1}));
                comma=strfind(name,",");
                if ~isempty(comma),name=name(1:comma(1)-1);end
                if isKey(occurrences,name)
                    occurrences(name)=occurrences(name)+1;
                else
                    occurrences(name)=1;
                    orderParameters(name)=max(amounts);
                end
            end
            names=occurrences.keys();
            factors=ones(1,numel(names));
            for index=1:numel(names)
                name=names{index};
                denominator=kssolv.analysis.matgenlab.transformations. ...
                    MagOrderingTransformation.denominator( ...
                    orderParameters(name));
                factors(index)=denominator/ ...
                    gcd(denominator,occurrences(name));
            end
            value=max([1,factors]);
        end
        function obj=from_dict(value)
            constraints=value.order_parameter;
            if ~iscell(constraints),constraints={constraints};end
            for index=1:numel(constraints)
                if ~isa(constraints{index}, ...
                        "kssolv.analysis.matgenlab.transformations." + ...
                        "MagOrderParameterConstraint")
                    constraints{index}= ...
                        kssolv.analysis.matgenlab.transformations. ...
                        MagOrderParameterConstraint.from_dict( ...
                        constraints{index});
                end
            end
            args={};names=fieldnames(value.enum_kwargs);
            for index=1:numel(names)
                args(end+(1:2))={names{index}, ...
                    value.enum_kwargs.(names{index})}; %#ok<AGROW>
            end
            obj=kssolv.analysis.matgenlab.transformations. ...
                MagOrderingTransformation(value.mag_species_spin, ...
                constraints,value.energy_model,args{:});
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                MagOrderingTransformation.from_dict(value);end
    end
    methods (Static,Access=private)
        function denominator=denominator(value)
            candidates=1:100;
            errors=abs(round(value*candidates)./candidates-value);
            denominator=candidates(find(errors<1e-10,1));
            if isempty(denominator),denominator=100;end
        end
    end
end
