function neighbors=get_neighbors_of_site_with_index(structure,n,varargin)
%#ok<*ALIGN>
%GET_NEIGHBORS_OF_SITE_WITH_INDEX Select neighbors with a named strategy.
options=struct(approach="min_dist",delta=.1,cutoff=10);
options=parse(options,varargin);
switch string(options.approach)
    case "min_dist"
        finder=kssolv.analysis.matgenlab.core.MinimumDistanceNN( ...
            options.delta,options.cutoff);
    case "voronoi"
        finder=kssolv.analysis.matgenlab.core.VoronoiNN( ...
            "tol",options.delta,"cutoff",options.cutoff);
    case "min_OKeeffe"
        finder=kssolv.analysis.matgenlab.core.MinimumOKeeffeNN( ...
            options.delta,options.cutoff);
    case "min_VIRE"
        finder=kssolv.analysis.matgenlab.core.MinimumVIRENN( ...
            options.delta,options.cutoff);
    otherwise
        error("KSSOLV:Matgenlab:LocalEnv:NeighborApproach", ...
            "Unsupported neighbor-finding method (%s).",options.approach);
end
neighbors=finder.get_nn(structure,n);
end
function output=parse(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else,output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;end
end
end
