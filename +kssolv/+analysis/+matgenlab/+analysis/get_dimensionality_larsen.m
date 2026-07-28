function dimensionality=get_dimensionality_larsen(bondedStructure)
%GET_DIMENSIONALITY_LARSEN Return the largest periodic graph rank.
components=kssolv.analysis.matgenlab.analysis. ...
    get_structure_components(bondedStructure);
if isempty(components)
    error("KSSOLV:Matgenlab:Dimensionality:EmptyGraph", ...
        "A bonded structure must contain at least one site.");
end
dimensionality=max([components.dimensionality]);
end
