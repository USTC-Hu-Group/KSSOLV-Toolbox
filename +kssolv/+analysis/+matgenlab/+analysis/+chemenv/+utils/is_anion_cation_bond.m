function value=is_anion_cation_bond(valences,index1,index2)
%IS_ANION_CATION_BOND Whether two sites have strictly opposite valence signs.
%#ok<*ALIGN>
if ischar(valences)||isstring(valences)||isempty(valences)||any(isnan(valences))
    value=true;
elseif valences(index1)==0||valences(index2)==0,value=true;
else,value=valences(index1)*valences(index2)<0;end
end
