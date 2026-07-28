function sites=get_unique_site_indices(structure)
sites=struct();symbols=string(cellfun(@(s)s.specie.symbol,structure.sites,"UniformOutput",false));props=structure.site_properties;
keys=fieldnames(props);signatures=strings(1,structure.num_sites);
for i=1:structure.num_sites,signatures(i)=symbols(i);for k=1:numel(keys),v=props.(keys{k});if iscell(v),x=v{i};elseif isvector(v),x=v(i);else,x=v(i,:);end;signatures(i)=signatures(i)+"|"+string(mat2str(x));end,end
for symbol=unique(symbols,"stable"),ids=find(symbols==symbol);u=unique(signatures(ids),"stable");for j=1:numel(u),sites.(matlab.lang.makeValidName(symbol+"_"+j))=ids(signatures(ids)==u(j));end,end
end
