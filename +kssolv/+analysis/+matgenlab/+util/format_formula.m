function formatted=format_formula(formula)
%FORMAT_FORMULA Convert formula digits into TeX subscripts.
formula=char(string(formula));output='';digits='';
for index=1:numel(formula)
    character=formula(index);
    if isstrprop(character,"digit")
        digits=[digits,character]; %#ok<AGROW>
    else
        if ~isempty(digits)
            output=[output,'_{',digits,'}']; %#ok<AGROW>
            digits='';
        end
        output=[output,character]; %#ok<AGROW>
    end
end
if ~isempty(digits),output=[output,'_{',digits,'}'];end
formatted="$"+string(output)+"$";
end
