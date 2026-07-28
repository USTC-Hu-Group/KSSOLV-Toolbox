function count=count_layers(structure,element)
%COUNT_LAYERS Count distinct periodic atomic planes along c.
if nargin<2||isempty(element)
    element=structure(1).species_string;
end
symbols=strings(1,structure.num_sites);
for index=1:structure.num_sites
    symbols(index)=structure(index).species_string;
end
coordinates=structure.frac_coords(symbols==string(element),3);
if isempty(coordinates),count=0;return,end
if isscalar(coordinates),count=1;return,end
height=structure.lattice.lengths(3);
coordinates=sort(mod(coordinates,1));
groups=coordinates(1);
for index=2:numel(coordinates)
    if (coordinates(index)-groups(end))*height>.25
        groups(end+1)=coordinates(index); %#ok<AGROW>
    end
end
if numel(groups)>1&&(groups(1)+1-groups(end))*height<=.25
    groups(end)=[];
end
count=numel(groups);
end
