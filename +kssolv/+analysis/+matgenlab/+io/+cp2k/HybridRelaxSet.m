classdef HybridRelaxSet < kssolv.analysis.matgenlab.io.cp2k.DftSet
%#ok<*NOCOMMA>
 methods,function obj=HybridRelaxSet(structure,varargin),obj@kssolv.analysis.matgenlab.io.cp2k.DftSet(structure,"run_type","GEO_OPT",varargin{:});obj.activate_hybrid();obj.activate_motion();end,end
end
