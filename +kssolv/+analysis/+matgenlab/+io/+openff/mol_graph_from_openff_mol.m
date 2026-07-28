function molGraph = mol_graph_from_openff_mol(openffMol, backend)
%MOL_GRAPH_FROM_OPENFF_MOL Convert an OpenFF molecule to a MoleculeGraph.
if nargin < 2, backend = []; end
Native = "kssolv.analysis.matgenlab.io.openff.OpenFFMolecule";
if ~isa(openffMol, Native)
    molGraph = kssolv.analysis.matgenlab.io.openff.internal. ...
        call_backend(backend, "mol_graph_from_openff_mol", openffMol);
    return
end

species = strings(1, openffMol.n_atoms);
formalCharges = cell(1, openffMol.n_atoms);
atomicNumbers = cell(1, openffMol.n_atoms);
aromatic = cell(1, openffMol.n_atoms);
stereo = cell(1, openffMol.n_atoms);
partial = cell(1, openffMol.n_atoms);
for index = 1:openffMol.n_atoms
    atom = openffMol.atoms(index);
    species(index) = kssolv.analysis.matgenlab.core. ...
        Element.fromZ(atom.atomic_number).symbol;
    formalCharges{index} = atom.formal_charge;
    atomicNumbers{index} = atom.atomic_number;
    aromatic{index} = atom.is_aromatic;
    stereo{index} = atom.stereochemistry;
    if isempty(openffMol.partial_charges)
        partial{index} = NaN;
    else
        partial{index} = openffMol.partial_charges(index);
    end
end
if isempty(openffMol.conformers)
    coordinates = zeros(openffMol.n_atoms, 3);
else
    coordinates = double(openffMol.conformers{1});
end
siteProperties = struct( ...
    "atomic_number", {atomicNumbers}, ...
    "is_aromatic", {aromatic}, ...
    "stereochemistry", {stereo}, ...
    "partial_charge", {partial}, ...
    "formal_charge", {formalCharges});
molecule = kssolv.analysis.matgenlab.core.Molecule( ...
    species, coordinates, charge = sum(cell2mat(formalCharges)), ...
    charge_spin_check = false, site_properties = siteProperties);
molGraph = kssolv.analysis.matgenlab.core.MoleculeGraph. ...
    from_empty_graph(molecule, "edge_weight_name", "weight", ...
    "edge_weight_units", "");
for bond = openffMol.bonds
    properties = struct("bond_order", bond.bond_order, ...
        "is_aromatic", bond.is_aromatic, ...
        "stereochemistry", bond.stereochemistry);
    molGraph.add_edge(bond.atom1_index, bond.atom2_index, ...
        "weight", bond.bond_order, "edge_properties", properties);
end
end
