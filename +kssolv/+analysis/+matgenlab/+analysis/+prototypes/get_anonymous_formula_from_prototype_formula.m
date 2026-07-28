function value=get_anonymous_formula_from_prototype_formula(prototype_formula)
%GET_ANONYMOUS_FORMULA_FROM_PROTOTYPE_FORMULA Sort stoichiometric amounts.
parsed=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    parse_prototype_formula(prototype_formula);
amounts=sort(parsed.counts);
tokens=strings(1,numel(parsed.alpha));
for index=1:numel(tokens)
    if amounts(index)==1,tokens(index)=parsed.alpha(index);
    else,tokens(index)=parsed.alpha(index)+string(amounts(index));end
end
value=join(tokens,"");
end
