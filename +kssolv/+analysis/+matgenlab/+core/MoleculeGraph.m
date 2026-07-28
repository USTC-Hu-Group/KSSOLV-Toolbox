classdef MoleculeGraph < handle
    %MOLECULEGRAPH Attributed undirected graph associated with a Molecule.
    properties
        molecule
        graph (1,1) kssolv.analysis.matgenlab.core.GraphStore
    end
    properties (Dependent,SetAccess=private)
        name
        edge_weight_name
        edge_weight_unit
    end
    methods
        function obj=MoleculeGraph(molecule,graph_data)
            if isa(molecule,"kssolv.analysis.matgenlab.core.MoleculeGraph")
                copy=molecule;obj.molecule=copy.molecule.copy();
                obj.graph=copy.graph.copy();return
            end
            obj.molecule=molecule;
            if nargin<2||isempty(graph_data)
                obj.graph=kssolv.analysis.matgenlab.core.GraphStore( ...
                    molecule.num_sites);
            elseif isa(graph_data,"kssolv.analysis.matgenlab.core.GraphStore")
                obj.graph=graph_data.copy();
            else
                obj.graph=storeFromStruct(graph_data);
            end
            obj.set_node_attributes();
        end
        function value=get.name(obj),value=obj.graph.attributes.name;end
        function value=get.edge_weight_name(obj)
            value=obj.graph.attributes.edge_weight_name;
        end
        function value=get.edge_weight_unit(obj)
            value=obj.graph.attributes.edge_weight_units;
        end
        function obj=add_edge(obj,from_index,to_index,varargin)
            options=struct(weight=[],warn_duplicates=true,edge_properties=struct());
            options=parseOptions(options,varargin);
            validateNode(obj,from_index);validateNode(obj,to_index);
            if from_index==to_index,return,end
            if to_index<from_index,[from_index,to_index]=deal(to_index,from_index);end
            if any(arrayfun(@(e)e.from_index==from_index&& ...
                    e.to_index==to_index,obj.graph.edges)),return,end
            props=options.edge_properties;if isempty(props),props=struct();end
            obj.graph.add_edge(from_index,to_index,"weight",options.weight, ...
                "edge_properties",props);
        end
        function obj=insert_node(obj,index,species,coords,varargin)
            options=struct(validate_proximity=false,site_properties=struct(),edges=[]);
            options=parseOptions(options,varargin);
            obj.molecule=obj.molecule.insert(index,species,coords, ...
                validate_proximity=options.validate_proximity, ...
                properties=options.site_properties);
            for ii=1:numel(obj.graph.edges)
                if obj.graph.edges(ii).from_index>=index
                    obj.graph.edges(ii).from_index=obj.graph.edges(ii).from_index+1;
                end
                if obj.graph.edges(ii).to_index>=index
                    obj.graph.edges(ii).to_index=obj.graph.edges(ii).to_index+1;
                end
            end
            obj.set_node_attributes();obj=addSpecifiedEdges(obj,options.edges);
        end
        function obj=set_node_attributes(obj)
            obj.graph.nodes=cell(1,obj.molecule.num_sites);
            for ii=1:obj.molecule.num_sites
                site=obj.molecule(ii);
                obj.graph.nodes{ii}=struct(specie=site.specie.symbol, ...
                    coords=site.coords,properties=site.site_properties);
            end
        end
        function obj=alter_edge(obj,from_index,to_index,varargin)
            options=struct(new_weight=[],new_edge_properties=[]);
            options=parseOptions(options,varargin);
            which=findEdge(obj,from_index,to_index);
            if isempty(which),error("KSSOLV:Matgenlab:MoleculeGraph:MissingEdge", ...
                    "Edge between the requested sites does not exist.");end
            if ~isempty(options.new_weight),obj.graph.edges(which).weight=options.new_weight;end
            if ~isempty(options.new_edge_properties)
                props=obj.graph.edges(which).edge_properties;
                names=fieldnames(options.new_edge_properties);
                for ii=1:numel(names),props.(names{ii})= ...
                        options.new_edge_properties.(names{ii});end
                obj.graph.edges(which).edge_properties=props;
            end
        end
        function obj=break_edge(obj,from_index,to_index,varargin)
            options=struct(allow_reverse=false);options=parseOptions(options,varargin); %#ok<NASGU>
            which=findEdge(obj,from_index,to_index);
            if isempty(which),error("KSSOLV:Matgenlab:MoleculeGraph:MissingEdge", ...
                    "Edge cannot be broken because it does not exist.");end
            obj.graph.remove_edge(which);
        end
        function obj=remove_nodes(obj,indices)
            indices=sort(unique(reshape(indices,1,[])));
            keep=~ismember(1:obj.molecule.num_sites,indices);
            mapping=zeros(1,obj.molecule.num_sites);mapping(keep)=1:sum(keep);
            edgeKeep=true(1,numel(obj.graph.edges));
            for ii=1:numel(obj.graph.edges)
                e=obj.graph.edges(ii);
                if ~keep(e.from_index)||~keep(e.to_index),edgeKeep(ii)=false;
                else
                    obj.graph.edges(ii).from_index=mapping(e.from_index);
                    obj.graph.edges(ii).to_index=mapping(e.to_index);
                end
            end
            obj.graph.edges=obj.graph.edges(edgeKeep);
            obj.molecule=obj.molecule.remove_sites(indices);obj.set_node_attributes();
        end
        function [fragments,index_map]=get_disconnected_fragments(obj,return_index_map)
            if nargin<2,return_index_map=false;end
            components=connectedComponents(obj.graph.adjacency());
            if isscalar(components)
                fragments={kssolv.analysis.matgenlab.core.MoleculeGraph(obj)};
                index_map=[];return
            end
            fragments=cell(1,numel(components));index_map=[];
            for cc=1:numel(components)
                nodes=components{cc};index_map=[index_map,nodes]; %#ok<AGROW>
                charge=0;if any(nodes==1),charge=obj.molecule.charge;end
                fragmentMolecule=kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                    obj.molecule.sites(nodes),charge=charge);
                edges={};
                for e=obj.graph.edges
                    if ismember(e.from_index,nodes)&&ismember(e.to_index,nodes)
                        props=e.edge_properties;if ~isempty(e.weight),props.weight=e.weight;end
                        edges(end+1,:)={find(nodes==e.from_index), ...
                            find(nodes==e.to_index),props}; %#ok<AGROW>
                    end
                end
                fragments{cc}=kssolv.analysis.matgenlab.core. ...
                    MoleculeGraph.from_edges(fragmentMolecule,edges);
            end
            if ~return_index_map,index_map=[];end
        end
        function fragments=split_molecule_subgraphs(obj,bonds,varargin)
            options=struct(allow_reverse=false,alterations=[]);
            options=parseOptions(options,varargin);
            copy=kssolv.analysis.matgenlab.core.MoleculeGraph(obj);
            if iscell(bonds),items=bonds;else,items=num2cell(bonds,2);end
            for ii=1:numel(items)
                bond=items{ii};copy.break_edge(bond(1),bond(2), ...
                    "allow_reverse",options.allow_reverse);
            end
            if ~isempty(options.alterations)
                alterations=options.alterations;
                if isstruct(alterations)
                    names=fieldnames(alterations);
                    for ii=1:numel(names)
                        a=alterations.(names{ii});
                        copy.alter_edge(a.from_index,a.to_index, ...
                            "new_weight",a.weight);
                    end
                end
            end
            if isscalar(connectedComponents(copy.graph.adjacency()))
                throw(kssolv.analysis.matgenlab.core.MolGraphSplitError());
            end
            fragments=copy.get_disconnected_fragments();
        end
        function fragments=build_unique_fragments(obj)
            n=obj.molecule.num_sites;fragments=struct();
            if n>22,error("KSSOLV:Matgenlab:MoleculeGraph:FragmentLimit", ...
                    "Exhaustive fragment generation is limited to 22 sites.");end
            for mask=1:(2^n-2)
                nodes=find(bitget(mask,1:n));
                adjacency=obj.graph.adjacency();
                if numel(connectedComponents(adjacency(nodes,nodes)))~=1,continue,end
                fragment=subgraph(obj,nodes);
                symbols=sort(string(fragment.molecule.species));
                key=matlab.lang.makeValidName(char(join(symbols,"_")+ ...
                    "_e"+fragment.graph.number_of_edges()));
                if ~isfield(fragments,key),fragments.(key)={fragment};
                elseif ~any(cellfun(@(x)x.isomorphic_to(fragment),fragments.(key)))
                    fragments.(key){end+1}=fragment;
                end
            end
        end
        function obj=substitute_group(obj,index,func_grp,strategy,varargin)
            options=struct(bond_order=1,graph_dict=[],strategy_params=struct());
            options=parseOptions(options,varargin);
            [group,groupGraph]=functionalGroup(func_grp,options.graph_dict,strategy);
            obj=attachGroup(obj,index,group,groupGraph,false);
        end
        function obj=replace_group(obj,index,func_grp,strategy,varargin)
            options=struct(bond_order=1,graph_dict=[],strategy_params=struct());
            options=parseOptions(options,varargin);
            [group,groupGraph]=functionalGroup(func_grp,options.graph_dict,strategy);
            obj=attachGroup(obj,index,group,groupGraph,true);
        end
        function rings=find_rings(obj,including)
            if nargin<2,including=[];end
            adjacency=obj.graph.adjacency()>0;n=size(adjacency,1);
            keys=strings(1,0);cycles={};
            for start=1:n
                dfs(start,start,start,false(1,n),[]);
            end
            rings=cell(size(cycles));
            for ii=1:numel(cycles)
                cycle=cycles{ii};edges=cell(1,numel(cycle));
                for jj=1:numel(cycle)
                    edges{jj}=[cycle(jj),cycle(mod(jj,numel(cycle))+1)];
                end
                rings{ii}=cell2mat(edges.');
            end
            function dfs(start,current,parent,visited,path)
                visited(current)=true;path=[path,current];
                for next=find(adjacency(current,:))
                    if next==start&&numel(path)>=3
                        if ~isempty(including)&&~any(ismember(including,path)),continue,end
                        canonical=canonicalCycle(path);key=join(string(canonical),",");
                        if ~any(keys==key),keys(end+1)=key;cycles{end+1}=path;end %#ok<AGROW>
                    elseif ~visited(next)&&next>=start&&next~=parent
                        dfs(start,next,current,visited,path);
                    end
                end
            end
        end
        function connected=get_connected_sites(obj,n)
            validateNode(obj,n);connected={};
            for e=obj.graph.edges
                index=[];
                if e.from_index==n,index=e.to_index;
                elseif e.to_index==n,index=e.from_index;end
                if isempty(index),continue,end
                site=obj.molecule(index);distance=site.distance(obj.molecule(n));
                connected{end+1}=kssolv.analysis.matgenlab.core. ...
                    ConnectedSite(site,[0,0,0],index,e.weight,distance); %#ok<AGROW>
            end
            if ~isempty(connected)
                distances=cellfun(@(x)x.dist,connected);
                [~,order]=sort(distances);
                connected=connected(order);
            end
        end
        function value=get_coordination_of_site(obj,n)
            value=numel(obj.get_connected_sites(n));
        end
        function filename=draw_graph_to_file(obj,filename,varargin)
            sg=molecularStructureGraph(obj);
            filename=sg.draw_graph_to_file(filename,varargin{:});
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.core.graphs", ...
                x_class="MoleculeGraph",molecule=obj.molecule.as_dict(), ...
                graphs=obj.graph.as_struct());
        end
        function value=asDict(obj),value=obj.as_dict();end
        function text=toJSON(obj,varargin)
            text=kssolv.analysis.matgenlab.util.encode(obj.as_dict(),varargin{:});
        end
        function obj=sort(obj,key,reverse)
            if nargin<2,key=[];end;if nargin<3,reverse=false;end
            old=obj.molecule.sites;
            if isempty(key)
                values=zeros(1,numel(old));
                for ii=1:numel(old),values(ii)=old{ii}.specie.X;end
            else
                values=cellfun(key,old);
            end
            [~,order]=sort(values);if reverse,order=flip(order);end
            mapping=zeros(1,numel(order));mapping(order)=1:numel(order);
            obj.molecule=kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                old(order),charge=obj.molecule.charge);
            for ii=1:numel(obj.graph.edges)
                obj.graph.edges(ii).from_index=mapping(obj.graph.edges(ii).from_index);
                obj.graph.edges(ii).to_index=mapping(obj.graph.edges(ii).to_index);
                if obj.graph.edges(ii).to_index<obj.graph.edges(ii).from_index
                    [obj.graph.edges(ii).from_index,obj.graph.edges(ii).to_index]= ...
                        deal(obj.graph.edges(ii).to_index,obj.graph.edges(ii).from_index);
                end
            end
            obj.set_node_attributes();
        end
        function tf=isomorphic_to(obj,other)
            tf=graphIsomorphic(obj,other);
        end
        function value=diff(obj,other,strict)
            if nargin<3,strict=true;end
            if strict
                mapping=moleculeSiteMapping(obj.molecule,other.molecule);
                if isempty(mapping)
                    error("KSSOLV:Matgenlab:MoleculeGraph:Diff", ...
                        "Meaningless to compare MoleculeGraphs if " + ...
                        "corresponding Molecules are different.");
                end
                first=edgeLabelsMapped(obj,1:obj.molecule.num_sites);
                second=edgeLabelsMapped(other,mapping);
            else
                first=edgeLabels(obj,false);
                second=edgeLabels(other,false);
            end
            both=intersect(first,second);den=numel(union(first,second));
            distance=0;if den>0,distance=1-numel(both)/den;end
            value=struct(dist=distance,self={cellstr(setdiff(first,second))}, ...
                other={cellstr(setdiff(second,first))},both={cellstr(both)});
        end
        function tf=eq(obj,other)
            tf=false;
            if ~isa(other,class(obj)),return,end
            try
                tf=obj.diff(other,true).dist==0;
            catch
                tf=false;
            end
        end
        function tf=ne(obj,other),tf=~eq(obj,other);end
        function n=length(obj),n=obj.molecule.num_sites;end
        function text=char(obj)
            text=sprintf("Molecule Graph: %s, %d nodes, %d edges",obj.name, ...
                obj.graph.number_of_nodes(),obj.graph.number_of_edges());
        end
    end
    methods (Static)
        function obj=from_empty_graph(molecule,varargin)
            options=struct(name="bonds",edge_weight_name=[], ...
                edge_weight_units=[]);options=parseOptions(options,varargin);
            if ~isempty(options.edge_weight_name)&&isempty(options.edge_weight_units)
                error("KSSOLV:Matgenlab:MoleculeGraph:WeightUnits", ...
                    "Please specify units associated with edge weights.");
            end
            attrs=struct(name=options.name,edge_weight_name=options.edge_weight_name, ...
                edge_weight_units=options.edge_weight_units);
            store=kssolv.analysis.matgenlab.core.GraphStore(molecule.num_sites,attrs);
            obj=kssolv.analysis.matgenlab.core.MoleculeGraph(molecule,store);
        end
        function obj=with_empty_graph(varargin)
            obj=kssolv.analysis.matgenlab.core.MoleculeGraph.from_empty_graph(varargin{:});
        end
        function obj=from_edges(molecule,edges)
            obj=kssolv.analysis.matgenlab.core.MoleculeGraph.from_empty_graph( ...
                molecule,"edge_weight_name","weight","edge_weight_units","");
            entries=normalizeMoleculeEdges(edges);
            for ii=1:numel(entries)
                e=entries{ii};obj.add_edge(e.from_index,e.to_index, ...
                    "weight",e.weight,"edge_properties",e.properties);
            end
        end
        function obj=with_edges(varargin)
            obj=kssolv.analysis.matgenlab.core.MoleculeGraph.from_edges(varargin{:});
        end
        function obj=from_local_env_strategy(molecule,strategy)
            if ~strategy.molecules_allowed
                error("KSSOLV:Matgenlab:MoleculeGraph:Strategy", ...
                    "Chosen strategy is not designed for use with molecules.");
            end
            obj=kssolv.analysis.matgenlab.core.MoleculeGraph.from_empty_graph( ...
                molecule,"edge_weight_name","weight","edge_weight_units","");
            environment=molecule;
            if strategy.extend_structure_molecules
                xyz=molecule.cart_coords;
                spans=max(xyz,[],1)-min(xyz,[],1)+100;
                environment=molecule.get_boxed_structure( ...
                    spans(1),spans(2),spans(3),no_cross=true,reorder=false);
            end
            for ii=1:molecule.num_sites
                info=strategy.get_nn_info(environment,ii);
                for jj=1:numel(info)
                    item=info{jj};
                    if isfield(item,"image")&&any(item.image~=0),continue,end
                    obj.add_edge(ii,item.site_index,"weight",item.weight, ...
                        "warn_duplicates",false);
                end
            end
        end
        function obj=with_local_env_strategy(varargin)
            obj=kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                from_local_env_strategy(varargin{:});
        end
        function obj=from_dict(value)
            molecule=kssolv.analysis.matgenlab.core.Molecule.from_dict(value.molecule);
            obj=kssolv.analysis.matgenlab.core.MoleculeGraph(molecule,value.graphs);
        end
        function obj=fromDict(value),obj=kssolv.analysis.matgenlab.core.MoleculeGraph.from_dict(value);end
    end
