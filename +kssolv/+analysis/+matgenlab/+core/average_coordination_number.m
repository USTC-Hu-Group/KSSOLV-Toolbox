function coordination=average_coordination_number(structures,frequency)
%AVERAGE_COORDINATION_NUMBER Ensemble-averaged Voronoi coordination.
if nargin<2||isempty(frequency),frequency=10;end
if ~iscell(structures),structures=num2cell(structures);end
elements=structures{1}.composition.elements;
coordination=struct();
for index=1:numel(elements)
    coordination.(char(elements{index}.symbol))=0;
end
count=0;
for frame=1:frequency:numel(structures)
    count=count+1;structure=structures{frame};
    % A 5 A local tessellation is sufficient for ordinary condensed
    % structures and avoids constructing the much larger default sphere.
    % Fall back to the upstream 13 A cutoff for unusually open cells.
    strategy=kssolv.analysis.matgenlab.core.VoronoiNN("cutoff",5);
    for site=1:structure.num_sites
        symbol=char(structure(site).specie.symbol);
        try
            value=strategy.get_cn(structure,site,"use_weights",true);
        catch
            fallback=kssolv.analysis.matgenlab.core.VoronoiNN();
            value=fallback.get_cn(structure,site,"use_weights",true);
        end
        coordination.(symbol)=coordination.(symbol)+value;
    end
end
composition=structures{1}.composition;
names=fieldnames(coordination);
for index=1:numel(names)
    coordination.(names{index})=coordination.(names{index})/ ...
        composition.get_atomic_fraction(names{index})/ ...
        composition.num_atoms/count;
end
end
