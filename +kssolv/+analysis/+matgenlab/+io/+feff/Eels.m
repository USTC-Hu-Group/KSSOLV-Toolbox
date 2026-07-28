classdef Eels < handle
 properties,data double=[];end
 properties(Dependent),energies;total_spectrum;atomic_background;fine_structure;end
 methods
  function obj=Eels(data),if nargin>0,obj.data=double(data);end,end
  function v=get.energies(o),v=o.data(:,1);end
  function v=get.total_spectrum(o),v=o.data(:,2);end
  function v=get.atomic_background(o),v=o.data(:,3);end
  function v=get.fine_structure(o),v=o.data(:,4);end
  function value=as_dict(o),value=struct("x_module","pymatgen.io.feff.outputs","x_class","Eels","data",o.data);end
 end
 methods(Static)
  function obj=from_file(filename),if nargin<1,filename="eels.dat";end;obj=kssolv.analysis.matgenlab.io.feff.Eels(readmatrix(filename,"FileType","text","CommentStyle","#"));end
  function obj=from_dict(d),obj=kssolv.analysis.matgenlab.io.feff.Eels(d.data);end
 end
end
