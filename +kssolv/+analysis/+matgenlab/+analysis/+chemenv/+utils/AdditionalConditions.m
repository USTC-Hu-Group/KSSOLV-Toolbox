classdef AdditionalConditions
    %ADDITIONALCONDITIONS Bond filters used by ChemEnv neighbor sets.
    %#ok<*MSNU>
    properties (Constant)
        NO_ADDITIONAL_CONDITION=0
        ONLY_ANION_CATION_BONDS=1
        NO_ELEMENT_TO_SAME_ELEMENT_BONDS=2
        ONLY_ANION_CATION_BONDS_AND_NO_ELEMENT_TO_SAME_ELEMENT_BONDS=3
        ONLY_ELEMENT_TO_OXYGEN_BONDS=4
        NONE=0
        NO_AC=0
        ONLY_ACB=1
        NO_E2SEB=2
        ONLY_ACB_AND_NO_E2SEB=3
        ONLY_E2OB=4
        ALL=[0,1,2,3,4]
        CONDITION_DESCRIPTION=["No additional condition", ...
            "Only anion-cation bonds", ...
            "No element-element bonds (same elements)", ...
            "Only anion-cation bonds and no element-element bonds (same elements)", ...
            "Only element-oxygen bonds"]
    end
    methods
        function value=check_condition(obj,condition,structure,parameters) %#ok<INUSL>
            if condition==obj.NONE,value=true;return,end
            index1=fieldValue(parameters,"site_index");
            index2=fieldValue(parameters,"neighbor_index");
            first=siteSymbols(structure(index1));
            second=siteSymbols(structure(index2));
            unlike=isempty(intersect(first,second));
            switch condition
                case obj.ONLY_ACB
                    value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                        is_anion_cation_bond(fieldValue(parameters,"valences"), ...
                        index1,index2);
                case obj.NO_E2SEB,value=unlike;
                case obj.ONLY_ACB_AND_NO_E2SEB
                    value=unlike&&kssolv.analysis.matgenlab.analysis.chemenv. ...
                        utils.is_anion_cation_bond( ...
                        fieldValue(parameters,"valences"),index1,index2);
                case obj.ONLY_E2OB
                    value=(any(first=="O")&&~any(second=="O"))|| ...
                        (any(second=="O")&&~any(first=="O"));
                otherwise,value=[];
            end
        end
    end
end
function value=fieldValue(input,name)
if isa(input,"containers.Map"),value=input(char(name));
else,value=input.(char(name));end
end
function value=siteSymbols(site)
value=string(cellfun(@(element)element.symbol,site.species.elements));
end
