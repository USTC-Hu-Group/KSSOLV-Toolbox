classdef BrokenSymmetry < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*INUSD>
 methods
  function obj=BrokenSymmetry(varargin)
   obj@kssolv.analysis.matgenlab.io.cp2k.Section("BS");
   start=1; if mod(numel(varargin),2)==1 && ~isempty(varargin), obj.section_parameters=string(varargin{1}); start=2; end
   for i=start:2:numel(varargin), obj.setitem(varargin{i},varargin{i+1}); end
  end
 end
 methods(Static)
  function obj=from_el(element,oxi_state,spin),if nargin<2,oxi_state=0;end;if nargin<3,spin=0;end;obj=kssolv.analysis.matgenlab.io.cp2k.BrokenSymmetry("L_ALPHA",-1,"N_ALPHA",0,"NEL_ALPHA",max(0,spin+oxi_state),"L_BETA",-1,"N_BETA",0,"NEL_BETA",max(0,-spin+oxi_state));end
 end
end
