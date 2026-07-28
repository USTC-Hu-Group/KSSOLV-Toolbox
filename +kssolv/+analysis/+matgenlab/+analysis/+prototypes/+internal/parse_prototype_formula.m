function parsed=parse_prototype_formula(formula)
%PARSE_PROTOTYPE_FORMULA Split AFLOW anonymous formula into letters/counts.
tokens=regexp(char(string(formula)),'([A-Z])([0-9]*)','tokens');
letters=strings(1,numel(tokens));counts=zeros(1,numel(tokens));
for index=1:numel(tokens)
    letters(index)=string(tokens{index}{1});
    suffix=string(tokens{index}{2});
    if strlength(suffix)==0
        counts(index)=1;
    else
        counts(index)=str2double(suffix);
    end
end
if join(letters+compose("%g",counts),"")==""
    error("KSSOLV:Matgenlab:Prototypes:Formula", ...
        "Prototype formula must contain uppercase element placeholders.");
end
parsed=struct("alpha",letters,"counts",counts);
end
