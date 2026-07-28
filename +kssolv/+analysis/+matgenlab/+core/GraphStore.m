classdef GraphStore < handle
    %GRAPHSTORE Lightweight attributed undirected multigraph backend.
    properties
        nodes cell = {}
        edges struct = struct("from_index",{},"to_index",{}, ...
            "from_jimage",{},"to_jimage",{},"weight",{}, ...
            "edge_properties",{})
        attributes (1,1) struct = struct(name="bonds", ...
            edge_weight_name=[],edge_weight_units=[])
    end
    methods
        function obj=GraphStore(nodeCount,attributes)
            if nargin<1,nodeCount=0;end
            if nargin>=2,obj.attributes=attributes;end
            obj.nodes=repmat({struct()},1,nodeCount);
        end
        function count=number_of_nodes(obj),count=numel(obj.nodes);end
        function count=number_of_edges(obj),count=numel(obj.edges);end
        function data=get_edge_data(obj,first,second)
            data={};
            for ii=1:numel(obj.edges)
                edge=obj.edges(ii);
                if edge.from_index==first&&edge.to_index==second
                    data{end+1}=edgeData(edge); %#ok<AGROW>
                end
            end
            if isempty(data),data=[];end
        end
        function obj=add_edge(obj,first,second,varargin)
            options=struct(from_jimage=[0,0,0],to_jimage=[0,0,0], ...
                weight=[],edge_properties=struct());
            options=parseOptions(options,varargin);
            edge=struct(from_index=first,to_index=second, ...
                from_jimage=reshape(options.from_jimage,1,3), ...
                to_jimage=reshape(options.to_jimage,1,3), ...
                weight=options.weight,edge_properties=options.edge_properties);
            obj.edges(end+1)=edge;
        end
        function obj=remove_edge(obj,index)
            obj.edges(index)=[];
        end
        function value=copy(obj)
            value=kssolv.analysis.matgenlab.core.GraphStore(0,obj.attributes);
            value.nodes=obj.nodes;value.edges=obj.edges;
        end
        function matrix=adjacency(obj)
            matrix=zeros(obj.number_of_nodes());
            for edge=obj.edges
                matrix(edge.from_index,edge.to_index)= ...
                    matrix(edge.from_index,edge.to_index)+1;
                if edge.from_index~=edge.to_index
                    matrix(edge.to_index,edge.from_index)= ...
                        matrix(edge.to_index,edge.from_index)+1;
                else
                    matrix(edge.from_index,edge.to_index)= ...
                        matrix(edge.from_index,edge.to_index)+1;
                end
            end
        end
        function value=as_struct(obj)
            value=struct(attributes=obj.attributes,nodes={obj.nodes}, ...
                edges=obj.edges);
        end
    end
end
function data=edgeData(edge)
data=edge.edge_properties;
data.from_jimage=edge.from_jimage;data.to_jimage=edge.to_jimage;
if ~isempty(edge.weight),data.weight=edge.weight;end
end
function output=parseOptions(output,input)
names=fieldnames(output);ii=1;
while ii<=numel(input)
    key=names{strcmpi(string(input{ii}),string(names))};
    output.(key)=input{ii+1};ii=ii+2;
end
end
