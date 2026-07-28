classdef StructureGraph < handle
    %STRUCTUREGRAPH Attributed periodic multigraph associated with a Structure.
    properties
        structure
        graph (1,1) kssolv.analysis.matgenlab.core.GraphStore
    end
    properties (Dependent,SetAccess=private)
        name
        edge_weight_name
        edge_weight_unit
        types_and_weights_of_connections
        weight_statistics
    end
    methods
        function obj=StructureGraph(structure,graph_data)
            if isa(structure,"kssolv.analysis.matgenlab.core.StructureGraph")
                copy=structure;obj.structure=copy.structure.copy();
                obj.graph=copy.graph.copy();return
            end
            obj.structure=structure;
            if nargin<2||isempty(graph_data)
                obj.graph=kssolv.analysis.matgenlab.core.GraphStore( ...
                    structure.num_sites);
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
        function value=get.types_and_weights_of_connections(obj)
            grouped=containers.Map("KeyType","char","ValueType","any");
            for edge=obj.graph.edges
                symbols=sort([obj.structure(edge.from_index).species_string, ...
                    obj.structure(edge.to_index).species_string]);
                key=char(strjoin(symbols,"-"));
                if isKey(grouped,key)
                    weights=grouped(key);
                else
                    weights={};
                end
                weights{end+1}=edge.weight; %#ok<AGROW>
                grouped(key)=weights;
            end
            value=containers.Map("KeyType","char","ValueType","any");
            keys=grouped.keys;
            for ii=1:numel(keys)
                weights=grouped(keys{ii});
                if all(cellfun(@(item)isnumeric(item)&&isscalar(item),weights))
                    value(keys{ii})=cell2mat(weights);
                else
                    value(keys{ii})=weights;
                end
            end
        end
        function value=get.weight_statistics(obj)
            weights=[];
            for edge=obj.graph.edges
                if ~isempty(edge.weight),weights(end+1)=edge.weight;end %#ok<AGROW>
            end
            if isempty(weights)
                value=struct(all_weights=[],min=NaN,max=NaN, ...
                    mean=NaN,variance=NaN);
            else
                value=struct(all_weights=weights,min=min(weights), ...
                    max=max(weights),mean=mean(weights), ...
                    variance=var(weights,0));
            end
        end
        function obj=add_edge(obj,from_index,to_index,varargin)
            options=struct(from_jimage=[0,0,0],to_jimage=[],weight=[], ...
                warn_duplicates=true,edge_properties=struct());
            options=parseOptions(options,varargin);
            validateNode(obj,from_index);validateNode(obj,to_index);
            fromImage=reshape(double(options.from_jimage),1,3);
            if isempty(options.to_jimage)
                obj=autoImages(obj,from_index,to_index,options);return
            end
            toImage=reshape(double(options.to_jimage),1,3);
            if to_index<from_index
                [from_index,to_index]=deal(to_index,from_index);
                [fromImage,toImage]=deal(toImage,fromImage);
            end
            toImage=round(toImage-fromImage);fromImage=[0,0,0];
            if from_index==to_index
                if all(toImage==0),return,end
                first=find(toImage~=0,1);
                if toImage(first)<0,toImage=-toImage;end
            end
            for edge=obj.graph.edges
                if edge.from_index==from_index&&edge.to_index==to_index&& ...
                        isequal(edge.to_jimage,toImage)
                    return
                end
            end
            props=options.edge_properties;if isempty(props),props=struct();end
            obj.graph.add_edge(from_index,to_index,"from_jimage",fromImage, ...
                "to_jimage",toImage,"weight",options.weight, ...
                "edge_properties",props);
        end
        function obj=insert_node(obj,index,species,coords,varargin)
            options=struct(coords_are_cartesian=false,validate_proximity=false, ...
                site_properties=struct(),edges=[]);
            options=parseOptions(options,varargin);
            obj.structure=obj.structure.insert(index,species,coords, ...
                coords_are_cartesian=options.coords_are_cartesian, ...
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
            obj.graph.nodes=[obj.graph.nodes(1:index-1),{struct()}, ...
                obj.graph.nodes(index:end)];
            obj.set_node_attributes();
            obj=addSpecifiedEdges(obj,options.edges,true);
        end
        function obj=set_node_attributes(obj)
            obj.graph.nodes=cell(1,obj.structure.num_sites);
            for ii=1:obj.structure.num_sites
                site=obj.structure(ii);
                obj.graph.nodes{ii}=struct(specie=site.specie.symbol, ...
                    coords=site.coords,properties=site.site_properties);
            end
        end
        function obj=alter_edge(obj,from_index,to_index,varargin)
            options=struct(to_jimage=[],new_weight=[],new_edge_properties=[]);
            options=parseOptions(options,varargin);
            which=findEdges(obj,from_index,to_index,options.to_jimage);
            if isempty(which),error("KSSOLV:Matgenlab:StructureGraph:MissingEdge", ...
                    "Edge between the requested sites does not exist.");end
            which=which(1);
            if ~isempty(options.new_weight)
                obj.graph.edges(which).weight=options.new_weight;
            end
            if ~isempty(options.new_edge_properties)
                old=obj.graph.edges(which).edge_properties;
                names=fieldnames(options.new_edge_properties);
                for ii=1:numel(names)
                    old.(names{ii})=options.new_edge_properties.(names{ii});
                end
                obj.graph.edges(which).edge_properties=old;
            end
        end
        function obj=break_edge(obj,from_index,to_index,varargin)
            options=struct(to_jimage=[],allow_reverse=false);
            options=parseOptions(options,varargin);
            if isempty(options.to_jimage)
                error("KSSOLV:Matgenlab:StructureGraph:ImageRequired", ...
                    "Image must be supplied, to avoid ambiguity.");
            end
            which=findEdges(obj,from_index,to_index,options.to_jimage);
            if isempty(which)&&options.allow_reverse
                which=findEdges(obj,to_index,from_index,-options.to_jimage);
            end
            if isempty(which),error("KSSOLV:Matgenlab:StructureGraph:MissingEdge", ...
                    "Edge cannot be broken because it does not exist.");end
            obj.graph.remove_edge(which(1));
        end
        function obj=remove_nodes(obj,indices)
            indices=sort(unique(reshape(indices,1,[])));
            keep=~ismember(1:obj.structure.num_sites,indices);
            mapping=zeros(1,obj.structure.num_sites);mapping(keep)=1:sum(keep);
            edgeKeep=true(1,numel(obj.graph.edges));
            for ii=1:numel(obj.graph.edges)
                edge=obj.graph.edges(ii);
                if ~keep(edge.from_index)||~keep(edge.to_index)
                    edgeKeep(ii)=false;
                else
                    obj.graph.edges(ii).from_index=mapping(edge.from_index);
                    obj.graph.edges(ii).to_index=mapping(edge.to_index);
                end
            end
            obj.graph.edges=obj.graph.edges(edgeKeep);
            obj.structure=obj.structure.remove_sites(indices);
            obj.set_node_attributes();
        end
        function obj=substitute_group(obj,index,func_grp,strategy,varargin)
            options=struct(bond_order=1,graph_dict=[],strategy_params=struct());
            options=parseOptions(options,varargin);
            [group,groupEdges]=structureFunctionalGroup( ...
                func_grp,options.graph_dict,strategy);
            connected=obj.get_connected_sites(index);
            if isempty(connected)
                error("KSSOLV:Matgenlab:StructureGraph:FunctionalGroup", ...
                    "Attachment site must have a connected neighbor.");
            end
            anchor=connected{1}.index;
            anchorCoords=obj.structure(anchor).coords;
            oldCoords=obj.structure(index).coords;
            rotation=alignVectors(group(2).coords-group(1).coords, ...
                oldCoords-anchorCoords);
            transformed=(group.cart_coords-group(1).coords)*rotation.'+anchorCoords;
            obj.structure=obj.structure.replace(index,group(2).species, ...
                transformed(2,:),coords_are_cartesian=true, ...
                properties=group(2).site_properties,label=group(2).label);
            keep=arrayfun(@(e)~(e.from_index==index||e.to_index==index), ...
                obj.graph.edges);obj.graph.edges=obj.graph.edges(keep);
            obj.add_edge(anchor,index,"to_jimage",[0,0,0]);
            mapping=zeros(1,group.num_sites);mapping(2)=index;
            for ii=3:group.num_sites
                obj.structure=obj.structure.append(group(ii).species, ...
                    transformed(ii,:),coords_are_cartesian=true, ...
                    properties=group(ii).site_properties);
                mapping(ii)=obj.structure.num_sites;
            end
            for ii=1:size(groupEdges,1)
                if any(groupEdges(ii,1:2)==1),continue,end
                obj.add_edge(mapping(groupEdges(ii,1)),mapping(groupEdges(ii,2)), ...
                    "to_jimage",[0,0,0]);
            end
            obj.set_node_attributes();
        end
        function connected=get_connected_sites(obj,n,jimage)
            if nargin<3,jimage=[0,0,0];end
            validateNode(obj,n);jimage=reshape(double(jimage),1,3);
            connected={};seen=strings(1,0);
            for edge=obj.graph.edges
                candidates={};
                if edge.from_index==n
                    candidates{end+1}={edge.to_index,jimage+edge.to_jimage,edge}; %#ok<AGROW>
                end
                if edge.to_index==n
                    candidates{end+1}={edge.from_index,jimage-edge.to_jimage,edge}; %#ok<AGROW>
                end
                for cc=1:numel(candidates)
                    item=candidates{cc};index=item{1};image=item{2};e=item{3};
                    key=string(index)+":"+join(string(image),",");
                    if any(seen==key),continue,end
                    seen(end+1)=key; %#ok<AGROW>
                    original=obj.structure(index);
                    site=kssolv.analysis.matgenlab.core.PeriodicSite( ...
                        original.species,original.frac_coords+image, ...
                        obj.structure.lattice,properties=original.site_properties, ...
                        label=original.label);
                    distance=norm(site.coords- ...
                        obj.structure.lattice.get_cartesian_coords( ...
                        obj.structure(n).frac_coords+jimage));
                    connected{end+1}=kssolv.analysis.matgenlab.core. ...
                        ConnectedSite(site,image,index,e.weight,distance); %#ok<AGROW>
                end
            end
            if ~isempty(connected)
                [~,order]=sort(cellfun(@(x)x.dist,connected));connected=connected(order);
            end
        end
        function value=get_coordination_of_site(obj,n)
            value=numel(obj.get_connected_sites(n));
        end
        function filename=draw_graph_to_file(obj,filename,varargin)
            if nargin<2||strlength(string(filename))==0,filename="graph.dot";end
            options=struct(diff=[],hide_unconnected_nodes=false, ...
                hide_image_edges=true,edge_colors=false,node_labels=false, ...
                weight_labels=false,image_labels=false,color_scheme="VESTA", ...
                keep_dot=false,algo="fdp");
            options=parseOptions(options,varargin);
            [folder,baseName,extension]=fileparts(string(filename));
            if strlength(extension)==0,extension=".dot";filename=filename+extension;end
            dotPath=string(filename);
            if extension~=".dot",dotPath=fullfile(folder,baseName+".dot");end
            writeDot(obj,dotPath,options);
            if extension~=".dot"
                executable=char(options.algo);
                [status,~]=system(sprintf('command -v %s',executable));
                if status~=0,error("KSSOLV:Matgenlab:StructureGraph:GraphViz", ...
                        "GraphViz executable '%s' is unavailable.",executable);end
                command=sprintf('\"%s\" -T%s \"%s\" -o \"%s\"', ...
                    executable,extractAfter(extension,1),dotPath,filename);
                [status,message]=system(command);
                if status~=0,error("KSSOLV:Matgenlab:StructureGraph:GraphViz",message);end
                if ~options.keep_dot,delete(dotPath);end
            end
        end
        function value=types_of_coordination_environments(obj,anonymous)
            if nargin<2,anonymous=false;end
            descriptions=strings(1,obj.structure.num_sites);
            for ii=1:obj.structure.num_sites
                center=obj.structure(ii).species_string;
                sites=obj.get_connected_sites(ii);
                syms=string(cellfun(@(x)x.site.species_string,sites, ...
                    "UniformOutput",false));
                uniqueSymbols=unique(syms);
                counts=arrayfun(@(symbol)sum(syms==symbol),uniqueSymbols);
                orderingTable=table(-counts.',uniqueSymbols.', ...
                    VariableNames=["counts","symbols"]);
                [~,order]=sortrows(orderingTable,["counts","symbols"], ...
                    ["ascend","descend"]);
                uniqueSymbols=uniqueSymbols(order);counts=counts(order);
                if anonymous
                    replacements=containers.Map("KeyType","char","ValueType","char");
                    replacements(char(center))="A";
                    nextLetter=double('B');
                    for jj=1:numel(uniqueSymbols)
                        symbol=char(uniqueSymbols(jj));
                        if ~isKey(replacements,symbol)
                            replacements(symbol)=char(nextLetter);
                            nextLetter=nextLetter+1;
                        end
                        uniqueSymbols(jj)=string(replacements(symbol));
                    end
                    center="A";
                end
                pieces=uniqueSymbols+"("+string(counts)+")";
                descriptions(ii)=center+"-"+join(pieces,",");
            end
            value=cellstr(unique(descriptions));
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.core.graphs", ...
                x_class="StructureGraph",structure=obj.structure.as_dict(), ...
                graphs=obj.graph.as_struct());
        end
        function value=asDict(obj),value=obj.as_dict();end
        function text=toJSON(obj,varargin)
            text=kssolv.analysis.matgenlab.util.encode(obj.as_dict(),varargin{:});
        end
        function obj=sort(obj,key,reverse)
            if nargin<2,key=[];end;if nargin<3,reverse=false;end
            oldSites=obj.structure.sites;
            sorted=obj.structure.get_sorted_structure(key,reverse);
            mapping=zeros(1,numel(oldSites));
            used=false(1,numel(oldSites));
            for old=1:numel(oldSites)
                for new=1:numel(oldSites)
                    if ~used(new)&&sameSite(oldSites{old},sorted(new))
                        mapping(old)=new;used(new)=true;break
                    end
                end
            end
            for ii=1:numel(obj.graph.edges)
                obj.graph.edges(ii).from_index=mapping(obj.graph.edges(ii).from_index);
                obj.graph.edges(ii).to_index=mapping(obj.graph.edges(ii).to_index);
                obj.graph.edges(ii)=canonicalEdge(obj.graph.edges(ii));
            end
            obj.structure=sorted;obj.set_node_attributes();
        end
        function value=diff(obj,other,strict)
            if nargin<3,strict=true;end
            if strict
                mapping=structureSiteMapping(obj.structure,other.structure);
                if isempty(mapping)
                    error("KSSOLV:Matgenlab:StructureGraph:Diff", ...
                        "Meaningless to compare StructureGraphs if " + ...
                        "corresponding Structures are different.");
                end
                first=edgeLabelsMapped(obj,1:obj.structure.num_sites);
                second=edgeLabelsMapped(other,mapping);
            else
                first=edgeLabels(obj,false);
                second=edgeLabels(other,false);
            end
            both=intersect(first,second);onlyFirst=setdiff(first,second);
            onlySecond=setdiff(second,first);den=numel(union(first,second));
            distance=0;if den>0,distance=1-numel(both)/den;end
            value=struct(dist=distance,self={cellstr(onlyFirst)}, ...
                other={cellstr(onlySecond)},both={cellstr(both)});
        end
        function molecules=get_subgraphs_as_molecules(obj,use_weights)
            if nargin<2,use_weights=false;end
            supercell=obj*[3,3,3];
            components=connectedComponents(supercell.graph.adjacency());
            molecules={};
            for component=components
                nodes=component{1};
                internal=arrayfun(@(e)ismember(e.from_index,nodes)&& ...
                    ismember(e.to_index,nodes),supercell.graph.edges);
                if any(arrayfun(@(e)any(e.to_jimage~=0), ...
                        supercell.graph.edges(internal)))
                    continue
                end
                sites=supercell.structure.sites(nodes);
                molecule=kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                    cellfun(@(s)kssolv.analysis.matgenlab.core.Site( ...
                    s.species,s.coords,properties=s.site_properties,label=s.label), ...
                    sites,"UniformOutput",false));
                edgeList=supercell.graph.edges(internal);edges=cell(size(edgeList));
                for ii=1:numel(edgeList)
                    properties=edgeList(ii).edge_properties;
                    if ~isempty(edgeList(ii).weight)
                        properties.weight=edgeList(ii).weight;
                    end
                    edges{ii}={find(nodes==edgeList(ii).from_index), ...
                        find(nodes==edgeList(ii).to_index),properties};
                end
                mg=kssolv.analysis.matgenlab.core.MoleculeGraph.from_edges( ...
                    molecule,edges);
                if ~any(cellfun(@(x)moleculeGraphsIsomorphic( ...
                        x,mg,use_weights),molecules))
                    molecules{end+1}=mg; %#ok<AGROW>
                end
            end
            molecules=cellfun(@(x)x.molecule.get_centered_molecule(), ...
                molecules,"UniformOutput",false);
        end
        function value=mtimes(obj,scaling)
            if ~isa(obj,"kssolv.analysis.matgenlab.core.StructureGraph")
                [obj,scaling]=deal(scaling,obj);
            end
            value=supercellGraph(obj,scaling);
        end
        function tf=eq(obj,other)
            tf=false;
            if ~isa(other,"kssolv.analysis.matgenlab.core.StructureGraph"),return,end
            try
                tf=obj.diff(other,true).dist==0;
            catch
                tf=false;
            end
        end
        function tf=ne(obj,other),tf=~eq(obj,other);end
        function n=length(obj),n=obj.structure.num_sites;end
        function text=char(obj)
            text=sprintf("Structure Graph: %s, %d nodes, %d edges", ...
                obj.name,obj.graph.number_of_nodes(),obj.graph.number_of_edges());
        end
    end
    methods (Static)
        function obj=from_empty_graph(structure,varargin)
            options=struct(name="bonds",edge_weight_name=[], ...
                edge_weight_units=[]);options=parseOptions(options,varargin);
            if ~isempty(options.edge_weight_name)&&isempty(options.edge_weight_units)
                error("KSSOLV:Matgenlab:StructureGraph:WeightUnits", ...
                    "Please specify units associated with edge weights.");
            end
            attrs=struct(name=options.name, ...
                edge_weight_name=options.edge_weight_name, ...
                edge_weight_units=options.edge_weight_units);
            store=kssolv.analysis.matgenlab.core.GraphStore( ...
                structure.num_sites,attrs);
            obj=kssolv.analysis.matgenlab.core.StructureGraph(structure,store);
        end
        function obj=with_empty_graph(varargin)
            obj=kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_empty_graph(varargin{:});
        end
        function obj=from_edges(structure,edges)
            obj=kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_empty_graph(structure,"edge_weight_name","weight", ...
                "edge_weight_units","");
            entries=normalizeStructureEdges(edges);
            for ii=1:numel(entries)
                e=entries{ii};obj.add_edge(e.from_index,e.to_index, ...
                    "from_jimage",e.from_jimage,"to_jimage",e.to_jimage, ...
                    "weight",e.weight,"edge_properties",e.properties);
            end
        end
        function obj=with_edges(varargin)
            obj=kssolv.analysis.matgenlab.core.StructureGraph.from_edges(varargin{:});
        end
        function obj=from_local_env_strategy(structure,strategy,varargin)
            options=struct(weights=false,edge_properties=false);
            options=parseOptions(options,varargin);
            if ~strategy.structures_allowed
                error("KSSOLV:Matgenlab:StructureGraph:Strategy", ...
                    "Chosen strategy is not designed for use with structures.");
            end
            obj=kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_empty_graph(structure);
            allInfo=strategy.get_all_nn_info(structure);
            for ii=1:numel(allInfo)
                for jj=1:numel(allInfo{ii})
                    info=allInfo{ii}{jj};weight=[];
                    if options.weights,weight=info.weight;end
                    props=struct();
                    if options.edge_properties&&isfield(info,"edge_properties")
                        props=info.edge_properties;
                    end
                    obj.add_edge(ii,info.site_index,"to_jimage",info.image, ...
                        "weight",weight,"warn_duplicates",false, ...
                        "edge_properties",props);
                end
            end
        end
        function obj=with_local_env_strategy(varargin)
            obj=kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_local_env_strategy(varargin{:});
        end
        function obj=from_dict(value)
            structure=kssolv.analysis.matgenlab.core.Structure.from_dict(value.structure);
            obj=kssolv.analysis.matgenlab.core.StructureGraph( ...
                structure,value.graphs);
        end
        function obj=fromDict(value),obj=kssolv.analysis.matgenlab.core.StructureGraph.from_dict(value);end
    end
