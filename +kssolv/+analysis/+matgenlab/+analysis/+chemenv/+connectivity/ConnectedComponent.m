%#ok<*PROP>
classdef ConnectedComponent < handle
    %CONNECTEDCOMPONENT Connected periodic environment multigraph.
    properties (Access=private)
        connected_subgraph
        periodicity_vectors_value=[]
        periodicity_computed (1,1) logical=false
    end
    properties (Dependent)
        graph
        is_periodic
        is_0d
        is_1d
        is_2d
        is_3d
        periodicity_vectors
        periodicity
        elastic_centered_graph
    end
    methods
        function obj=ConnectedComponent(varargin)
            opts=parseNamed(struct(environments=[],links=[], ...
                environments_data=[],links_data=[],graph=[]),varargin{:});
            if ~isempty(opts.graph),obj.connected_subgraph=opts.graph;
            else
                obj.connected_subgraph=struct(nodes={opts.environments}, ...
                    edges=linksToEdges(opts.links,opts.links_data));
            end
        end
        function value=get.graph(obj),value=obj.connected_subgraph;end
        function value=get.is_periodic(obj),value=obj.periodicity>0;end
        function value=get.is_0d(obj),value=obj.periodicity==0;end
        function value=get.is_1d(obj),value=obj.periodicity==1;end
        function value=get.is_2d(obj),value=obj.periodicity==2;end
        function value=get.is_3d(obj),value=obj.periodicity==3;end
        function value=get.periodicity_vectors(obj)
            if ~obj.periodicity_computed,obj.compute_periodicity();end
            value=obj.periodicity_vectors_value;
        end
        function value=get.periodicity(obj)
            value=size(obj.periodicity_vectors,1);
        end
        function value=get.elastic_centered_graph(obj)
            value=obj.connected_subgraph;
            positions=obj.unwrappedPositions();
            value.positions=positions-mean(positions,1);
        end
        function value=coordination_sequence(obj,sourceNode,varargin)
            opts=parseNamed(struct(path_size=5,coordination="number", ...
                include_source=false),varargin{:});
            source=findNode(obj.connected_subgraph.nodes,sourceNode);
            frontier={[source,0,0,0]};seen=stateKey(frontier{1});
            seenMap=containers.Map(char(seen),true);
            value=cell(1,opts.path_size+1);
            if opts.include_source,value{1}=layerValue(obj,frontier, ...
                    opts.coordination);end
            for depth=1:opts.path_size
                next={};
                for ii=1:numel(frontier)
                    state=frontier{ii};node=state(1);image=state(2:4);
                    edges=incident(obj.connected_subgraph.edges,node);
                    for edge=edges
                        [other,delta]=traverse(obj.connected_subgraph, ...
                            edge,node);
                        deltas=delta;
                        if edge.u==edge.v&&any(delta~=0)
                            deltas=[delta;-delta];
                        end
                        for idelta=1:size(deltas,1)
                            candidate=[other,image+deltas(idelta,:)];
                            key=char(stateKey(candidate));
                            if ~isKey(seenMap,key)
                                seenMap(key)=true;
                                next{end+1}=candidate; %#ok<AGROW>
                            end
                        end
                    end
                end
                value{depth+1}=layerValue(obj,next,opts.coordination);
                frontier=next;
            end
            if ~opts.include_source,value=value(2:end);end
        end
        function value=compute_periodicity(obj,varargin)
            value=obj.compute_periodicity_cycle_basis();
        end
        function value=compute_periodicity_all_simple_paths_algorithm(obj)
            value=obj.compute_periodicity_cycle_basis();
        end
        function value=compute_periodicity_cycle_basis(obj)
            graph=obj.connected_subgraph;n=numel(graph.nodes);
            assigned=false(1,n);positions=zeros(n,3);cycles=zeros(0,3);
            for source=1:n
                if assigned(source),continue,end
                assigned(source)=true;queue=source;
                while ~isempty(queue)
                    node=queue(1);queue(1)=[];
                    edges=incident(graph.edges,node);
                    for edge=edges
                        [other,delta]=traverse(graph,edge,node);
                        candidate=positions(node,:)+delta;
                        if ~assigned(other)
                            assigned(other)=true;positions(other,:)=candidate;
                            queue(end+1)=other; %#ok<AGROW>
                        else
                            residual=candidate-positions(other,:);
                            if any(residual~=0)
                                cycles(end+1,:)=residual; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
            obj.periodicity_vectors_value=independentIntegerRows(cycles);
            obj.periodicity_computed=true;
            value=obj.periodicity_vectors_value;
        end
        function value=make_supergraph(obj,multiplicity)
            value=kssolv.analysis.matgenlab.analysis.chemenv. ...
                connectivity.make_supergraph(obj.connected_subgraph, ...
                multiplicity,obj.periodicity_vectors);
        end
        function [fig,ax]=show_graph(obj,varargin)
            fig=figure("Visible","off");ax=axes(fig);
            n=numel(obj.connected_subgraph.nodes);
            theta=linspace(0,2*pi,n+1).';
            pos=[cos(theta(1:n)),sin(theta(1:n))];
            kssolv.analysis.matgenlab.analysis.chemenv.connectivity. ...
                draw_network(obj.connected_subgraph,pos,ax, ...
                "periodicity_vectors",obj.periodicity_vectors);
        end
        function value=as_dict(obj)
            nodes=cellfun(@(x)x.as_dict(),obj.connected_subgraph.nodes, ...
                "UniformOutput",false);
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "connectivity.connected_components", ...
                x_class="ConnectedComponent",nodes={nodes}, ...
                edges=obj.connected_subgraph.edges, ...
                periodicity_vectors=obj.periodicity_vectors);
        end
        function value=description(obj,varargin)
            opts=parseNamed(struct(full=false),varargin{:});
            symbols=cellfun(@(x)string(x.ce_symbol), ...
                obj.connected_subgraph.nodes);
            value=sprintf("%dD connected component with %d nodes (%s)", ...
                obj.periodicity,numel(symbols), ...
                strjoin(unique(symbols),", "));
            if opts.full
                value=value+sprintf(" and %d links", ...
                    numel(obj.connected_subgraph.edges));
            end
            value=char(value);
        end
    end
    methods (Static)
        function obj=from_graph(graph)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                connectivity.ConnectedComponent("graph",graph);
        end
        function obj=from_dict(value)
            nodes=cellfun(@decodeNode,toCell(value.nodes), ...
                "UniformOutput",false);
            graph=struct(nodes={nodes},edges=value.edges);
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                connectivity.ConnectedComponent.from_graph(graph);
            if isfield(value,"periodicity_vectors")
                obj.periodicity_vectors_value=value.periodicity_vectors;
                obj.periodicity_computed=true;
            end
        end
    end
    methods (Access=private)
        function value=unwrappedPositions(obj)
            graph=obj.connected_subgraph;n=numel(graph.nodes);
            value=zeros(n,3);seen=false(1,n);
            if n==0,return,end
            seen(1)=true;queue=1;
            while ~isempty(queue)
                node=queue(1);queue(1)=[];
                for edge=incident(graph.edges,node)
                    [other,delta]=traverse(graph,edge,node);
                    if ~seen(other)
                        seen(other)=true;value(other,:)=value(node,:)+delta;
                        queue(end+1)=other; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
