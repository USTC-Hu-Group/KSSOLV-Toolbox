classdef MPRelaxSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPRELAXSET Materials Project relaxation inputs.
    methods
        function obj = MPRelaxSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", varargin{:});
        end
    end
end