end

function validateNode(obj,index)
if index<1||index>obj.structure.num_sites||index~=fix(index)
    error("KSSOLV:Matgenlab:StructureGraph:Node","Node index is out of bounds.");
end
end
function obj=autoImages(obj,fromIndex,toIndex,options)
first=obj.structure(fromIndex);second=obj.structure(toIndex);
[minimum,~]=obj.structure.lattice.get_distance_and_image( ...
    first.frac_coords,second.frac_coords);
if minimum<=1e-12
    unitImages=eye(3);
    distances=zeros(1,3);
    for ii=1:3
        distances(ii)=obj.structure.lattice.get_distance_and_image( ...
            first.frac_coords,first.frac_coords,unitImages(ii,:));
    end
    minimum=min(distances);
end
neighbors=obj.structure.get_neighbors_in_shell( ...
    first.coords,minimum,max(1e-8,.01*minimum),true,true);
for ii=1:numel(neighbors)
    neighbor=neighbors{ii};
    if neighbor.index~=toIndex,continue,end
    obj.add_edge(fromIndex,toIndex,"to_jimage",neighbor.image, ...
        "weight",options.weight,"warn_duplicates",false, ...
        "edge_properties",options.edge_properties);
end
end
function which=findEdges(obj,first,second,image)
which=[];
for ii=1:numel(obj.graph.edges)
    e=obj.graph.edges(ii);
    if e.from_index==first&&e.to_index==second&& ...
            (isempty(image)||isequal(e.to_jimage,reshape(image,1,3)))
        which(end+1)=ii; %#ok<AGROW>
    end