function value=layerValue(obj,states,type)
if string(type)=="number",value=numel(states);return,end
value=containers.Map("KeyType","char","ValueType","double");
for ii=1:numel(states)
    symbol=char(obj.connected_subgraph.nodes{states{ii}(1)}.ce_symbol);
    if isKey(value,symbol),value(symbol)=value(symbol)+1;
    else,value(symbol)=1;end
end
end
function value=findNode(nodes,input)
if isnumeric(input),value=double(input);return,end
value=find(cellfun(@(x)x.isite==input.isite,nodes),1);
if isempty(value),error("KSSOLV:Matgenlab:ChemEnv:Node","Node not found.");end
end
function value=stateKey(state)
value=sprintf("%d,%d,%d,%d",state);
end
function value=incident(edges,node)
if isempty(edges),value=edges;return,end
value=edges([edges.u]==node|[edges.v]==node);
end
function [other,delta]=traverse(graph,edge,node)
if edge.u==node,other=edge.v;else,other=edge.u;end
site=graph.nodes{node}.isite;
if edge.start==site,delta=edge.delta;else,delta=-edge.delta;end
end
function value=independentIntegerRows(rows)
value=zeros(0,3);
for ii=1:size(rows,1)
    candidate=rows(ii,:);
    if all(candidate==0),continue,end
    if rank([value;candidate],1e-10)>size(value,1)
        first=find(candidate~=0,1);
        if candidate(first)<0,candidate=-candidate;end
        value(end+1,:)=candidate; %#ok<AGROW>
    end
    if size(value,1)==3,break,end
end
end
function value=linksToEdges(links,linksData) %#ok<INUSD>
value=struct("u",{},"v",{},"start",{},"end",{}, ...
    "delta",{},"ligands",{});
if isempty(links),return,end
for ii=1:size(links,1)
    value(end+1)=struct("u",links(ii,1),"v",links(ii,2), ...
        "start",links(ii,1),"end",links(ii,2), ...
        "delta",[0 0 0],"ligands",{{}}); %#ok<AGROW>
end
end
function value=decodeNode(data)
site=kssolv.analysis.matgenlab.core.PeriodicSite.from_dict( ...
    data.central_site);
value=kssolv.analysis.matgenlab.analysis.chemenv.connectivity. ...
    EnvironmentNode(site,double(data.i_central_site)+1,data.ce_symbol);
end
function value=toCell(input)
if iscell(input),value=input(:).';else,value=num2cell(input(:)).';end
end
function opts=parseNamed(opts,varargin)
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
