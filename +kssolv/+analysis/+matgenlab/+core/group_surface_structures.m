function groups=group_surface_structures(structures,tolerance)
%GROUP_SURFACE_STRUCTURES Group slab terminations by rigid invariants.
if nargin<2||isempty(tolerance),tolerance=1e-6;end
if ~iscell(structures),structures=num2cell(structures);end
groups=cell(1,0);
keys=containers.Map("KeyType","char","ValueType","double");
digits=max(6,ceil(-log10(max(tolerance,eps)))+2);
for index=1:numel(structures)
    key=surfaceInvariant(structures{index},digits);
    if isKey(keys,key)
        group=keys(key);
        groups{group}{end+1}=structures{index};
    else
        group=numel(groups)+1;
        keys(key)=group;
        groups{group}=structures(index);
    end
end
end

function key=surfaceInvariant(structure,digits)
parameters=round(structure.lattice.parameters,digits);
header=sprintf("%s|%d|%.*g,",char(structure.formula), ...
    structure.num_sites,digits,parameters);
pairs=strings(1,structure.num_sites*(structure.num_sites-1)/2);
next=0;
for first=1:structure.num_sites-1
    for second=first+1:structure.num_sites
        next=next+1;
        labels=sort([string(structure.sites{first}.species_string), ...
            string(structure.sites{second}.species_string)]);
        distance=structure.sites{first}.distance( ...
            structure.sites{second});
        pairs(next)=sprintf("%s>%s:%.*g",labels(1),labels(2), ...
            digits,distance);
    end
end
pairs=sort(pairs);
key=reshape(char(string(header)+join(pairs,";")),1,[]);
end