end
end
function edge=canonicalEdge(edge)
if edge.to_index<edge.from_index
    [edge.from_index,edge.to_index]=deal(edge.to_index,edge.from_index);
    edge.to_jimage=-edge.to_jimage;
end
if edge.from_index==edge.to_index
    first=find(edge.to_jimage~=0,1);
    if ~isempty(first)&&edge.to_jimage(first)<0,edge.to_jimage=-edge.to_jimage;end
end
edge.from_jimage=[0,0,0];
end
function labels=edgeLabels(obj,strict)
labels=strings(1,numel(obj.graph.edges));
for ii=1:numel(obj.graph.edges)
    e=obj.graph.edges(ii);
    if strict
        labels(ii)=e.from_index+"-"+e.to_index+"@"+join(string(e.to_jimage),",");
    else
        pair=sort([obj.structure(e.from_index).species_string, ...
            obj.structure(e.to_index).species_string]);
        labels(ii)=pair(1)+"-"+pair(2);
    end
end
labels=unique(labels);
end
function labels=edgeLabelsMapped(obj,mapping)
labels=strings(1,numel(obj.graph.edges));
for ii=1:numel(obj.graph.edges)
    edge=obj.graph.edges(ii);
    edge.from_index=mapping(edge.from_index);
    edge.to_index=mapping(edge.to_index);
    edge=canonicalEdge(edge);
    labels(ii)=edge.from_index+"-"+edge.to_index+"@"+ ...
        join(string(edge.to_jimage),",");