end

function validateNode(obj,index)
if index<1||index>obj.molecule.num_sites||index~=fix(index)
    error("KSSOLV:Matgenlab:MoleculeGraph:Node","Node index is out of bounds.");
end
end
function which=findEdge(obj,first,second)
a=min(first,second);b=max(first,second);
which=find(arrayfun(@(e)e.from_index==a&&e.to_index==b,obj.graph.edges),1);
end
function obj=addSpecifiedEdges(obj,edges)
if isempty(edges),return,end
if isstruct(edges),entries=num2cell(edges);else,entries=edges;end
for ii=1:numel(entries)
    e=entries{ii};args={};
    if isfield(e,"weight"),args=[args,{"weight",e.weight}];end %#ok<AGROW>
    if isfield(e,"properties"),args=[args,{"edge_properties",e.properties}];end %#ok<AGROW>
    obj.add_edge(e.from_index,e.to_index,args{:});
end
end
function store=storeFromStruct(value)
store=kssolv.analysis.matgenlab.core.GraphStore(0,value.attributes);
nodes=value.nodes;if isstruct(nodes),nodes=num2cell(nodes);end;store.nodes=nodes;
edges=value.edges;if iscell(edges),edges=[edges{:}];end;store.edges=edges;
end
function entries=normalizeMoleculeEdges(edges)
entries={};if isempty(edges),return,end
if isnumeric(edges)
    raw=num2cell(edges,2);
