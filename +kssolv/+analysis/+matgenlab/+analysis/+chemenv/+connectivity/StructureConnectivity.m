%#ok<*AGROW,*ALIGN,*ASGSL,*CCAT1>
classdef StructureConnectivity < handle
    %STRUCTURECONNECTIVITY Periodic multigraph of sites and environments.
    properties
        light_structure_environments
        environment_subgraphs
        connectivity_description struct=struct()
    end
    properties (Access=private)
        graph_value
        environment_subgraph_value=[]
    end
    methods
        function obj=StructureConnectivity(lse,varargin)
            opts=parseNamed(struct(connectivity_graph=[], ...
                environment_subgraphs=[]),varargin{:});
            obj.light_structure_environments=lse;
            if isempty(opts.connectivity_graph)
                obj.graph_value=emptyGraph();
            else,obj.graph_value=opts.connectivity_graph;end
            if isempty(opts.environment_subgraphs)
                obj.environment_subgraphs=containers.Map( ...
                    "KeyType","char","ValueType","any");
            else,obj.environment_subgraphs=opts.environment_subgraphs;end
        end
        function value=environment_subgraph(obj,varargin)
            opts=parseNamed(struct(environments_symbols=[],only_atoms=[]), ...
                varargin{:});
            if ~isempty(opts.environments_symbols)
                obj.setup_environment_subgraph(opts.environments_symbols, ...
                    "only_atoms",opts.only_atoms);
            elseif isempty(obj.environment_subgraph_value)
                symbols=obj.light_structure_environments. ...
                    environments_identified();
                obj.setup_environment_subgraph(symbols, ...
                    "only_atoms",opts.only_atoms);
            end
            value=obj.environment_subgraph_value;
        end
        function add_sites(obj)
            obj.graph_value.nodes=1:obj.light_structure_environments. ...
                structure.num_sites;
        end
        function add_bonds(obj,isite,neighborSet)
            neighbors=neighborSet.neighb_indices_and_images;
            for ii=1:numel(neighbors)
                target=neighbors{ii}.index;
                delta=reshape(double(neighbors{ii}.image_cell),1,3);
                if target==0,target=1;end
                if ~edgeExists(obj.graph_value.edges,isite,target,delta)
                    edge=struct("u",isite,"v",target,"start",isite, ...
                        "end",target,"delta",delta,"ligands",{{}});
                    obj.graph_value.edges(end+1)=edge;
                end
            end
        end
        function setup_environment_subgraph(obj,symbols,varargin)
            opts=parseNamed(struct(only_atoms=[]),varargin{:});
            symbols=sort(string(symbols));
            key=char(strjoin(symbols,"-"));
            if ~isempty(opts.only_atoms)
                key=key+"#"+strjoin(sort(string(opts.only_atoms)),"-");
            end
            key=char(key);
            if isKey(obj.environment_subgraphs,key)
                obj.environment_subgraph_value= ...
                    obj.environment_subgraphs(key);return
            end
            graph=emptyGraph();graph.nodes={};siteIndices=[];
            lse=obj.light_structure_environments;
            for isite=1:lse.structure.num_sites
                envs=lse.coordination_environments{isite};
                if isempty(envs),continue,end
                symbol=string(envs{1}.ce_symbol);
                if ~any(symbols==symbol),continue,end
                if ~isempty(opts.only_atoms)&& ...
                        ~any(string(opts.only_atoms)== ...
                        string(lse.structure.sites{isite}.species_string))
                    continue
                end
                graph.nodes{end+1}=kssolv.analysis.matgenlab.analysis. ...
                    chemenv.connectivity.get_environment_node( ...
                    lse.structure.sites{isite},isite,symbol);
                siteIndices(end+1)=isite;
            end
            for i1=1:numel(siteIndices)
                site1=siteIndices(i1);
                links1=incidentEdges(obj.graph_value.edges,site1);
                for i2=i1:numel(siteIndices)
                    site2=siteIndices(i2);
                    links2=incidentEdges(obj.graph_value.edges,site2);
                    deltas={};ligands={};
                    for e1=links1
                        ligand1=otherEnd(e1,site1);
                        for e2=links2
                            ligand2=otherEnd(e2,site2);
                            if ligand1~=ligand2,continue,end
                            delta=kssolv.analysis.matgenlab.analysis. ...
                                chemenv.connectivity.get_delta_image( ...
                                site1,site2,e1,e2);
                            if site1==site2&&all(delta==0),continue,end
                            index=find(cellfun(@(x)isequal(x,delta), ...
                                deltas),1);
                            ligand=struct(index=ligand1,data1=e1,data2=e2);
                            if isempty(index)
                                deltas{end+1}=delta;ligands{end+1}={ligand};
                            else,ligands{index}{end+1}=ligand;end
                        end
                    end
                    if i1==i2,[deltas,ligands]=removeOpposite( ...
                            deltas,ligands);end
                    for jj=1:numel(deltas)
                        graph.edges(end+1)=struct("u",i1,"v",i2, ...
                            "start",site1,"end",site2, ...
                            "delta",deltas{jj}, ...
                            "ligands",{ligands{jj}});
                    end
                end
            end
            obj.environment_subgraph_value=graph;
            obj.environment_subgraphs(key)=graph;
        end
        function setup_connectivity_description(obj)
            graph=obj.graph_value;
            deltas=zeros(numel(graph.edges),3);
            for ii=1:numel(graph.edges)
                deltas(ii,:)=graph.edges(ii).delta;
            end
            obj.connectivity_description=struct( ...
                number_of_sites=numel(graph.nodes), ...
                number_of_bonds=numel(graph.edges), ...
                number_of_periodic_bonds=sum(any(deltas~=0,2)), ...
                environment_subgraphs={sort(obj.environment_subgraphs.keys)});
        end
        function value=get_connected_components(obj,varargin)
            graph=obj.environment_subgraph(varargin{:});
            groups=componentGroups(graph);
            value=cell(1,numel(groups));
            for ii=1:numel(groups)
                nodes=groups{ii};
                keep=ismember([graph.edges.u],nodes)& ...
                    ismember([graph.edges.v],nodes);
                sub=emptyGraph();sub.nodes=graph.nodes(nodes);
                remap=zeros(1,numel(graph.nodes));remap(nodes)=1:numel(nodes);
                sub.edges=graph.edges(keep);
                for jj=1:numel(sub.edges)
                    sub.edges(jj).u=remap(sub.edges(jj).u);
                    sub.edges(jj).v=remap(sub.edges(jj).v);
                end
                value{ii}=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    connectivity.ConnectedComponent.from_graph(sub);
            end
        end
        function setup_atom_environment_subgraph(obj,atomEnvironment)
            obj.setup_environment_subgraph(atomEnvironment{2}, ...
                "only_atoms",atomEnvironment{1});
        end
        function setup_environments_subgraph(obj,environmentsSymbols)
            obj.setup_environment_subgraph(environmentsSymbols);
        end
        function setup_atom_environments_subgraph(obj,atomsEnvironments)
            atoms=cellfun(@(x)x{1},atomsEnvironments,"UniformOutput",false);
            envs=cellfun(@(x)x{2},atomsEnvironments,"UniformOutput",false);
            obj.setup_environment_subgraph(envs,"only_atoms",atoms);
        end
        function print_links(obj)
            graph=obj.environment_subgraph();
            fprintf("Links in graph :\n");
            for ii=1:numel(graph.edges)
                edge=graph.edges(ii);
                fprintf("%d - %d by %d ligands (%g %g %g)\n", ...
                    edge.start,edge.end,numel(edge.ligands),edge.delta);
            end
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "connectivity.structure_connectivity", ...
                x_class="StructureConnectivity", ...
                light_structure_environments= ...
                obj.light_structure_environments.as_dict(), ...
                connectivity_graph=graphToDict(obj.graph_value), ...
                environment_subgraphs=struct());
        end
    end
    methods (Static)
        function obj=from_dict(value)
            lse=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.LightStructureEnvironments. ...
                from_dict(value.light_structure_environments);
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                connectivity.StructureConnectivity(lse, ...
                "connectivity_graph",dictToGraph(value.connectivity_graph));
        end
    end