end
labels=unique(labels);
end
function mapping=structureSiteMapping(reference,candidate)
mapping=[];
if reference.num_sites~=candidate.num_sites||reference.lattice~=candidate.lattice
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
function tf=moleculeGraphsIsomorphic(first,second,useWeights)
n=first.molecule.num_sites;
if n~=second.molecule.num_sites||first.graph.number_of_edges()~= ...
        second.graph.number_of_edges()
    tf=false;return
end
adjacencyA=first.graph.adjacency();adjacencyB=second.graph.adjacency();
labelsA=string(cellfun(@(site)site.species_string,first.molecule.sites, ...
    UniformOutput=false));
labelsB=string(cellfun(@(site)site.species_string,second.molecule.sites, ...
    UniformOutput=false));
if ~isequal(sort(labelsA),sort(labelsB)),tf=false;return,end
degreeA=sum(adjacencyA,2).';degreeB=sum(adjacencyB,2).';
mapping=zeros(1,n);used=false(1,n);
[~,order]=sort(degreeA,"descend");tf=search(1);
    function success=search(position)
        if position>n,success=true;return,end
        node=order(position);
        candidates=find(~used&labelsB==labelsA(node)&degreeB==degreeA(node));
        success=false;
        for candidate=candidates
            consistent=true;
            for previous=1:n
                mapped=mapping(previous);
                if mapped==0,continue,end
                if adjacencyA(node,previous)~=adjacencyB(candidate,mapped)
                    consistent=false;break
                end
                if useWeights&&adjacencyA(node,previous)>0&& ...
                        ~isequaln(edgeWeight(first,node,previous), ...
                        edgeWeight(second,candidate,mapped))
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
function value=edgeWeight(graph,first,second)
firstNode=min(first,second);secondNode=max(first,second);value=[];
for edge=graph.graph.edges
    if edge.from_index==firstNode&&edge.to_index==secondNode
        value=edge.weight;return
    end
