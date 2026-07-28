classdef Reaction < kssolv.analysis.matgenlab.analysis.BalancedReaction
    %REACTION Automatically balanced chemical reaction.

    properties (Access = protected)
        input_reactants cell
        input_products cell
    end

    methods
        function obj = Reaction(reactants,products)
            obj@kssolv.analysis.matgenlab.analysis.BalancedReaction();
            obj.input_reactants=cellfun(@(value) ...
                kssolv.analysis.matgenlab.core.Composition(value), ...
                reshape(reactants,1,[]),UniformOutput=false);
            obj.input_products=cellfun(@(value) ...
                kssolv.analysis.matgenlab.core.Composition(value), ...
                reshape(products,1,[]),UniformOutput=false);
            obj.all_comp_=[obj.input_reactants,obj.input_products];
            elementNames=strings(1,0); elements={};
            for composition=obj.all_comp_
                for element=composition{1}.elements
                    name=string(element{1});
                    if ~any(elementNames==name)
                        elementNames(end+1)=name; %#ok<AGROW>
                        elements{end+1}=element{1}; %#ok<AGROW>
                    end
                end
            end
            [~,order]=sort(elementNames);
            obj.elements_=elements(order);
            matrix=zeros(numel(elements),numel(obj.all_comp_));
            for row=1:numel(obj.elements_)
                for column=1:numel(obj.all_comp_)
                    matrix(row,column)= ...
                        obj.all_comp_{column}(obj.elements_{row});
                end
            end
            rankValue=rank(matrix);
            difference=numel(obj.all_comp_)-rankValue;
            maximumConstraints=max(1,difference);
            obj.coeffs_=obj.balance(matrix,maximumConstraints, ...
                numel(obj.input_reactants));
        end

        function value=copy(obj)
            value=kssolv.analysis.matgenlab.analysis.Reaction( ...
                obj.input_reactants,obj.input_products);
        end

        function value=as_dict(obj)
            reactants=cellfun(@(item)item.as_dict(), ...
                obj.input_reactants,UniformOutput=false);
            products=cellfun(@(item)item.as_dict(), ...
                obj.input_products,UniformOutput=false);
            value=struct( ...
                "x_module","pymatgen.analysis.reaction_calculator", ...
                "x_class","Reaction","reactants",{reactants}, ...
                "products",{products});
        end
    end

    methods (Static)
        function obj=from_dict(value)
            reactants=cellfun(@(item) ...
                kssolv.analysis.matgenlab.core.Composition.from_dict(item), ...
                value.reactants,UniformOutput=false);
            products=cellfun(@(item) ...
                kssolv.analysis.matgenlab.core.Composition.from_dict(item), ...
                value.products,UniformOutput=false);
            obj=kssolv.analysis.matgenlab.analysis.Reaction(reactants,products);
        end
    end

    methods (Access=private)
        function coefficients=balance(obj,matrix,maxConstraints,firstProduct)
            best=[]; lowest=inf; balanced=false;
            productIndices=firstProduct+1:size(matrix,2);
            reactantIndices=1:firstProduct;
            lists={productIndices,reactantIndices};
            signs=[1,-1];
            for side=1:2
                indices=lists{side};
                for count=maxConstraints:-1:1
                    if count>numel(indices),continue,end
                    combinations=nchoosek(indices,count);
                    for row=1:size(combinations,1)
                        constraints=combinations(row,:);
                        augmented=[matrix;zeros(count,size(matrix,2))];
                        target=zeros(size(matrix,1)+count,1);
                        target(end-count+1:end)=signs(side);
                        for index=1:count
                            augmented(size(matrix,1)+index, ...
                                constraints(index))=1;
                        end
                        solution=pinv(augmented)*target;
                        if norm(matrix*solution)>1e-7,continue,end
                        balanced=true;
                        expected=[-ones(1,firstProduct), ...
                            ones(1,size(matrix,2)-firstProduct)];
                        errors=sum(expected.*solution.'<obj.TOLERANCE);
                        if errors==0
                            coefficients=solution.'; return
                        elseif errors<lowest
                            lowest=errors; best=solution.';
                        end
                    end
                end
            end
            if ~balanced
                throw(kssolv.analysis.matgenlab.analysis.ReactionError( ...
                    "Reaction cannot be balanced."));
            end
            coefficients=best;
        end
    end
end
