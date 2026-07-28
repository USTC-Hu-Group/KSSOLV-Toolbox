classdef BandStructure < kssolv.analysis.matgenlab.io.cp2k.Section
 methods
  function obj=BandStructure(varargin)
   obj@kssolv.analysis.matgenlab.io.cp2k.Section("BAND_STRUCTURE");
   start=1; if mod(numel(varargin),2)==1 && ~isempty(varargin), obj.section_parameters=string(varargin{1}); start=2; end
   for i=start:2:numel(varargin), obj.setitem(varargin{i},varargin{i+1}); end
  end
 end
 methods(Static)
  function obj=from_kpoints(kpoints,varargin),obj=kssolv.analysis.matgenlab.io.cp2k.BandStructure("FILENAME","BAND.bs");if isprop(kpoints,"kpts"),obj.setitem("KPOINTS",kpoints.kpts);end,end
 end
end
