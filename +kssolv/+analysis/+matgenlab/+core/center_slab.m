function slab=center_slab(slab)
%CENTER_SLAB Translate a slab so its atomic center lies at fractional c=0.5.
coordinates=slab.frac_coords;
weights=zeros(slab.num_sites,1);
for index=1:slab.num_sites
    weights(index)=slab(index).species.weight;
end
z=mod(coordinates(:,3),1);
sorted=sort(z);
[~,cut]=max(diff([sorted;sorted(1)+1]));
start=sorted(mod(cut,numel(sorted))+1);
unwrapped=mod(z-start,1);
center=sum(unwrapped.*weights)/sum(weights);
coordinates(:,3)=mod(unwrapped+(0.5-center),1);
if isa(slab,"kssolv.analysis.matgenlab.core.Slab")
    slab=kssolv.analysis.matgenlab.core.Slab(slab.lattice, ...
        slab.species_and_occu,coordinates,slab.miller_index, ...
        slab.oriented_unit_cell,slab.shift,slab.scale_factor, ...
        reorient_lattice=slab.reorient_lattice, ...
        site_properties=slab.site_properties,energy=slab.energy);
else
    slab=kssolv.analysis.matgenlab.core.Structure(slab.lattice, ...
        slab.species_and_occu,coordinates, ...
        site_properties=slab.site_properties);
end
end
