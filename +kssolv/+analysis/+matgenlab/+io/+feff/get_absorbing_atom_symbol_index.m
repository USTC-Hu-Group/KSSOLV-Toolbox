function [symbol,index]=get_absorbing_atom_symbol_index(absorbing_atom,structure)
%GET_ABSORBING_ATOM_SYMBOL_INDEX Resolve a FEFF absorber.
if ischar(absorbing_atom)||isstring(absorbing_atom)
 symbol=string(absorbing_atom);indices=structure.indices_from_symbol(symbol);
 if isempty(indices),error("KSSOLV:Matgenlab:Feff:Absorber","Absorbing element is absent from the structure.");end
 index=indices(1);
elseif isnumeric(absorbing_atom)&&isscalar(absorbing_atom)&&absorbing_atom>=0&&absorbing_atom==fix(absorbing_atom)
 index=double(absorbing_atom)+1;
 if index>structure.num_sites,error("KSSOLV:Matgenlab:Feff:Absorber","Absorbing atom index is out of range.");end
 symbol=string(structure.sites{index}.specie.symbol);
else
 error("KSSOLV:Matgenlab:Feff:Absorber","absorbing_atom must be a species symbol or zero-based site index.");
end
end
