function [nearest,distance]=get_nearest_site(structure,coords,site,radius)
%GET_NEAREST_SITE Closest periodic image of a specified site.
if nargin<4||isempty(radius)
    radius=norm(sum(structure.lattice.matrix,1));
end
base=site.frac_coords;center=reshape(double(coords),1,3);
limit=max(1,ceil(radius/min(structure.lattice.lengths))+1);
distance=Inf;nearest=site;
for a=-limit:limit
    for b=-limit:limit
        for c=-limit:limit
            fractional=base+[a,b,c];
            cartesian=structure.lattice.get_cartesian_coords(fractional);
            candidateDistance=norm(cartesian-center);
            if candidateDistance<distance
                distance=candidateDistance;
                nearest=kssolv.analysis.matgenlab.core.PeriodicSite( ...
                    site.species,fractional,structure.lattice, ...
                    properties=site.site_properties,label=site.label);
            end
        end
    end
end
end
