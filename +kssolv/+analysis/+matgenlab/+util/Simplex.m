classdef Simplex < kssolv.analysis.matgenlab.util.MSONable
    %SIMPLEX Generalized full-dimensional simplex.
    % Compatible with pymatgen.util.coord.Simplex.

    properties (SetAccess = private)
        space_dim (1,1) double
        simplex_dim (1,1) double
        origin (1,:) double
    end

    properties (Access = private)
        coordinates_ double
        augmented_ double = []
        augmentedInverse_ double = []
    end

    properties (Dependent, SetAccess = private)
        volume
        coords
    end

    methods
        function obj = Simplex(coords)
            arguments
                coords double
            end
            if ~ismatrix(coords) || isempty(coords) || any(~isfinite(coords), "all")
                error("KSSOLV:Matgenlab:Simplex:InvalidCoordinates", ...
                    "coords must be a nonempty finite 2-D array.");
            end
            obj.coordinates_ = coords;
            [obj.space_dim, obj.simplex_dim] = size(coords);
            obj.origin = coords(end, :);
            if obj.space_dim == obj.simplex_dim + 1
                obj.augmented_ = [coords, ones(obj.space_dim, 1)];
                obj.augmentedInverse_ = inv(obj.augmented_);
            end
        end

        function value = get.coords(obj)
            value = obj.coordinates_;
        end

        function value = get.volume(obj)
            obj.requireFullDimensional();
            value = abs(det(obj.augmented_)) / factorial(obj.simplex_dim);
        end

        function bary = bary_coords(obj, point)
            obj.requireFullDimensional();
            point = reshape(double(point), 1, []);
            if numel(point) ~= obj.simplex_dim
                error("KSSOLV:Matgenlab:Simplex:DimensionMismatch", ...
                    "point must have %d coordinates.", obj.simplex_dim);
            end
            bary = [point, 1] * obj.augmentedInverse_;
        end

        function bary = baryCoords(obj, point)
            bary = obj.bary_coords(point);
        end

        function point = point_from_bary_coords(obj, baryCoords)
            obj.requireFullDimensional();
            point = double(baryCoords) * obj.augmented_(:, 1:end-1);
        end

        function point = pointFromBaryCoords(obj, baryCoords)
            point = obj.point_from_bary_coords(baryCoords);
        end

        function tf = in_simplex(obj, point, tolerance)
            if nargin < 3, tolerance = 1e-8; end
            tf = all(obj.bary_coords(point) >= -tolerance);
        end

        function tf = inSimplex(obj, point, tolerance)
            if nargin < 3, tolerance = 1e-8; end
            tf = obj.in_simplex(point, tolerance);
        end

        function points = line_intersection(obj, point1, point2, tolerance)
            if nargin < 4, tolerance = 1e-8; end
            b1 = obj.bary_coords(point1);
            b2 = obj.bary_coords(point2);
            line = b1 - b2;
            valid = abs(line) > 1e-10;
            possible = b1 - (b1(valid).' ./ line(valid).') .* line;
            barys = zeros(0, obj.space_dim);
            for idx = 1:size(possible, 1)
                candidate = possible(idx, :);
                if all(candidate >= -tolerance)
                    duplicate = any(all(abs(barys - candidate) <= tolerance, 2));
                    if ~duplicate
                        barys(end + 1, :) = candidate; %#ok<AGROW>
                    end
                end
            end
            if size(barys, 1) >= 3
                error("KSSOLV:Matgenlab:Simplex:TooManyIntersections", ...
                    "More than 2 intersections found");
            end
            points = obj.point_from_bary_coords(barys);
        end

        function points = lineIntersection(obj, varargin)
            points = obj.line_intersection(varargin{:});
        end

        function tf = eq(obj, other)
            if ~isa(other, "kssolv.analysis.matgenlab.util.Simplex") || ...
                    ~isequal(size(obj.coordinates_), size(other.coordinates_))
                tf = false;
                return
            end
            tf = true;
            used = false(size(other.coordinates_, 1), 1);
            for idx = 1:size(obj.coordinates_, 1)
                matches = find(all(abs(other.coordinates_ - ...
                    obj.coordinates_(idx, :)) <= ...
                    1e-8 + 1e-5 * abs(other.coordinates_), 2) & ~used);
                if isempty(matches), tf = false; return; end
                used(matches(1)) = true;
            end
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end

        function text = string(obj)
            lines = strings(obj.space_dim + 1, 1);
            lines(1) = sprintf("%d-simplex in %dD space\nVertices:", ...
                obj.simplex_dim, obj.space_dim);
            for idx = 1:obj.space_dim
                values = arrayfun(@(x) string(sprintf("%.15g", x)), ...
                    obj.coordinates_(idx, :));
                lines(idx + 1) = sprintf("\t(%s)", strjoin(values, ", "));
            end
            text = strjoin(lines, newline);
        end

        function text = char(obj), text = char(string(obj)); end

        function disp(obj), fprintf("%s\n", string(obj)); end

        function data = asDict(obj)
            data = kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.util.coord", "Simplex", ...
                struct("coords", obj.coordinates_));
        end

        function data = as_dict(obj), data = obj.asDict(); end
    end

    methods (Static)
        function obj = fromDict(data)
            obj = kssolv.analysis.matgenlab.util.Simplex(data.coords);
        end

        function obj = from_dict(data), obj = ...
                kssolv.analysis.matgenlab.util.Simplex.fromDict(data); end
    end

    methods (Access = private)
        function requireFullDimensional(obj)
            if isempty(obj.augmented_)
                error("KSSOLV:Matgenlab:Simplex:NotFullDimensional", ...
                    "Simplex is not full-dimensional");
            end
        end
    end
end
