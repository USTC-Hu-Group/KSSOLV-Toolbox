function unregister_molecule_format(name)
%UNREGISTER_MOLECULE_FORMAT Remove a molecule handler if registered.
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.molecules();
name=char(lower(string(name)));
if isKey(registry,name),remove(registry,name);end
end
