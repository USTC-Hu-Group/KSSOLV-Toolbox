classdef Subsys < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*NOCOMMA>
 methods,function obj=Subsys(varargin),obj@kssolv.analysis.matgenlab.io.cp2k.Section("SUBSYS");for i=1:2:numel(varargin),if isstruct(varargin{i}),obj.update(varargin{i});end,end,end,end
end
