function components=get_structure_components(bondedStructure,varargin)
%GET_STRUCTURE_COMPONENTS Describe weakly connected periodic components.
options=struct("inc_orientation",false,"inc_site_ids",false, ...
    "inc_molecule_graph",false);
options=parseOptions(options,varargin);
if ~isa(bondedStructure, ...
        "kssolv.analysis.matgenlab.core.StructureGraph")
    error("KSSOLV:Matgenlab:Dimensionality:StructureGraph", ...
        "bondedStructure must be a StructureGraph.");
end
groups=connectedComponents(bondedStructure.graph.adjacency());
components=struct([]);
for componentIndex=1:numel(groups)
    nodes=sort(groups{componentIndex});
    [dimension,vertices]=kssolv.analysis.matgenlab.analysis. ...
        calculate_dimensionality_of_site( ...
        bondedStructure,nodes(1),true);
    item=struct("dimensionality",dimension);
    if options.inc_orientation
        if dimension==1||dimension==2
            centered=vertices-mean(vertices,1);
            [~,~,rightVectors]=svd(centered,0);
            if dimension==2
                direction=rightVectors(:,end).';
            else
                direction=rightVectors(:,1).';
            end
            item.orientation=kssolv.analysis.matgenlab.core. ...
                get_integer_index(direction);
        else
            item.orientation=[];
        end
    end
    if options.inc_site_ids,item.site_ids=nodes;end
    if options.inc_molecule_graph&&dimension==0
        item.molecule_graph=kssolv.analysis.matgenlab.analysis. ...
            zero_d_graph_to_molecule_graph(bondedStructure,nodes);
    end
    sites=bondedStructure.structure.sites(nodes);
    structure=kssolv.analysis.matgenlab.core.Structure.from_sites(sites);
    graph=kssolv.analysis.matgenlab.core.StructureGraph. ...
        from_empty_graph(structure);
    mapping=zeros(1,bondedStructure.structure.num_sites);
    mapping(nodes)=1:numel(nodes);
    for edge=bondedStructure.graph.edges
        if ismember(edge.from_index,nodes)&& ...
                ismember(edge.to_index,nodes)
            graph.add_edge(mapping(edge.from_index),mapping(edge.to_index), ...
                "from_jimage",edge.from_jimage, ...
                "to_jimage",edge.to_jimage,"weight",edge.weight, ...
                "edge_properties",edge.edge_properties);
        end
    end
    item.structure_graph=graph;
    if componentIndex==1
        components=item;
    else
        components(end+1)=item; %#ok<AGROW>
    end
end
end

function groups=connectedComponents(adjacency)
count=size(adjacency,1);
visited=false(1,count);
groups={};
for start=1:count
    if visited(start),continue,end
    queue=start;visited(start)=true;nodes=[];
    while ~isempty(queue)
        current=queue(1);queue(1)=[];nodes(end+1)=current; %#ok<AGROW>
        neighbors=find(adjacency(current,:)~=0);
        unseen=neighbors(~visited(neighbors));
        visited(unseen)=true;queue=[queue,unseen]; %#ok<AGROW>
    end
    groups{end+1}=nodes; %#ok<AGROW>
end
end

function output=parseOptions(output,input)
names=fieldnames(output);position=1;index=1;
while index<=numel(input)
    if (ischar(input{index})||isstring(input{index}))&& ...
            any(strcmpi(string(input{index}),string(names)))
        match=find(strcmpi(string(input{index}),string(names)),1);
        output.(names{match})=input{index+1};index=index+2;
    else
        output.(names{position})=input{index};
        position=position+1;index=index+1;
    end
end
end
