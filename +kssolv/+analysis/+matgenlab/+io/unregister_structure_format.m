function unregister_structure_format(name)
%UNREGISTER_STRUCTURE_FORMAT Remove a structure handler if registered.
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.structures();
name=char(lower(string(name)));
if isKey(registry,name),remove(registry,name);end
end
