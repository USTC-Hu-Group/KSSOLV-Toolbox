function value=get_all_simple_paths_edges(input,source,target,varargin)
%GET_ALL_SIMPLE_PATHS_EDGES Enumerate edge-resolved simple paths.
cutoff=[];includeData=true;
if ~isempty(varargin)
    if ischar(varargin{1})||isstring(varargin{1})
        for index=1:2:numel(varargin)
            switch lower(string(varargin{index}))
                case "cutoff",cutoff=varargin{index+1};
                case "data",includeData=logical(varargin{index+1});
            end
        end
    else
        cutoff=varargin{1};
        if numel(varargin)>1,includeData=varargin{2};end
    end
end
[graph_,edgeRecords]=asGraph(input);
arguments_={};if ~isempty(cutoff),arguments_={"MaxPathLength",cutoff};end
nodePaths=allpaths(graph_,source,target,arguments_{:});
value={};
for pathIndex=1:numel(nodePaths)
    nodes=nodePaths{pathIndex};partial={{}};
    for position=1:numel(nodes)-1
        matches=findEdgeRecords(edgeRecords,nodes(position),nodes(position+1));
        expanded={};
        for candidate=1:numel(matches)
            record=edgeRecords(matches(candidate));
            for prefix=1:numel(partial)
                edge=struct(from=nodes(position),to=nodes(position+1), ...
                    key=matches(candidate));
                if includeData,edge.data=record.data;end
                expanded{end+1}=[partial{prefix},{edge}]; %#ok<AGROW>
            end
        end
        partial=expanded;
    end
    value=[value,partial]; %#ok<AGROW>
end
end
function [graph_,records]=asGraph(input)
if isa(input,"kssolv.analysis.matgenlab.core.GraphStore")
    records=repmat(struct(from=0,to=0,data=struct()),1,numel(input.edges));
    from=zeros(1,numel(records));to=from;
    for index=1:numel(records)
        edge=input.edges(index);from(index)=edge.from_index;to(index)=edge.to_index;
        records(index)=struct(from=from(index),to=to(index),data=edge.edge_properties);
    end
    graph_=graph(from,to,[],input.number_of_nodes());
elseif isa(input,"graph")
    endpoints=input.Edges.EndNodes;records=repmat( ...
        struct(from=0,to=0,data=struct()),1,size(endpoints,1));
    for index=1:numel(records)
        records(index)=struct(from=endpoints(index,1),to=endpoints(index,2), ...
            data=table2struct(input.Edges(index,:)));
    end
    graph_=input;
else
    error("KSSOLV:Matgenlab:ChemEnv:Graph","Unsupported graph type.");
end
end
function value=findEdgeRecords(records,first,second)
value=find(arrayfun(@(edge)(edge.from==first&&edge.to==second)|| ...
    (edge.from==second&&edge.to==first),records));
end
