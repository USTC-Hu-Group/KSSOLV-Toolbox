function value=get_prototype_formula_from_composition(composition)
%GET_PROTOTYPE_FORMULA_FROM_COMPOSITION AFLOW formula in element order.
if ~isa(composition,"kssolv.analysis.matgenlab.core.Composition")
    composition=kssolv.analysis.matgenlab.core.Composition(composition);
end
symbols=composition.chemical_system_set;
ordered=zeros(1,numel(symbols));
for index=1:numel(symbols),ordered(index)=composition.amountOf(symbols(index));end
if all(abs(ordered-round(ordered))<1e-10)
    divisor=abs(round(ordered(1)));
    for index=2:numel(ordered),divisor=gcd(divisor,abs(round(ordered(index))));end
    if divisor>1,ordered=ordered/divisor;end
end
tokens=strings(1,numel(ordered));
for index=1:numel(ordered)
    letter=string(char(double('A')+index-1));
    if abs(ordered(index)-1)<1e-10
        tokens(index)=letter;
    elseif abs(ordered(index)-round(ordered(index)))<1e-8
        tokens(index)=letter+string(round(ordered(index)));
    else
        tokens(index)=letter+string(ordered(index));
    end
end
value=join(tokens,"");
end
