function facets=get_facets(qhull_data,joggle)
%GET_FACETS Return convex-hull simplex facets using MATLAB Qhull.
if nargin<2,joggle=false;end
data=double(qhull_data);
if size(data,1)<=size(data,2)
    facets=1:size(data,1);
    return
end
options={};
if joggle,options={'QJ'};end
try
    if isempty(options),facets=convhulln(data);
    else,facets=convhulln(data,options);end
catch
    facets=convhulln(data,{'QJ'});
end
end