end
end
function tf=sameSite(a,b)
tf=a.species_string==b.species_string&&norm(a.coords-b.coords)<1e-8;
end
function obj=addSpecifiedEdges(obj,edges,periodic)
if isempty(edges),return,end
if isstruct(edges),entries=num2cell(edges);elseif iscell(edges),entries=edges;else,return,end
for ii=1:numel(entries)
    e=entries{ii};args={};
    if isfield(e,"weight"),args=[args,{"weight",e.weight}];end %#ok<AGROW>
    if isfield(e,"properties"),args=[args,{"edge_properties",e.properties}];end %#ok<AGROW>
    if periodic
        image=[0,0,0];if isfield(e,"to_jimage"),image=e.to_jimage;end
        args=[args,{"to_jimage",image}]; %#ok<AGROW>
    end
    obj.add_edge(e.from_index,e.to_index,args{:});
end
end
function store=storeFromStruct(value)
attrs=value.attributes;
store=kssolv.analysis.matgenlab.core.GraphStore(0,attrs);
nodes=value.nodes;if isstruct(nodes),nodes=num2cell(nodes);end;store.nodes=nodes;
edges=value.edges;if iscell(edges),edges=[edges{:}];end;store.edges=edges;
end
function entries=normalizeStructureEdges(edges)
entries={};
if isempty(edges),return,end
if isnumeric(edges)
    if size(edges,2)~=2&&size(edges,2)~=8
        error("KSSOLV:Matgenlab:StructureGraph:Edges", ...
            "Numeric edge data must have 2 or 8 columns.");
    end
    raw=num2cell(edges,2);
