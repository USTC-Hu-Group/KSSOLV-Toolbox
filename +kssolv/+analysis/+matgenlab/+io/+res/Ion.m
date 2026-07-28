classdef Ion
    %ION Atomic RES SFAC record.

    properties (SetAccess = private)
        specie (1,1) string = ""
        specie_num (1,1) double = 0
        pos (1,3) double = [0, 0, 0]
        occupancy (1,1) double = 1
        spin = []
    end

    methods
        function obj = Ion(specie, specieNum, position, occupancy, spin)
            if nargin == 0, return; end
            if nargin < 5, spin = []; end
            position = reshape(double(position), 1, []);
            if numel(position) ~= 3
                error("KSSOLV:Matgenlab:Res:IonPosition", ...
                    "Ion position must contain three values.");
            end
            obj.specie = string(specie);
            obj.specie_num = double(specieNum);
            obj.pos = position;
            obj.occupancy = double(occupancy);
            if ~isempty(spin), obj.spin = double(spin); end
        end

        function value = string(obj)
            if isempty(obj.spin)
                value = sprintf("%-7s%-2d %.8f %.8f %.8f %f", ...
                    obj.specie, obj.specie_num, obj.pos, obj.occupancy);
            else
                value = sprintf( ...
                    "%-7s%-2d %.8f %.8f %.8f %f %5.2f", ...
                    obj.specie, obj.specie_num, obj.pos, ...
                    obj.occupancy, obj.spin);
            end
        end

        function value = char(obj), value = char(string(obj)); end

        function value = as_dict(obj)
            value = struct("specie", obj.specie, ...
                "specie_num", obj.specie_num, "pos", obj.pos, ...
                "occupancy", obj.occupancy, "spin", obj.spin);
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.res.Ion( ...
                value.specie, value.specie_num, value.pos, ...
                value.occupancy, value.spin);
        end
    end
end
