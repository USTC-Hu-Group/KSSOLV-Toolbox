function value=get_formula_from_protostructure_label(label)
%GET_FORMULA_FROM_PROTOSTRUCTURE_LABEL Restore a chemical formula.
sections=split(string(label),":");
if numel(sections)~=2
    error("KSSOLV:Matgenlab:Prototypes:Label", ...
        "Protostructure labels must contain one ':'.");
end
prototype=split(sections(1),"_");formula=prototype(1);
parsed=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    parse_prototype_formula(formula);
elements=split(sections(2),"-");
if numel(elements)~=numel(parsed.counts)
    error("KSSOLV:Matgenlab:Prototypes:Formula", ...
        "Prototype formula and chemical system have different sizes.");
end
tokens=strings(1,numel(elements));
for index=1:numel(elements)
    if parsed.counts(index)==1,tokens(index)=elements(index);
    else,tokens(index)=elements(index)+string(parsed.counts(index));end
end
value=join(tokens,"");
end
