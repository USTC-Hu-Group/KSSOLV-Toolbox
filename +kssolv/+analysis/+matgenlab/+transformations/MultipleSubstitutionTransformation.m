classdef MultipleSubstitutionTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        sp_to_replace
        r_fraction (1,1) double
        substitution_dict
        charge_balance_species
        order (1,1) logical
    end
    methods
        function obj=MultipleSubstitutionTransformation( ...
                species,fraction,substitutions,balanceSpecies,order)
            if nargin<4,balanceSpecies=[];end
            if nargin<5,order=true;end
            obj.sp_to_replace=species;obj.r_fraction=fraction;
            obj.substitution_dict=substitutions;
            obj.charge_balance_species=balanceSpecies;obj.order=order;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3||~returnRankedList
                error("KSSOLV:Matgenlab:MultipleSubstitution:RankedOnly", ...
                    "MultipleSubstitutionTransformation requires a ranked list.");
            end
            if isstruct(obj.substitution_dict)
                names=fieldnames(obj.substitution_dict);
                entries=cell(numel(names),2);
                for index=1:numel(names)
                    entries(index,:)={str2double(regexprep(names{index},'\\D','')), ...
                        obj.substitution_dict.(names{index})};
                end
            elseif isa(obj.substitution_dict,"containers.Map")
                names=obj.substitution_dict.keys();entries=cell(numel(names),2);
                for index=1:numel(names)
                    entries(index,:)={str2double(names{index}), ...
                        obj.substitution_dict(names{index})};
                end
            else
                entries=obj.substitution_dict;
            end
            result=cell(1,0);
            for group=1:size(entries,1)
                charge=double(entries{group,1});
                dummy=kssolv.analysis.matgenlab.core.DummySpecies( ...
                    "X",charge);
                mapping={obj.sp_to_replace, ...
                    {obj.sp_to_replace,1-obj.r_fraction; ...
                    dummy,obj.r_fraction}};
                candidate=kssolv.analysis.matgenlab.transformations. ...
                    SubstitutionTransformation(mapping). ...
                    apply_transformation(structure);
                if ~isempty(obj.charge_balance_species)
                    candidate=kssolv.analysis.matgenlab.transformations. ...
                        ChargeBalanceTransformation( ...
                        obj.charge_balance_species). ...
                        apply_transformation(candidate);
                end
                if obj.order
                    candidate=kssolv.analysis.matgenlab.transformations. ...
                        OrderDisorderedStructureTransformation(). ...
                        apply_transformation(candidate);
                end
                elements=reshape(string(entries{group,2}),1,[]);
                for element=elements
                    replacement=kssolv.analysis.matgenlab.core.Species( ...
                        element,charge);
                    transformed=kssolv.analysis.matgenlab.transformations. ...
                        SubstitutionTransformation({dummy,replacement}). ...
                        apply_transformation(candidate);
                    result{end+1}=struct("structure",transformed); %#ok<AGROW>
                end
            end
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                MultipleSubstitutionTransformation(value.sp_to_replace, ...
                value.r_fraction,value.substitution_dict, ...
                value.charge_balance_species,value.order);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                MultipleSubstitutionTransformation.from_dict(value);end
    end
end
