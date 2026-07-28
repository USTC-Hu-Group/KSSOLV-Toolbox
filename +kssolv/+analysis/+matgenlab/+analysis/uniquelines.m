function lines=uniquelines(facets)
%#ok<*ISCL>
%UNIQUELINES Convert simplex facets into sorted unique edge pairs.
if isnumeric(facets),facets=num2cell(facets,2);end
lines=zeros(0,2);
for ii=1:numel(facets)
    facet=facets{ii};
    if numel(facet)==1,pairs=[facet,facet];
    else,pairs=nchoosek(facet,2);end
    lines=[lines;sort(pairs,2)]; %#ok<AGROW>
end
lines=unique(lines,"rows");
end
