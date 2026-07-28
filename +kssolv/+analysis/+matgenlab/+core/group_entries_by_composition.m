function groups=group_entries_by_composition(entries,sort_by_e_per_atom)
%GROUP_ENTRIES_BY_COMPOSITION Group entries by reduced formula.
if nargin<2,sort_by_e_per_atom=true;end
if ~iscell(entries),entries=num2cell(entries);end
formulas=cellfun(@(item)string(item.reduced_formula),entries);
[~,order]=sort(formulas); entries=entries(order); formulas=formulas(order);
groups=cell(1,0);
for formula=unique(formulas,"stable")
    group=entries(formulas==formula);
    if sort_by_e_per_atom
        energies=cellfun(@(item)item.energy_per_atom,group);
        [~,energyOrder]=sort(energies);group=group(energyOrder);
    end
    groups{end+1}=group; %#ok<AGROW>
end
end
