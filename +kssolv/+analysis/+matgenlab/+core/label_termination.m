function label=label_termination(slab,ftol,terminationIndex)
%LABEL_TERMINATION Chemistry, layer symmetry and multiplicity label.
if nargin<2||isempty(ftol),ftol=.25;end
if nargin<3,terminationIndex=[];end
z=mod(slab.frac_coords(:,3),1);height=slab.lattice.lengths(3);
top=max(z);indices=find((top-z)*height<=ftol);
topPlane=kssolv.analysis.matgenlab.core.Structure.from_sites( ...
    slab.sites(indices));
formula=string(topPlane.reduced_formula);
try
    analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(topPlane,.1);
    symbol=string(analyzer.get_space_group_symbol());
catch
    symbol="P1";
end
if isempty(terminationIndex)
    label=sprintf("%s_%s_%d",formula,symbol,numel(indices));
else
    label=sprintf("%d_%s_%s_%d",terminationIndex,formula,symbol, ...
        numel(indices));
end
label=string(label);
end
