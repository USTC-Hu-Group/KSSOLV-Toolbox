classdef Xmu < handle
 properties,header=[];parameters=[];absorbing_atom=[];data double=[];end
 properties(Dependent),energies;relative_energies;wavenumber;mu;mu0;chi;e_fermi;source;calc;material_formula;edge;end
 methods
  function obj=Xmu(header,parameters,absorbingAtom,data),if nargin>0,obj.header=header;obj.parameters=parameters;obj.absorbing_atom=absorbingAtom;obj.data=double(data);end,end
  function v=get.energies(o),v=o.data(:,1);end
  function v=get.relative_energies(o),v=o.data(:,2);end
  function v=get.wavenumber(o),v=o.data(:,3);end
  function v=get.mu(o),v=o.data(:,4);end
  function v=get.mu0(o),v=o.data(:,5);end
  function v=get.chi(o),v=o.data(:,6);end
  function v=get.e_fermi(o),v=o.energies(1)-o.relative_energies(1);end
  function v=get.source(o),v=o.header.source;end
  function v=get.calc(o),if o.parameters.has("XANES"),v="XANES";else,v="EXAFS";end,end
  function v=get.material_formula(o),v=erase(string(o.header.formula)," ");end
  function v=get.edge(o),v=o.parameters("EDGE");end
  function value=as_dict(o),value=struct("x_module","pymatgen.io.feff.outputs","x_class","Xmu","header",o.header.as_dict(),"parameters",o.parameters.as_dict(),"absorbing_atom",o.absorbing_atom,"data",o.data);end
 end
 methods(Static)
  function obj=from_file(xmuFile,feffInput),if nargin<1,xmuFile="xmu.dat";end;if nargin<2,feffInput="feff.inp";end;data=readmatrix(xmuFile,"FileType","text","CommentStyle","#");header=kssolv.analysis.matgenlab.io.feff.Header.from_file(feffInput);tags=kssolv.analysis.matgenlab.io.feff.Tags.from_file(feffInput);if tags.has("RECIPROCAL"),absorber=tags("TARGET");else,pot=kssolv.analysis.matgenlab.io.feff.Potential.pot_string_from_file(feffInput);lines=splitlines(string(pot));tok=split(strtrim(lines(4)));absorber=tok(3);end;obj=kssolv.analysis.matgenlab.io.feff.Xmu(header,tags,absorber,data);end
  function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.feff.Xmu(kssolv.analysis.matgenlab.io.feff.Header.from_dict(d.header),kssolv.analysis.matgenlab.io.feff.Tags.from_dict(d.parameters),d.absorbing_atom,d.data);end
 end
end
