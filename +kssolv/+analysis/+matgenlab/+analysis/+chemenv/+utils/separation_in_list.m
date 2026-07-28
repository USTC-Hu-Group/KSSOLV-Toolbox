function value=separation_in_list(separation,list)
%SEPARATION_IN_LIST Test whether a canonical in-plane group is represented.
sorted=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
    sort_separation(separation);
value=false;
for index=1:numel(list)
    candidate=list{index};
    if numel(candidate{2})==numel(sorted{2})&& ...
            all(candidate{2}==sorted{2})
        value=true;return
    end
end
end
