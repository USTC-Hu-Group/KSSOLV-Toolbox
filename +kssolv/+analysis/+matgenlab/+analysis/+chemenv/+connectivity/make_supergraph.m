function value=make_supergraph(graph,multiplicity,periodicity_vectors)
%MAKE_SUPERGRAPH Replicate a one-periodic graph into a finite ring.
if numel(multiplicity)~=1||size(periodicity_vectors,1)~=1
    error("KSSOLV:Matgenlab:ChemEnv:Supergraph", ...
        "Only one-periodic supergraphs are defined.");
end
mult=double(multiplicity);n=numel(graph.nodes);
value=struct(nodes={repmat(graph.nodes,1,mult)}, ...
    edges=struct("u",{},"v",{},"start",{},"end",{}, ...
    "delta",{},"ligands",{}));
period=periodicity_vectors(1,:);
for copy=0:mult-1
    for edge=graph.edges
        targetCopy=copy;delta=edge.delta;
        if isequal(delta,period),targetCopy=mod(copy+1,mult);
        elseif isequal(delta,-period),targetCopy=mod(copy-1,mult);end
        clone=edge;clone.u=copy*n+edge.u;
        clone.v=targetCopy*n+edge.v;clone.delta=[0 0 0];
        clone.start=clone.u;clone.end=clone.v;
        value.edges(end+1)=clone;
    end
end
end