elseif iscell(edges)
    if size(edges,2)>=2&&~isstruct(edges{1})
        raw=cell(size(edges,1),1);
        for ii=1:size(edges,1)
            raw{ii}=edges(ii,:);
        end
    else
        raw=edges;
    end
elseif isstruct(edges)
    raw=num2cell(edges);
else
    error("KSSOLV:Matgenlab:MoleculeGraph:Edges","Unsupported edge data.");
end
for ii=1:numel(raw)
    item=raw{ii};weight=[];props=struct();
    if isstruct(item)
        from=item.from_index;to=item.to_index;
        if isfield(item,"weight"),weight=item.weight;end
        if isfield(item,"properties"),props=item.properties;end
    elseif isnumeric(item)
        from=item(1);to=item(2);
    else
        from=item{1};to=item{2};
        if numel(item)>=3&&isstruct(item{3})
            props=item{3};if isfield(props,"weight"),weight=props.weight;props=rmfield(props,"weight");end
        end
    end
    entries{end+1}=struct(from_index=from,to_index=to, ...
        weight=weight,properties=props); %#ok<AGROW>
end
end
function components=connectedComponents(adjacency)
n=size(adjacency,1);seen=false(1,n);components={};
for start=1:n
    if seen(start),continue,end
    queue=start;seen(start)=true;component=[];
    while ~isempty(queue)
        node=queue(1);queue(1)=[];component(end+1)=node; %#ok<AGROW>
        next=find(adjacency(node,:)>0&~seen);seen(next)=true;
        queue=[queue,next]; %#ok<AGROW>
    end
    components{end+1}=component; %#ok<AGROW>
