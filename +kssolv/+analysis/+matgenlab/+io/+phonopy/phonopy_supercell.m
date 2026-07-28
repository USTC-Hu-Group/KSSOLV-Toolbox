function [supercell,translations]=phonopy_supercell(structure,scaling)
%PHONOPY_SUPERCELL Build a Structure in phonopy's site/translation order.
if isscalar(scaling),scaling=eye(3)*scaling;end
if isvector(scaling),scaling=diag(scaling);end
scaling=double(scaling);
points=kssolv.analysis.matgenlab.util. ...
    lattice_points_in_supercell(scaling);
unitTranslations=points*scaling;
[~,order]=sortrows(unitTranslations,[3,2,1]);
unitTranslations=unitTranslations(order,:);
translations=unitTranslations;
newLattice=kssolv.analysis.matgenlab.core.Lattice( ...
    scaling*structure.lattice.matrix);
sites=cell(1,structure.num_sites*size(translations,1));
output=0;
for siteIndex=1:structure.num_sites
    site=structure(siteIndex);
    for translationIndex=1:size(translations,1)
        output=output+1;
        unitFrac=site.frac_coords+translations(translationIndex,:);
        superFrac=unitFrac/scaling;
        sites{output}=kssolv.analysis.matgenlab.core.PeriodicSite( ...
            site.species,superFrac,newLattice, ...
            properties=site.site_properties,label=site.label);
    end
end
supercell=kssolv.analysis.matgenlab.core.Structure. ...
    from_sites(sites,to_unit_cell=true);
end