elseif iscell(edges)
    if size(edges,2)==1
        raw=edges;
    elseif size(edges,2)>=2
        raw=cell(size(edges,1),1);
        for ii=1:size(edges,1)
            raw{ii}=edges(ii,:);
        end
    else
        raw={edges};
    end
elseif isstruct(edges)
    if all(isfield(edges,{"from_index","to_index"}))
        raw=num2cell(edges);
    else
        raw={};names=fieldnames(edges);
        for ii=1:numel(names)
            raw{end+1}=edges.(names{ii}); %#ok<AGROW>
        end
    end
else
    error("KSSOLV:Matgenlab:StructureGraph:Edges","Unsupported edge data.");
end
for ii=1:numel(raw)
    item=raw{ii};props=struct();weight=[];
    if isstruct(item)
        e=item;
        if isfield(e,"properties"),props=e.properties;end
        if isfield(e,"weight"),weight=e.weight;end
        from=e.from_index;to=e.to_index;
        fromImage=[0,0,0];toImage=[0,0,0];
        if isfield(e,"from_jimage"),fromImage=e.from_jimage;end
        if isfield(e,"to_jimage"),toImage=e.to_jimage;end
    elseif isnumeric(item)
        from=item(1);to=item(2);fromImage=[0,0,0];toImage=[0,0,0];
        if numel(item)==8
            fromImage=item(3:5);toImage=item(6:8);
        end
    else
        from=item{1};to=item{2};fromImage=[0,0,0];toImage=[0,0,0];
        if numel(item)>=4
            fromImage=item{3};toImage=item{4};
        end
        propertiesIndex=5;
        if numel(item)==3&&isstruct(item{3}),propertiesIndex=3;end
        if numel(item)>=propertiesIndex&&isstruct(item{propertiesIndex})
            props=item{propertiesIndex};
            if isfield(props,"weight")
                weight=props.weight;props=rmfield(props,"weight");
            end
        end
    end
    entries{end+1}=struct(from_index=from,to_index=to, ...
        from_jimage=fromImage,to_jimage=toImage,weight=weight, ...
        properties=props); %#ok<AGROW>