end
end
function fragment=subgraph(obj,nodes)
molecule=kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
    obj.molecule.sites(nodes),charge=double(any(nodes==1))*obj.molecule.charge);
rows={};
for e=obj.graph.edges
    if ismember(e.from_index,nodes)&&ismember(e.to_index,nodes)
        props=e.edge_properties;if ~isempty(e.weight),props.weight=e.weight;end
        rows(end+1,:)={find(nodes==e.from_index),find(nodes==e.to_index),props}; %#ok<AGROW>
    end
end
fragment=kssolv.analysis.matgenlab.core.MoleculeGraph.from_edges(molecule,rows);
end
function cycle=canonicalCycle(path)
[~,where]=min(path);a=circshift(path,1-where);b=[a(1),fliplr(a(2:end))];
if join(string(a),",")<=join(string(b),","),cycle=a;else,cycle=b;end
end
function tf=graphIsomorphic(first,second,useWeights)
if nargin<3,useWeights=false;end
n=first.molecule.num_sites;
if n~=second.molecule.num_sites||first.graph.number_of_edges()~= ...
        second.graph.number_of_edges(),tf=false;return,end
a=first.graph.adjacency();b=second.graph.adjacency();
labelsA=string(cellfun(@(x)x.specie.symbol,first.molecule.sites, ...
    "UniformOutput",false));
