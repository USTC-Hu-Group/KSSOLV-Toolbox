function pointOperations=get_site_symmetries(structure,precision)
%GET_SITE_SYMMETRIES Point operations centered on every atomic site.
if nargin<2,precision=0.1;end
if ~isa(structure,"kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:SiteSymmetries:Structure", ...
        "structure must be a periodic matgenlab structure.");
end
pointOperations=cell(1,structure.num_sites);
for first=1:structure.num_sites
    temporary=structure.copy();
    origin=structure.frac_coords(first,:);
    for second=1:structure.num_sites
        temporary=temporary.replace(second, ...
            structure(second).species, ...
            structure.frac_coords(second,:)-origin);
    end
    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(temporary,precision);
    operations=analyzer.get_symmetry_operations(true);
    pointOperations{first}=operations(cellfun(@(operation) ...
        all(abs(operation.translation_vector)<1e-12),operations));
end
end
