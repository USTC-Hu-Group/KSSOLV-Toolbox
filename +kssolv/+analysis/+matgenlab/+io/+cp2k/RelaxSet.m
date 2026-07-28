classdef RelaxSet < kssolv.analysis.matgenlab.io.cp2k.DftSet
%#ok<*NOCOMMA>
 methods,function obj=RelaxSet(structure,varargin),obj@kssolv.analysis.matgenlab.io.cp2k.DftSet(structure,"run_type","GEO_OPT",varargin{:});obj.activate_motion();end,end
end
