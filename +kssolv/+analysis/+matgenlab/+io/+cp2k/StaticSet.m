classdef StaticSet < kssolv.analysis.matgenlab.io.cp2k.DftSet
%#ok<*NOCOMMA>
 methods,function obj=StaticSet(structure,varargin),obj@kssolv.analysis.matgenlab.io.cp2k.DftSet(structure,"run_type","ENERGY_FORCE",varargin{:});end,end
end
