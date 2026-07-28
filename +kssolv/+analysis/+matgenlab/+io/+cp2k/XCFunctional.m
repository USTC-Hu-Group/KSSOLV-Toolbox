classdef XCFunctional < kssolv.analysis.matgenlab.io.cp2k.Section
 methods
  function obj=XCFunctional(varargin)
   obj@kssolv.analysis.matgenlab.io.cp2k.Section("XC_FUNCTIONAL");
   start=1; if mod(numel(varargin),2)==1 && ~isempty(varargin), obj.section_parameters=string(varargin{1}); start=2; end
   for i=start:2:numel(varargin), obj.setitem(varargin{i},varargin{i+1}); end
  end
 end
end
