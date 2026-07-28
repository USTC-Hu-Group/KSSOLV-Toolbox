function formats=list_molecule_formats()
%LIST_MOLECULE_FORMATS Return all currently registered molecule handlers.
registry=kssolv.analysis.matgenlab.io.FormatRegistryStore.molecules();
formats=values(registry);
end
