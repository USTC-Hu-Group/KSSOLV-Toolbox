classdef MITRelaxSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MITRELAXSET MIT high-throughput relaxation inputs.
    methods
        function obj = MITRelaxSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MITRelaxSet", varargin{:});
        end
    end
end
