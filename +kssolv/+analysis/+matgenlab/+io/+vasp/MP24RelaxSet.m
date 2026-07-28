classdef MP24RelaxSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MP24RELAXSET Materials Project 2024 benchmarked relaxation inputs.
    properties (Dependent, SetAccess = private)
        kspacing_update
    end
    methods
        function obj = MP24RelaxSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MP24RelaxSet", "auto_kspacing", true, ...
                varargin{:});
        end
        function value = get.kspacing_update(obj)
            value = kssolv.analysis.matgenlab.io.vasp.auto_kspacing( ...
                obj.bandgap, obj.bandgap_tol);
        end
    end
end
