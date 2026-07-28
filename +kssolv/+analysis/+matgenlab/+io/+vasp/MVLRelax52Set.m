classdef MVLRelax52Set < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MVLRELAX52SET VASP 5.2-compatible relaxation inputs.
    methods
        function obj = MVLRelax52Set(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MVLRelax52Set", varargin{:});
        end
    end
end
