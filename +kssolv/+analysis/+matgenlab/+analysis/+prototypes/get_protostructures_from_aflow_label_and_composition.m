function values=get_protostructures_from_aflow_label_and_composition( ...
        aflow_label,composition)
%GET_PROTOSTRUCTURES_FROM_AFLOW_LABEL_AND_COMPOSITION Assign elements to sites.
if ~isa(composition,"kssolv.analysis.matgenlab.core.Composition")
    composition=kssolv.analysis.matgenlab.core.Composition(composition);
end
parts=split(string(aflow_label),"_");
if numel(parts)<4,error("KSSOLV:Matgenlab:Prototypes:Label", ...
        "Malformed AFLOW label.");end
anonymous=parts(1);pearson=parts(2);spg=parts(3);wyckoffs=parts(4:end);
elements=composition.chemical_system_set;
first=struct();
for index=1:numel(elements)
    first.(elements(index))=composition.amountOf(elements(index));
end
second=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    anonymous_formula_dict(anonymous);
translations=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    find_translations(first,second);
anonymousNames=fieldnames(second);siteByAnonymous=struct();
for index=1:numel(anonymousNames)
    siteByAnonymous.(anonymousNames{index})=wyckoffs(index);
end
formula=kssolv.analysis.matgenlab.analysis.prototypes. ...
    get_prototype_formula_from_composition(composition);
values=strings(1,0);
for translation=1:numel(translations)
    mapping=translations{translation};
    elementNames=sort(string(fieldnames(mapping)));
    sites=strings(1,numel(elementNames));
    for index=1:numel(elementNames)
        anonymousName=mapping.(elementNames(index));
        sites(index)=kssolv.analysis.matgenlab.analysis.prototypes. ...
            internal.prefix_wyckoff_counts( ...
            siteByAnonymous.(anonymousName));
    end
    canonical=kssolv.analysis.matgenlab.analysis.prototypes. ...
        canonicalize_element_wyckoffs(join(sites,"_"),spg);
    values(end+1)=formula+"_"+pearson+"_"+spg+"_"+canonical+":"+ ...
        join(elementNames,"-"); %#ok<AGROW>
end
values=unique(values,"stable");
end