end
end
function components=connectedComponents(adjacency)
n=size(adjacency,1);seen=false(1,n);components={};
for start=1:n
    if seen(start),continue,end
    queue=start;seen(start)=true;component=[];
    while ~isempty(queue)
        node=queue(1);queue(1)=[];component(end+1)=node; %#ok<AGROW>
        next=find(adjacency(node,:)>0&~seen);
        seen(next)=true;queue=[queue,next]; %#ok<AGROW>
    end
    components{end+1}=component; %#ok<AGROW>
end
end
function value=supercellGraph(obj,scaling)
if isscalar(scaling)
    matrix=eye(3)*scaling;
elseif isvector(scaling)&&numel(scaling)==3
    matrix=diag(scaling);
else
    matrix=double(scaling);
end
newStructure=obj.structure*matrix;
points=kssolv.analysis.matgenlab.util.lattice_points_in_supercell(matrix);
translations=round(points*matrix);multiplicity=size(points,1);
value=kssolv.analysis.matgenlab.core.StructureGraph.from_empty_graph( ...
    newStructure,"name",obj.name,"edge_weight_name",obj.edge_weight_name, ...
    "edge_weight_units",obj.edge_weight_unit);
for edge=obj.graph.edges
    for qq=1:multiplicity
        source=(edge.from_index-1)*multiplicity+qq;
        raw=(obj.structure(edge.to_index).frac_coords+translations(qq,:)+ ...
            edge.to_jimage)/matrix;
        wrapped=mod(raw,1);best=Inf;dest=0;
        for rr=1:multiplicity
            candidate=mod((obj.structure(edge.to_index).frac_coords+ ...
                translations(rr,:))/matrix,1);
            error_=norm(mod(candidate-wrapped+.5,1)-.5);
            if error_<best,best=error_;dest=(edge.to_index-1)*multiplicity+rr;end
        end
        image=round(raw-newStructure(dest).frac_coords);
        value.add_edge(source,dest,"to_jimage",image,"weight",edge.weight, ...
            "warn_duplicates",false,"edge_properties",edge.edge_properties);
    end
