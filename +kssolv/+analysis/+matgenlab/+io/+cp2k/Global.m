classdef Global < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*NOCOMMA>
 methods,function obj=Global(project_name,run_type,varargin),if nargin<1,project_name="CP2K";end;if nargin<2,run_type="ENERGY_FORCE";end;obj@kssolv.analysis.matgenlab.io.cp2k.Section("GLOBAL");obj.setitem("PROJECT_NAME",project_name);obj.setitem("RUN_TYPE",run_type);obj.updatePairs(varargin{:});end,end
 methods(Access=private),function updatePairs(obj,varargin),for i=1:2:numel(varargin),if isstruct(varargin{i}),obj.update(varargin{i});else,obj.setitem(varargin{i},varargin{i+1});end,end,end,end
end
