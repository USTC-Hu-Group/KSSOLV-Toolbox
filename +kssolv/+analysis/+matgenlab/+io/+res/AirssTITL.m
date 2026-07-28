classdef AirssTITL
    %AIRSSTITL AIRSS metadata stored in a RES TITL record.

    properties (SetAccess = private)
        seed (1,1) string = ""
        pressure (1,1) double = 0
        volume (1,1) double = 0
        energy (1,1) double = 0
        integrated_spin_density (1,1) double = 0
        integrated_absolute_spin_density (1,1) double = 0
        spacegroup_label (1,1) string = "P1"
        appearances (1,1) double = 1
    end

    methods
        function obj = AirssTITL(seed, pressure, volume, energy, ...
                spin, absoluteSpin, spacegroup, appearances)
            if nargin == 0, return; end
            obj.seed = string(seed);
            obj.pressure = double(pressure);
            obj.volume = double(volume);
            obj.energy = double(energy);
            obj.integrated_spin_density = double(spin);
            obj.integrated_absolute_spin_density = double(absoluteSpin);
            obj.spacegroup_label = string(spacegroup);
            obj.appearances = double(appearances);
        end

        function value = string(obj)
            value = sprintf( ...
                "TITL %s %.2f %.4f %.5f %f %f (%s) n - %d", ...
                obj.seed, obj.pressure, obj.volume, obj.energy, ...
                obj.integrated_spin_density, ...
                obj.integrated_absolute_spin_density, ...
                obj.spacegroup_label, obj.appearances);
        end

        function value = char(obj), value = char(string(obj)); end

        function value = as_dict(obj)
            value = struct("seed", obj.seed, ...
                "pressure", obj.pressure, "volume", obj.volume, ...
                "energy", obj.energy, ...
                "integrated_spin_density", ...
                obj.integrated_spin_density, ...
                "integrated_absolute_spin_density", ...
                obj.integrated_absolute_spin_density, ...
                "spacegroup_label", obj.spacegroup_label, ...
                "appearances", obj.appearances);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.res.AirssTITL( ...
                value.seed, value.pressure, value.volume, value.energy, ...
                value.integrated_spin_density, ...
                value.integrated_absolute_spin_density, ...
                value.spacegroup_label, value.appearances);
        end
    end
end
