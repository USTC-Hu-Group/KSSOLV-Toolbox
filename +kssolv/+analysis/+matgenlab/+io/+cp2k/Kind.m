classdef Kind < kssolv.analysis.matgenlab.io.cp2k.Section
 properties,specie;magnetization=0;basis_set="GTH_BASIS";potential="GTH_POTENTIALS";ghost=false;aux_basis=[];end
 methods
  function obj=Kind(specie,varargin)
   obj@kssolv.analysis.matgenlab.io.cp2k.Section("KIND");obj.specie=specie;
   if isobject(specie)&&isprop(specie,"symbol"),symbol=string(specie.symbol);else,symbol=string(specie);end
   obj.alias=symbol;
   for i=1:2:numel(varargin)
    key=lower(string(varargin{i}));val=varargin{i+1};
    if key=="alias",obj.alias=string(val);elseif isprop(obj,key),obj.(char(key))=val;end
   end
   obj.section_parameters=obj.alias;obj.setitem("ELEMENT",symbol);obj.setitem("MAGNETIZATION",obj.magnetization);
   basis=obj.basis_set;if isobject(basis)&&ismethod(basis,"get_keyword"),obj.add(basis.get_keyword());else,obj.setitem("BASIS_SET",basis);end
   pot=obj.potential;if isobject(pot)&&ismethod(pot,"get_keyword"),obj.add(pot.get_keyword());else,obj.setitem("POTENTIAL",pot);end
   if obj.ghost,obj.setitem("GHOST",true);end
   if ~isempty(obj.aux_basis)
    aux=obj.aux_basis;if isobject(aux)&&isprop(aux,"name"),aux=aux.name;end
    obj.add(kssolv.analysis.matgenlab.io.cp2k.Keyword("BASIS_SET","AUX_FIT",aux));
   end
  end
 end
end
