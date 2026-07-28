function groups=entry_dict_from_list(allSlabEntries)
%ENTRY_DICT_FROM_LIST Group SlabEntry objects by facet and clean parent.
if isempty(allSlabEntries)
    groups=struct("hkl",{},"clean",{},"ads",{});return
end
if ~iscell(allSlabEntries),allSlabEntries=num2cell(allSlabEntries);end
groups=struct("hkl",{},"clean",{},"ads",{});
for index=1:numel(allSlabEntries)
    entry=allSlabEntries{index};hkl=entry.miller_index;
    groupIndex=find(arrayfun(@(x)isequal(x.hkl,hkl),groups),1);
    if isempty(groupIndex)
        groupIndex=numel(groups)+1;groups(groupIndex).hkl=hkl;
        groups(groupIndex).clean={};groups(groupIndex).ads={};
    end
    if isempty(entry.clean_entry)
        groups(groupIndex).clean{end+1}=entry;
        groups(groupIndex).ads{end+1}={};
    else
        cleanIndex=find(cellfun(@(x)sameEntry(x,entry.clean_entry), ...
            groups(groupIndex).clean),1);
        if isempty(cleanIndex)
            groups(groupIndex).clean{end+1}=entry.clean_entry;
            groups(groupIndex).ads{end+1}={entry};
        else
            groups(groupIndex).ads{cleanIndex}{end+1}=entry;
        end
    end
end
end
function tf=sameEntry(first,second)
tf=first==second&&isequal(first.miller_index,second.miller_index);
end