labelsB=string(cellfun(@(x)x.specie.symbol,second.molecule.sites, ...
    "UniformOutput",false));
if ~isequal(sort(labelsA),sort(labelsB)),tf=false;return,end
degreeA=sum(a,2).';degreeB=sum(b,2).';mapping=zeros(1,n);used=false(1,n);
[~,order]=sort(degreeA,"descend");tf=search(1);
    function success=search(position)
        if position>n,success=true;return,end
        node=order(position);
        candidates=find(~used&labelsB==labelsA(node)&degreeB==degreeA(node));
        success=false;
        for candidate=candidates
            consistent=true;
            for previous=1:n
                if mapping(previous)>0&&a(node,previous)~=b(candidate,mapping(previous))
                    consistent=false;break
                end
                if useWeights&&mapping(previous)>0&&a(node,previous)>0&& ...
                        ~isequaln(edgeWeight(first,node,previous), ...
                        edgeWeight(second,candidate,mapping(previous)))
                    consistent=false;break
                end
            end
            if consistent
                mapping(node)=candidate;used(candidate)=true;
                if search(position+1),success=true;return,end
                mapping(node)=0;used(candidate)=false;
            end
        end
    end
end
function labels=edgeLabels(obj,strict)
labels=strings(1,numel(obj.graph.edges));
for ii=1:numel(obj.graph.edges)
    e=obj.graph.edges(ii);
    if strict,labels(ii)=e.from_index+"-"+e.to_index;
    else
        pair=sort([obj.molecule(e.from_index).specie.symbol, ...
            obj.molecule(e.to_index).specie.symbol]);
        labels(ii)=pair(1)+"-"+pair(2);
    end
