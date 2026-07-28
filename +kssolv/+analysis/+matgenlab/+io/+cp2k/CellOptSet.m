classdef CellOptSet < kssolv.analysis.matgenlab.io.cp2k.DftSet
%#ok<*NOCOMMA>
 methods,function obj=CellOptSet(structure,varargin),obj@kssolv.analysis.matgenlab.io.cp2k.DftSet(structure,"run_type","CELL_OPT",varargin{:});obj.activate_motion();end,end
end
