classdef MPScanStaticSet < kssolv.analysis.matgenlab.io.vasp.MPScanRelaxSet
    %MPSCANSTATICSET Materials Project r2SCAN static inputs.
    methods
        function obj = MPScanStaticSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.MPScanRelaxSet( ...
                structure, "inherit_incar", true, varargin{:});
            obj.set_name = "MPScanStaticSet";
            obj.extra_incar_updates = struct("ALGO","Fast","LREAL",false, ...
                "NSW",0,"LORBIT",11,"LVHAR",true,"ISMEAR",-5);
        end
    end
end