end
labels=unique(labels);
end
function labels=edgeLabelsMapped(obj,mapping)
labels=strings(1,numel(obj.graph.edges));
for ii=1:numel(obj.graph.edges)
    edge=obj.graph.edges(ii);
    first=mapping(edge.from_index);second=mapping(edge.to_index);
    labels(ii)=min(first,second)+"-"+max(first,second);
end
labels=unique(labels);
end
function mapping=moleculeSiteMapping(reference,candidate)
mapping=[];
if reference.num_sites~=candidate.num_sites|| ...
        reference.charge~=candidate.charge|| ...
        reference.spin_multiplicity~=candidate.spin_multiplicity
    return
end
result=zeros(1,reference.num_sites);used=false(1,reference.num_sites);
for candidateIndex=1:candidate.num_sites
    found=0;
    for referenceIndex=1:reference.num_sites
        if ~used(referenceIndex)&& ...
                reference.sites{referenceIndex}==candidate.sites{candidateIndex}
            found=referenceIndex;break
        end
    end
    if found==0,return,end
    result(candidateIndex)=found;used(found)=true;
end
mapping=result;
end
function value=edgeWeight(graph,first,second)
firstNode=min(first,second);secondNode=max(first,second);value=[];
for edge=graph.graph.edges
    if edge.from_index==firstNode&&edge.to_index==secondNode
        value=edge.weight;return
    end
