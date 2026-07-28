function value=get_atom_map(structure,absorbing_atom)
%GET_ATOM_MAP Map unique element symbols to FEFF potential indices.
if nargin<2,absorbing_atom=[];end
symbols=string(cellfun(@(s)s.specie.symbol,structure.sites,"UniformOutput",false));
uniqueSymbols=sort(unique(symbols));if ~isempty(absorbing_atom)&&sum(symbols==string(absorbing_atom))==1,uniqueSymbols(uniqueSymbols==string(absorbing_atom))=[];end
value=struct();for i=1:numel(uniqueSymbols),value.(matlab.lang.makeValidName(uniqueSymbols(i)))=i;end
end
