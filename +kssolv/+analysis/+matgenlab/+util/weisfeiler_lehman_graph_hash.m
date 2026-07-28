function hash=weisfeiler_lehman_graph_hash(graph,varargin)
%WEISFEILER_LEHMAN_GRAPH_HASH Weisfeiler-Lehman graph hash.
options=struct(edge_attr=[],node_attr=[],iterations=3,digest_size=16);
options=parse(options,varargin);
sub=kssolv.analysis.matgenlab.util.weisfeiler_lehman_subgraph_hashes( ...
    graph,"edge_attr",options.edge_attr,"node_attr",options.node_attr, ...
    "iterations",options.iterations,"digest_size",options.digest_size);
counts=strings(0,2);
for iteration=1:options.iterations
    labels=strings(1,numel(keys(sub)));
    for node=1:numel(labels),values=sub(node);labels(node)=values(iteration);end
    uniqueLabels=unique(labels);
    for ii=1:numel(uniqueLabels)
        counts(end+1,:)=[uniqueLabels(ii),string(sum(labels==uniqueLabels(ii)))]; %#ok<AGROW>
    end
end
% Python's reference implementation hashes repr(tuple(sorted Counter items)).
pieces=strings(1,size(counts,1));
for ii=1:size(counts,1)
    pieces(ii)="('"+counts(ii,1)+"', "+counts(ii,2)+")";
end
representation="("+join(pieces,", ");
if isscalar(pieces),representation=representation+",";end
representation=representation+")";
hash=kssolv.analysis.matgenlab.util.blake2b_hex(representation,options.digest_size);
end
function output=parse(output,input)
names=fieldnames(output);ii=1;pos=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii})) && ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};
        ii=ii+2;
    else
        output.(names{pos})=input{ii};
        pos=pos+1;
        ii=ii+1;
    end
end
end
