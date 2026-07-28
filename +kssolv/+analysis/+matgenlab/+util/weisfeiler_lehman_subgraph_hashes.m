function hashes=weisfeiler_lehman_subgraph_hashes(graph,varargin)
%WEISFEILER_LEHMAN_SUBGRAPH_HASHES Per-node WL neighborhood hashes.
options=struct(edge_attr=[],node_attr=[],iterations=3,digest_size=16);
options=parse(options,varargin);
[adjacency,nodeAttributes,edgeAttributes]=normalizeGraph(graph);
n=size(adjacency,1);labels=strings(1,n);
for ii=1:n
    if ~isempty(options.node_attr)
        labels(ii)=attribute(nodeAttributes{ii},options.node_attr);
    elseif ~isempty(options.edge_attr)
        labels(ii)="";
    else
        labels(ii)=string(nnz(adjacency(ii,:)>0));
    end
end
hashes=containers.Map("KeyType","double","ValueType","any");
for ii=1:n,hashes(ii)=strings(1,options.iterations);end
for iteration=1:options.iterations
    updated=strings(1,n);
    for node=1:n
        neighbors=find(adjacency(node,:)>0);parts=strings(1,numel(neighbors));
        for jj=1:numel(neighbors)
            prefix="";
            if ~isempty(options.edge_attr)
                prefix=attribute(edgeAttributes{node,neighbors(jj)},options.edge_attr);
            end
            parts(jj)=prefix+labels(neighbors(jj));
        end
        aggregate=labels(node)+join(sort(parts),"");
        updated(node)=kssolv.analysis.matgenlab.util.blake2b_hex( ...
            aggregate,options.digest_size);
        existing=hashes(node);
        existing(iteration)=updated(node);
        hashes(node)=existing;
    end
    labels=updated;
end
end
function value=attribute(data,name)
if isstruct(data)&&isfield(data,char(string(name))),value=string(data.(char(string(name))));
else,value="";end
end
function [a,nodes,edges]=normalizeGraph(input)
if isa(input,"kssolv.analysis.matgenlab.core.StructureGraph")|| ...
        isa(input,"kssolv.analysis.matgenlab.core.MoleculeGraph")
    input=input.graph;
end
if isa(input,"kssolv.analysis.matgenlab.core.GraphStore")
    a=input.adjacency();nodes=input.nodes;edges=cell(size(a));
    for e=input.edges
        data=e.edge_properties;if ~isempty(e.weight),data.weight=e.weight;end
        edges{e.from_index,e.to_index}=data;edges{e.to_index,e.from_index}=data;
    end
elseif isa(input,"graph")||isa(input,"digraph")
    a=full(adjacency(input));nodes=repmat({struct()},1,numnodes(input));
    names=input.Nodes.Properties.VariableNames;
    for ii=1:numnodes(input)
        for jj=1:numel(names),nodes{ii}.(names{jj})=input.Nodes.(names{jj})(ii,:);end
    end
    edges=cell(size(a));edgeNames=input.Edges.Properties.VariableNames;
    ends=input.Edges.EndNodes;
    for ii=1:numedges(input)
        data=struct();
        for jj=1:numel(edgeNames)
            if ~strcmp(edgeNames{jj},"EndNodes")
                data.(edgeNames{jj})=input.Edges.(edgeNames{jj})(ii,:);
            end
        end
        edges{ends(ii,1),ends(ii,2)}=data;edges{ends(ii,2),ends(ii,1)}=data;
    end
elseif isnumeric(input)
    a=double(input);
    nodes=repmat({struct()},1,size(a,1));
    edges=cell(size(a));
else
    error("KSSOLV:Matgenlab:GraphHash:GraphType", ...
        "Unsupported graph representation.");
end
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
