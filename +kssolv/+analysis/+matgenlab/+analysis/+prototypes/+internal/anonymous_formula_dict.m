function value=anonymous_formula_dict(formula)
%ANONYMOUS_FORMULA_DICT Parse one-letter AFLOW anonymous elements.
tokens=regexp(char(string(formula)),"([A-Za-z])([0-9]*)","tokens");
value=struct();
for index=1:numel(tokens)
    letter=tokens{index}{1};amount=str2double(tokens{index}{2});
    if isnan(amount),amount=1;end
    if isfield(value,letter),value.(letter)=value.(letter)+amount;
    else,value.(letter)=amount;end
end
end
