classdef MatPESStaticSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MATPESSTATICSET MatPES static-energy calculation inputs.
    methods
        function obj = MatPESStaticSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MatPESStaticSet", varargin{:});
        end
    end
end
