function [openffMol, atomMap] = add_conformer( ...
        openffMol, geometry, backend)
%ADD_CONFORMER Add geometry coordinates or generate one conformer.
if nargin < 2, geometry = []; end
if nargin < 3, backend = []; end
Native = "kssolv.analysis.matgenlab.io.openff.OpenFFMolecule";
if ~isa(openffMol, Native)
    [openffMol, atomMap] = ...
        kssolv.analysis.matgenlab.io.openff.internal.call_backend( ...
        backend, "add_conformer", openffMol, geometry);
    return
end
if ~isempty(geometry)
    inferred = kssolv.analysis.matgenlab.io.openff. ...
        infer_openff_mol(geometry, backend);
    [isomorphic, atomMap] = kssolv.analysis.matgenlab.io.openff. ...
        get_atom_map(inferred, openffMol);
    if ~isomorphic
        error("KSSOLV:Matgenlab:OpenFF:Isomorphism", ...
            "An isomorphism cannot be found between SMILES '%s' and " + ...
            "the provided molecule.", openffMol.to_smiles());
    end
    openffMol.add_conformer(geometry.cart_coords(atomMap, :));
else
    atomMap = 1:openffMol.n_atoms;
    openffMol.generate_conformers(1);
end
end
