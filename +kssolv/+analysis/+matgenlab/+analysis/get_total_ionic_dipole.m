function dipole=get_total_ionic_dipole(structure,zvalDictionary)
%GET_TOTAL_IONIC_DIPOLE Sum ionic dipoles for all periodic sites.
dipole=zeros(1,3);
for index=1:structure.num_sites
    site=structure.sites{index};
    key=matlab.lang.makeValidName(char(site.species_string));
    if isstruct(zvalDictionary),zval=zvalDictionary.(key);
    else,zval=zvalDictionary(char(site.species_string));end
    dipole=dipole+kssolv.analysis.matgenlab.analysis. ...
        calc_ionic(site,structure,zval);
end
end
