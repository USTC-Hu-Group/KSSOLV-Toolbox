function atoms=get_phonopy_structure(structure)
%GET_PHONOPY_STRUCTURE Convert a pymatgen-compatible Structure.
symbols=strings(1,structure.num_sites);
masses=zeros(1,structure.num_sites);
for index=1:structure.num_sites
    symbols(index)=structure(index).specie.symbol;
    masses(index)=structure(index).specie.atomic_mass;
end
magmoms=[];
siteProperties=structure.site_properties;
if isfield(siteProperties,"magmom")
    magmoms=siteProperties.magmom;
    if iscell(magmoms)
        try
            magmoms=cell2mat(magmoms);
        catch
            magmoms=[];
        end
    end
end
atoms=kssolv.analysis.matgenlab.io.phonopy.PhonopyAtoms( ...
    symbols,structure.lattice.matrix,structure.frac_coords,masses,magmoms);
end
