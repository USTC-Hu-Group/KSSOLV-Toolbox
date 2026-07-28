function lengths=get_max_bond_lengths(structure,radiusUpdates)
%GET_MAX_BOND_LENGTHS Jmol maximum bond-distance estimates.
if nargin<2,radiusUpdates=[];end
strategy=kssolv.analysis.matgenlab.core.JmolNN( ...
    "el_radius_updates",radiusUpdates);
elements=structure.elements;
[~,order]=sort(cellfun(@(element)element.Z,elements));
elements=elements(order);
lengths=containers.Map("KeyType","char","ValueType","double");
for first=1:numel(elements)
    for second=first:numel(elements)
        key=char(elements{first}.symbol+"|"+elements{second}.symbol);
        lengths(key)=strategy.get_max_bond_distance( ...
            elements{first}.symbol,elements{second}.symbol);
    end
end
end
