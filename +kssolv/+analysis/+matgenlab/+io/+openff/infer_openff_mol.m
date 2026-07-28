function openffMol = infer_openff_mol(molGeometry, backend)
%INFER_OPENFF_MOL Infer bonds and orders from a matgenlab Molecule.
if nargin < 2, backend = []; end
if ~isempty(backend) && ...
        kssolv.analysis.matgenlab.io.openff.internal. ...
        backend_has(backend, "infer_openff_mol")
    openffMol = kssolv.analysis.matgenlab.io.openff.internal. ...
        call_backend(backend, "infer_openff_mol", molGeometry);
    return
end
if ~isa(molGeometry, "kssolv.analysis.matgenlab.core.IMolecule")
    error("KSSOLV:Matgenlab:OpenFF:Molecule", ...
        "infer_openff_mol requires a matgenlab Molecule.");
end
strategy = kssolv.analysis.matgenlab.core.OpenBabelNN();
molGraph = kssolv.analysis.matgenlab.core.MoleculeGraph. ...
    from_local_env_strategy(molGeometry, strategy);
molGraph = kssolv.analysis.matgenlab.core.metal_edge_extender(molGraph);
openffMol = kssolv.analysis.matgenlab.io.openff. ...
    mol_graph_to_openff_mol(molGraph, backend);
end
