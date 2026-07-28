function value=get_prototype_from_protostructure(label)
%GET_PROTOTYPE_FROM_PROTOSTRUCTURE Canonical isopointal AFLOW label.
aflow=split(string(label),":");parts=split(aflow(1),"_");
if numel(parts)<4,error("KSSOLV:Matgenlab:Prototypes:Label", ...
        "Malformed protostructure label.");end
formula=parts(1);pearson=parts(2);spg=parts(3);wyckoffs=parts(4:end);
anonymous=kssolv.analysis.matgenlab.analysis.prototypes. ...
    get_anonymous_formula_from_prototype_formula(formula);
counts=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    anonymous_formula_dict(formula);
countNames=fieldnames(counts);amounts=cellfun(@(name)counts.(name),countNames);
[amounts,order]=sort(amounts);wyckoffs=wyckoffs(order);
normalized=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    prefix_wyckoff_counts(join(wyckoffs,"_"));
if numel(unique(amounts))==numel(amounts)
    canonical=kssolv.analysis.matgenlab.analysis.prototypes. ...
        canonicalize_element_wyckoffs(normalized,spg);
    value=anonymous+"_"+pearson+"_"+spg+"_"+canonical;return
end
groups=unique(amounts,"stable");choices=cell(1,numel(groups));
for groupIndex=1:numel(groups)
    indices=amounts==groups(groupIndex);
    choices{groupIndex}=localPermutations(wyckoffs(indices));
end
combinations={strings(1,0)};
for groupIndex=1:numel(choices)
    next={};
    for prior=1:numel(combinations)
        for choice=1:numel(choices{groupIndex})
            next{end+1}=[combinations{prior}, ...
                choices{groupIndex}{choice}]; %#ok<AGROW>
        end
    end
    combinations=next;
end
data=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    load_data("relabelings");
mappings=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    map_get(data,spg,[]);
if isstruct(mappings),mappings=num2cell(mappings);end
candidates=strings(1,0);scores=zeros(1,0);
for combo=1:numel(combinations)
    base=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
        prefix_wyckoff_counts(join(combinations{combo},"_"));
    for mapping=1:numel(mappings)
        translated=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
            translate_wyckoffs(base,mappings{mapping});
        [candidate,score]=kssolv.analysis.matgenlab.analysis.prototypes. ...
            sort_and_score_element_wyckoffs(translated);
        candidates(end+1)=candidate;scores(end+1)=score; %#ok<AGROW>
    end
end
[~,order]=sortrows(table(scores(:),candidates(:)),[1,2]);
value=anonymous+"_"+pearson+"_"+spg+"_"+candidates(order(1));
end

function values=localPermutations(input)
if numel(input)<=1,values={reshape(input,1,[])};return,end
indices=perms(1:numel(input));values=cell(1,size(indices,1));
for index=1:size(indices,1),values{index}=reshape(input(indices(index,:)),1,[]);end
end
