function value = num_valence_electrons(structure, pseudos)
structure = kssolv.analysis.matgenlab.io.abinit.as_structure(structure);
table = kssolv.analysis.matgenlab.io.abinit.PseudoTable.as_table(pseudos);
value = 0;
for i = 1:structure.num_sites
    value = value + table.pseudo_with_symbol(structure.sites{i}.specie.symbol).Z_val;
end
end
