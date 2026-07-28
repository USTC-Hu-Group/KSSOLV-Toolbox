function openffMol = mol_graph_to_openff_mol(molGraph, backend)
%MOL_GRAPH_TO_OPENFF_MOL Convert a MoleculeGraph to an OpenFF molecule.
if nargin < 2, backend = []; end
if ~isempty(backend)
    openffMol = kssolv.analysis.matgenlab.io.openff.internal. ...
        call_backend(backend, "mol_graph_to_openff_mol", molGraph);
    return
end
if ~isa(molGraph, "kssolv.analysis.matgenlab.core.MoleculeGraph")
    error("KSSOLV:Matgenlab:OpenFF:MoleculeGraph", ...
        "mol_graph_to_openff_mol requires a matgenlab MoleculeGraph.");
end

OpenFFMolecule = @kssolv.analysis.matgenlab.io.openff.OpenFFMolecule;
openffMol = OpenFFMolecule();
for index = 1:molGraph.molecule.num_sites
    node = molGraph.graph.nodes{index};
    properties = nodeProperties(node);
    element = kssolv.analysis.matgenlab.core.Element( ...
        molGraph.molecule(index).specie.symbol);
    atomicNumber = fieldOr(properties, "atomic_number", element.Z);
    formalCharge = fieldOr(properties, "formal_charge", []);
    if isempty(formalCharge)
        formalCharge = double(index == 1) * round(molGraph.molecule.charge);
    end
    aromatic = fieldOr(properties, "is_aromatic", false);
    stereo = fieldOr(properties, "stereochemistry", "");
    openffMol.add_atom(atomicNumber, formalCharge, aromatic, stereo);
end

partialCharges = nan(1, openffMol.n_atoms);
for index = 1:openffMol.n_atoms
    properties = nodeProperties(molGraph.graph.nodes{index});
    partialCharges(index) = fieldOr(properties, "partial_charge", NaN);
end
if all(~isnan(partialCharges))
    openffMol.set_partial_charges(partialCharges);
end

for edge = molGraph.graph.edges
    properties = edge.edge_properties;
    order = fieldOr(properties, "bond_order", []);
    if isempty(order)
        if isempty(edge.weight), order = 1; else, order = edge.weight; end
    end
    aromatic = fieldOr(properties, "is_aromatic", false);
    stereo = fieldOr(properties, "stereochemistry", "");
    openffMol.add_bond(edge.from_index, edge.to_index, order, ...
        aromatic, stereo);
end
openffMol.add_conformer(molGraph.molecule.cart_coords);
end

function properties = nodeProperties(node)
properties = struct();
if isfield(node, "properties") && isstruct(node.properties)
    properties = node.properties;
end
names = ["atomic_number", "formal_charge", "is_aromatic", ...
    "stereochemistry", "partial_charge"];
for name = names
    if isfield(node, name)
        properties.(name) = node.(name);
    end
end
end

function value = fieldOr(record, name, fallback)
if isstruct(record) && isfield(record, name)
    value = record.(name);
else
    value = fallback;
end
end