end
end
function [group,graph]=functionalGroup(input,graphData,strategy)
if isa(input,"kssolv.analysis.matgenlab.core.MoleculeGraph")
    group=input.molecule;graph=input;return
elseif isa(input,"kssolv.analysis.matgenlab.core.IMolecule")
    group=input;
elseif ischar(input)||isstring(input)
    group=loadFunctionalGroup(input);
else
    error("KSSOLV:Matgenlab:MoleculeGraph:FunctionalGroup", ...
        "Unknown functional-group representation.");
end
if ~isempty(graphData)
    graph=kssolv.analysis.matgenlab.core.MoleculeGraph.from_edges(group,graphData);
else
    try
        graph=kssolv.analysis.matgenlab.core.MoleculeGraph. ...
            from_local_env_strategy(group,strategy());
    catch
        graph=kssolv.analysis.matgenlab.core.MoleculeGraph.from_empty_graph(group);
        for ii=2:group.num_sites
            if kssolv.analysis.matgenlab.core.CovalentBond.is_bonded(group(2),group(ii),.3)
                graph.add_edge(2,ii);
            end
        end
    end
end
end
function group=loadFunctionalGroup(name)
databasePath=fullfile(fileparts(mfilename("fullpath")), ...
    "+data","func_groups.json");
database=jsondecode(fileread(databasePath));
key=char(lower(string(name)));
if ~isfield(database,key)
    error("KSSOLV:Matgenlab:MoleculeGraph:FunctionalGroup", ...
        "Unknown functional group '%s'.",string(name));
end
record=database.(key);
group=kssolv.analysis.matgenlab.core.Molecule( ...
    cellstr(string(record.species)),double(record.coords));
end
function obj=attachGroup(obj,index,group,groupGraph,replace)
neighbors=obj.get_connected_sites(index);
if isempty(neighbors),error("KSSOLV:Matgenlab:MoleculeGraph:FunctionalGroup", ...
        "Attachment site must have a connected neighbor.");end
