classdef HybridStaticSet < kssolv.analysis.matgenlab.io.cp2k.DftSet
%#ok<*NOCOMMA>
 methods,function obj=HybridStaticSet(structure,varargin),obj@kssolv.analysis.matgenlab.io.cp2k.DftSet(structure,"run_type","ENERGY_FORCE",varargin{:});obj.activate_hybrid();end,end
end
