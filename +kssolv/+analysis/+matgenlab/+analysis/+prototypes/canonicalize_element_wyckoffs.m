function value=canonicalize_element_wyckoffs(element_wyckoffs,spg_num)
%CANONICALIZE_ELEMENT_WYCKOFFS Select the canonical isopointal relabeling.
data=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    load_data("relabelings");
mappings=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
    map_get(data,string(spg_num),[]);
if isempty(mappings)
    error("KSSOLV:Matgenlab:Prototypes:SpaceGroup", ...
        "No Wyckoff relabeling data for space group %s.",string(spg_num));
end
if isstruct(mappings),mappings=num2cell(mappings);end
candidates=strings(1,numel(mappings));scores=zeros(1,numel(mappings));
for index=1:numel(mappings)
    translated=kssolv.analysis.matgenlab.analysis.prototypes.internal. ...
        translate_wyckoffs(element_wyckoffs,mappings{index});
    [candidates(index),scores(index)]= ...
        kssolv.analysis.matgenlab.analysis.prototypes. ...
        sort_and_score_element_wyckoffs(translated);
end
[~,order]=sortrows(table(scores(:),candidates(:)),[1,2]);
value=candidates(order(1));
end
