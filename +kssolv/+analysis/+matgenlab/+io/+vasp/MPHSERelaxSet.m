classdef MPHSERelaxSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MPHSERELAXSET Materials Project HSE06 relaxation inputs.
    methods
        function obj = MPHSERelaxSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPHSERelaxSet", varargin{:});
        end
    end
end
