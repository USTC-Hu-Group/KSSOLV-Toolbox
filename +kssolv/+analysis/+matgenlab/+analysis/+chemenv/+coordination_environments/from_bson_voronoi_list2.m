function value=from_bson_voronoi_list2(raw,structure)
%FROM_BSON_VORONOI_LIST2 Restore pymatgen's compact Voronoi wire format.
value=cell(size(raw));
for isite=1:numel(raw)
    if isempty(raw{isite}),value{isite}=[];continue,end
    siteEntries=cell(1,numel(raw{isite}));
    for inb=1:numel(raw{isite})
        pair=raw{isite}{inb};siteSpec=pair{1};data=pair{2};
        if iscell(siteSpec)
            structureIndex=double(siteSpec{1})+1;
            image=reshape(double(siteSpec{2}),1,3);
        else
            structureIndex=double(siteSpec(1))+1;
            image=reshape(double(siteSpec(2:4)),1,3);
        end
        base=structure.sites{structureIndex};
        site=kssolv.analysis.matgenlab.core.PeriodicSite( ...
            base.species,base.frac_coords+image,structure.lattice, ...
            properties=base.site_properties,label=base.label);
        data.site=site;data.index=structureIndex;
        siteEntries{inb}=data;
    end
    value{isite}=siteEntries;
end
end
