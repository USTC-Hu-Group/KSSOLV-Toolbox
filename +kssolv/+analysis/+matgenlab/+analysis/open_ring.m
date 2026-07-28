function graph = open_ring(mol_graph, bond, opt_steps, backend)
%OPEN_RING Remove a ring bond and optionally optimize through a Babel seam.
if nargin < 3 || isempty(opt_steps), opt_steps = 10000; end
if nargin < 4, backend = []; end
if ~isa(mol_graph, "kssolv.analysis.matgenlab.core.MoleculeGraph")
    error("KSSOLV:Matgenlab:Fragmenter:MoleculeGraph", ...
        "mol_graph must be a MoleculeGraph.");
end
if iscell(bond), bond = bond{1}; end
bond = reshape(double(bond), 1, []);
if numel(bond) ~= 2
    error("KSSOLV:Matgenlab:Fragmenter:Bond", ...
        "bond must identify exactly two sites.");
end
if isempty(backend)
    % Native topology-preserving fallback: opening a ring means removing the
    % selected edge. Coordinates remain a deterministic initial geometry.
    graph = kssolv.analysis.matgenlab.core.MoleculeGraph(mol_graph);
    graph.break_edge(bond(1), bond(2), "allow_reverse", true);
    return
end
adaptor = kssolv.analysis.matgenlab.io.babel. ...
    BabelMolAdaptor.from_molecule_graph(mol_graph, backend);
adaptor.remove_bond(bond(1), bond(2));
adaptor.localopt("uff", opt_steps);
graph = kssolv.analysis.matgenlab.core.MoleculeGraph. ...
    from_local_env_strategy(adaptor.pymatgen_mol, ...
    kssolv.analysis.matgenlab.core.OpenBabelNN());
end
