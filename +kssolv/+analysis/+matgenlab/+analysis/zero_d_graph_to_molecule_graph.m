function moleculeGraph=zero_d_graph_to_molecule_graph( ...
        bondedStructure,graph)
%ZERO_D_GRAPH_TO_MOLECULE_GRAPH Convert a finite periodic component.
if isa(graph,"kssolv.analysis.matgenlab.core.GraphStore")
    nodes=1:graph.number_of_nodes();
elseif isnumeric(graph)
    nodes=sort(unique(reshape(double(graph),1,[])));
elseif isstruct(graph)&&isfield(graph,"nodes")
    nodes=sort(unique(reshape(double(graph.nodes),1,[])));
else
    error("KSSOLV:Matgenlab:Dimensionality:Graph", ...
        "graph must be component site indices or a GraphStore.");
end
if isempty(nodes)
    error("KSSOLV:Matgenlab:Dimensionality:EmptyComponent", ...
        "The graph component cannot be empty.");
end
dimension=kssolv.analysis.matgenlab.analysis. ...
    calculate_dimensionality_of_site(bondedStructure,nodes(1));
if dimension~=0
    error("KSSOLV:Matgenlab:Dimensionality:NotZeroD", ...
        "Graph component is not zero-dimensional.");
end
seen=false(1,bondedStructure.structure.num_sites);
images=zeros(bondedStructure.structure.num_sites,3);
queueIndices=nodes(1);queueImages=zeros(1,3);
while ~isempty(queueIndices)
    index=queueIndices(1);image=queueImages(1,:);
    queueIndices(1)=[];queueImages(1,:)=[];
    if seen(index)
        if any(images(index,:)~=image)
            error("KSSOLV:Matgenlab:Dimensionality:NotZeroD", ...
                "Graph component is not zero-dimensional.");
        end
        continue
    end
    seen(index)=true;images(index,:)=image;
    connected=bondedStructure.get_connected_sites(index,image);
    for neighborIndex=1:numel(connected)
        neighbor=connected{neighborIndex};
        if ~ismember(neighbor.index,nodes),continue,end
        if ~seen(neighbor.index)
            queueIndices(end+1)=neighbor.index; %#ok<AGROW>
            queueImages(end+1,:)=neighbor.jimage; %#ok<AGROW>
        elseif any(images(neighbor.index,:)~=neighbor.jimage)
            error("KSSOLV:Matgenlab:Dimensionality:NotZeroD", ...
                "Graph component is not zero-dimensional.");
        end
    end
end
ordered=sort(nodes);
species=cell(1,numel(ordered));coordinates=zeros(numel(ordered),3);
for index=1:numel(ordered)
    site=bondedStructure.structure(ordered(index));
    species{index}=site.species;
    coordinates(index,:)=bondedStructure.structure.lattice. ...
        get_cartesian_coords(site.frac_coords+images(ordered(index),:));
end
molecule=kssolv.analysis.matgenlab.core.Molecule(species,coordinates);
moleculeGraph=kssolv.analysis.matgenlab.core.MoleculeGraph. ...
    from_empty_graph(molecule);
mapping=zeros(1,bondedStructure.structure.num_sites);
mapping(ordered)=1:numel(ordered);
for edge=bondedStructure.graph.edges
    if ismember(edge.from_index,ordered)&& ...
            ismember(edge.to_index,ordered)
        moleculeGraph.add_edge(mapping(edge.from_index), ...
            mapping(edge.to_index),"weight",edge.weight, ...
            "edge_properties",edge.edge_properties);
    end
end
end