anchor=neighbors{1}.index;anchorCoords=obj.molecule(anchor).coords;
oldCoords=obj.molecule(index).coords;
if replace
    adjacency=obj.graph.adjacency()>0;
    adjacency(anchor,index)=false;adjacency(index,anchor)=false;
    branch=reachable(adjacency,index);remove=setdiff(branch,index);
    oldIndex=index;oldAnchor=anchor;
    if ~isempty(remove),obj.remove_nodes(remove);end
    index=oldIndex-sum(remove<oldIndex);
    anchor=oldAnchor-sum(remove<oldAnchor);
    anchorCoords=obj.molecule(anchor).coords;oldCoords=obj.molecule(index).coords;
end
source=group(2).coords-group(1).coords;target=oldCoords-anchorCoords;
rotation=alignVectors(source,target);
transformed=(group.cart_coords-group(1).coords)*rotation.'+anchorCoords;
sites=obj.molecule.sites;
sites{index}=kssolv.analysis.matgenlab.core.Site(group(2).species, ...
    transformed(2,:),properties=group(2).site_properties,label=group(2).label);
obj.molecule=kssolv.analysis.matgenlab.core.Molecule.from_sites(sites, ...
    charge=obj.molecule.charge);
keepEdges=arrayfun(@(e)~(e.from_index==index||e.to_index==index),obj.graph.edges);
obj.graph.edges=obj.graph.edges(keepEdges);obj.add_edge(anchor,index);
mapping=zeros(1,group.num_sites);mapping(2)=index;
for ii=3:group.num_sites
    obj.molecule=obj.molecule.append(group(ii).species,transformed(ii,:), ...
        properties=group(ii).site_properties);
    mapping(ii)=obj.molecule.num_sites;
end
for e=groupGraph.graph.edges
    if e.from_index==1||e.to_index==1,continue,end
    obj.add_edge(mapping(e.from_index),mapping(e.to_index), ...
        "weight",e.weight,"edge_properties",e.edge_properties);
end
obj.set_node_attributes();
end
function nodes=reachable(adjacency,start)
seen=false(1,size(adjacency,1));seen(start)=true;queue=start;nodes=[];
while ~isempty(queue)
    node=queue(1);queue(1)=[];nodes(end+1)=node; %#ok<AGROW>
    next=find(adjacency(node,:)&~seen);seen(next)=true;queue=[queue,next]; %#ok<AGROW>
end
end
function rotation=alignVectors(first,second)
first=first/norm(first);second=second/norm(second);axis=cross(first,second);
c=dot(first,second);
if norm(axis)<1e-12
    if c>0,rotation=eye(3);else
        axis=null(first).';axis=axis(1,:);K=skew(axis);rotation=eye(3)+2*K*K;
    end
else
    axis=axis/norm(axis);K=skew(axis);rotation=eye(3)+sqrt(1-c^2)*K+(1-c)*K*K;
end
end
function K=skew(v),K=[0,-v(3),v(2);v(3),0,-v(1);-v(2),v(1),0];end
function sg=molecularStructureGraph(obj)
lattice=kssolv.analysis.matgenlab.core.Lattice.cubic(100);
structure=kssolv.analysis.matgenlab.core.Structure(lattice, ...
    obj.molecule.species_and_occu,obj.molecule.cart_coords+50, ...
    coords_are_cartesian=true);
rows={};
for e=obj.graph.edges
    props=e.edge_properties;if ~isempty(e.weight),props.weight=e.weight;end
    rows(end+1,:)={e.from_index,e.to_index,[0,0,0],[0,0,0],props}; %#ok<AGROW>
end
sg=kssolv.analysis.matgenlab.core.StructureGraph.from_edges(structure,rows);
end
function output=parseOptions(output,input)
names=fieldnames(output);ii=1;position=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else
        output.(names{position})=input{ii};
        position=position+1;ii=ii+1;
    end
end
end
