function graph=oxygen_edge_extender(graph)
%OXYGEN_EDGE_EXTENDER Add missed short O-C and O-H edges to a MoleculeGraph.
if ~isobject(graph)||~ismethod(graph,"get_connected_sites")|| ...
        ~ismethod(graph,"add_edge")||~isprop(graph,"molecule")
    error("KSSOLV:Matgenlab:LocalEnv:GraphsUnavailable", ...
        "oxygen_edge_extender requires a MoleculeGraph-compatible object.");
end
for oxygen=1:graph.molecule.num_sites
    if graph.molecule(oxygen).specie.symbol~="O",continue,end
    connected=graph.get_connected_sites(oxygen);
    indices=connectedIndices(connected);
    for candidate=1:graph.molecule.num_sites
        if candidate==oxygen||any(indices==candidate),continue,end
        symbol=graph.molecule(candidate).specie.symbol;
        distance=graph.molecule(candidate).distance(graph.molecule(oxygen));
        if (symbol=="C"&&distance<1.5)||(symbol=="H"&&distance<1)
            graph=graph.add_edge(oxygen,candidate);
        end
    end
end
end
function indices=connectedIndices(connected)
indices=zeros(1,numel(connected));
for ii=1:numel(connected)
    item=connected{ii};
    indices(ii)=item.index;
end
end
