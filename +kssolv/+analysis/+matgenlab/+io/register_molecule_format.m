function register_molecule_format(format)
%REGISTER_MOLECULE_FORMAT Register or replace a molecule format handler.
if ~isa(format,"kssolv.analysis.matgenlab.io.MoleculeFormat")
    error("KSSOLV:Matgenlab:Registry:MoleculeFormat", ...
        "Expected a MoleculeFormat descriptor.");
end
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.molecules();
registry(char(lower(format.name)))=format; %#ok<NASGU>
end
