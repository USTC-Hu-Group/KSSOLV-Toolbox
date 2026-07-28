function formats=list_structure_formats()
%LIST_STRUCTURE_FORMATS Return all currently registered structure handlers.
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.structures();
formats=values(registry);
end
