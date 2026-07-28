classdef MVLGWSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MVLGWSET Many-body perturbation theory calculation inputs.
    methods
        function obj = MVLGWSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MVLGWSet", "force_gamma", true, ...
                "inherit_incar", true, "copy_wavecar", true, ...
                "mode", "STATIC", varargin{:});
            obj.extra_kpoints_updates = struct( ...
                "reciprocal_density",obj.reciprocal_density);
        end
    end
    methods (Static)
        function obj = from_prev_calc(prev_calc_dir, varargin)
            modeValue = "DIAG";
            if ~isempty(varargin) && ...
                    (ischar(varargin{1}) || isstring(varargin{1}))
                first = string(varargin{1});
                knownOptions = ["mode","user_incar_settings", ...
                    "user_kpoints_settings","allow_potcar"];
                if ~any(first == knownOptions)
                    modeValue = first;
                    varargin(1) = [];
                end
            end
            obj = kssolv.analysis.matgenlab.io.vasp.MVLGWSet( ...
                [], "mode", modeValue, varargin{:});
            obj = obj.override_from_prev_calc(prev_calc_dir);
        end
    end
end
