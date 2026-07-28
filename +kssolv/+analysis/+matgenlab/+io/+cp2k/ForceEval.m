classdef ForceEval < kssolv.analysis.matgenlab.io.cp2k.Section
%#ok<*NOCOMMA>
 methods,function obj=ForceEval(varargin),obj@kssolv.analysis.matgenlab.io.cp2k.Section("FORCE_EVAL");obj.setitem("METHOD","QS");for i=1:2:numel(varargin),if isstruct(varargin{i}),obj.update(varargin{i});end,end,end,end
end
