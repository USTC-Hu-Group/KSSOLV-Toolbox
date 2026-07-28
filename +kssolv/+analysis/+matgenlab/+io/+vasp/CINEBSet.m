classdef CINEBSet < kssolv.analysis.matgenlab.io.vasp.NEBSet
    %CINEBSET Climbing-image nudged elastic band inputs.
    methods
        function obj = CINEBSet(structures, varargin)
            obj@kssolv.analysis.matgenlab.io.vasp.NEBSet( ...
                structures, varargin{:});
            obj.set_name = "CINEBSet";
            obj.extra_incar_updates.LCLIMB = true;
        end
    end
end