end
end
function writeDot(obj,path,options)
fid=fopen(path,"w");cleaner=onCleanup(@()fclose(fid));
fprintf(fid,"graph G {\n");
connected=false(1,obj.structure.num_sites);
for edge=obj.graph.edges
    if options.hide_image_edges&&any(edge.to_jimage~=0),continue,end
    connected([edge.from_index,edge.to_index])=true;
    label="";
    if options.weight_labels&&~isempty(edge.weight),label=string(edge.weight);end
    if options.image_labels,label=label+" "+mat2str(edge.to_jimage);end
    fprintf(fid,'  n%d -- n%d [label=\"%s\"];\n', ...
        edge.from_index,edge.to_index,label);
end
for ii=1:obj.structure.num_sites
    if options.hide_unconnected_nodes&&~connected(ii),continue,end
    label=string(obj.structure(ii).specie.symbol);
    if options.node_labels,label=label+"("+ii+")";end
    fprintf(fid,'  n%d [label=\"%s\"];\n',ii,label);
end
fprintf(fid,"}\n");
end
function [group,edges]=structureFunctionalGroup(input,graphData,strategy)
if isa(input,"kssolv.analysis.matgenlab.core.MoleculeGraph")
    group=input.molecule;edges=zeros(input.graph.number_of_edges(),2);
    for ii=1:numel(input.graph.edges)
        edges(ii,:)=[input.graph.edges(ii).from_index,input.graph.edges(ii).to_index];
    end
elseif isa(input,"kssolv.analysis.matgenlab.core.IMolecule")
    group=input;edges=[];
elseif ischar(input)||isstring(input)
    databasePath=fullfile(fileparts(mfilename("fullpath")), ...
        "+data","func_groups.json");
    database=jsondecode(fileread(databasePath));
    key=char(lower(string(input)));
    if ~isfield(database,key)
        error("KSSOLV:Matgenlab:StructureGraph:FunctionalGroup", ...
            "Unknown functional group '%s'.",string(input));
    end
    record=database.(key);
    group=kssolv.analysis.matgenlab.core.Molecule( ...
        cellstr(string(record.species)),double(record.coords));
    edges=[];
else
    error("KSSOLV:Matgenlab:StructureGraph:FunctionalGroup", ...
        "Unknown functional-group representation.");
end
if ~isempty(graphData)
    if isnumeric(graphData),edges=graphData;
    elseif iscell(graphData),edges=cell2mat(graphData(:,1:2));end
elseif isempty(edges)
    try
        finder=strategy();info=finder.get_all_nn_info(group);edges=[];
        for ii=1:numel(info)
            for jj=1:numel(info{ii})
                a=min(ii,info{ii}{jj}.site_index);
                b=max(ii,info{ii}{jj}.site_index);
                if a~=b,edges(end+1,:)=[a,b];end %#ok<AGROW>
            end
        end
        edges=unique(edges,"rows");
    catch
        edges=[1,2];
    end
end
end
function rotation=alignVectors(first,second)
first=first/norm(first);second=second/norm(second);axis=cross(first,second);
c=max(-1,min(1,dot(first,second)));
if norm(axis)<1e-12
    if c>0,rotation=eye(3);else
        basis=null(first).';axis=basis(1,:);K=skew(axis);
        rotation=eye(3)+2*K*K;
    end
else
    axis=axis/norm(axis);K=skew(axis);
    rotation=eye(3)+sqrt(max(0,1-c^2))*K+(1-c)*K*K;
end
end
function K=skew(v),K=[0,-v(3),v(2);v(3),0,-v(1);-v(2),v(1),0];end
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