end
function value=emptyGraph()
template=struct("u",{},"v",{},"start",{},"end",{}, ...
    "delta",{},"ligands",{});
value=struct(nodes=[],edges=template);
end
function value=edgeExists(edges,u,v,delta)
value=false;
for edge=edges
    if edge.start==u&&edge.end==v&&isequal(edge.delta,delta)
        value=true;return
    end
    if edge.start==v&&edge.end==u&&isequal(edge.delta,-delta)
        value=true;return
    end
end
end
function value=incidentEdges(edges,node)
value=edges([edges.u]==node|[edges.v]==node);
end
function value=otherEnd(edge,node)
if edge.start==node,value=edge.end;else,value=edge.start;end
end
function [deltas,ligands]=removeOpposite(deltas,ligands)
keep=true(1,numel(deltas));
for ii=1:numel(deltas)
    if ~keep(ii),continue,end
    opposite=find(cellfun(@(x)isequal(x,-deltas{ii}),deltas),1);
    if ~isempty(opposite)&&opposite~=ii,keep(opposite)=false;end
end
deltas=deltas(keep);ligands=ligands(keep);
end
function value=componentGroups(graph)
n=numel(graph.nodes);visited=false(1,n);value={};
for source=1:n
    if visited(source),continue,end
    queue=source;visited(source)=true;group=[];
    while ~isempty(queue)
        node=queue(1);queue(1)=[];group(end+1)=node;
        edges=graph.edges([graph.edges.u]==node|[graph.edges.v]==node);
        adjacent=[];
        for edge=edges
            if edge.u==node,adjacent(end+1)=edge.v;
            else,adjacent(end+1)=edge.u;end
        end
        fresh=adjacent(~visited(adjacent));visited(fresh)=true;
        queue=[queue,fresh];
    end
    value{end+1}=group;
end
end
function value=graphToDict(graph)
value=graph;
for ii=1:numel(value.edges)
    value.edges(ii).delta=reshape(value.edges(ii).delta,1,3);
end
end
function value=dictToGraph(value),value=value;end
function opts=parseNamed(opts,varargin)
for ii=1:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
