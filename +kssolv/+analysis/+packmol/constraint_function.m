function [f, gradient, violation, perAtom] = constraint_function(type, parameters, coordinates)
%CONSTRAINT_FUNCTION Evaluate Packmol comprest/gwalls formulas.
%
% TYPE is the integer ityperest code used by the Fortran implementation.
% The objective and analytical Cartesian gradient preserve comprest.f90 and
% gwalls.f90 at upstream commit 14e50c65.

coordinates = double(coordinates);
if size(coordinates, 2) ~= 3 || any(~isfinite(coordinates), "all")
    error("KSSOLV:Packmol:Coordinates", ...
        "Coordinates must be a finite N-by-3 matrix.");
end
p = zeros(1, 9);
p(1:numel(parameters)) = double(parameters);
n = size(coordinates, 1);
gradient = zeros(n, 3);
x = coordinates(:, 1);
y = coordinates(:, 2);
z = coordinates(:, 3);
scale = 1;
scale2 = 1.0e-2;

switch double(type)
    case {2, 3}
        if type == 2
            lower = p(1:3);
            upper = lower + p(4);
        else
            lower = p(1:3);
            upper = p(4:6);
        end
        below = min(coordinates - lower, 0);
        above = max(coordinates - upper, 0);
        perAtom = scale * sum(below.^2 + above.^2, 2);
        gradient = 2 * scale * (below + above);
        violation = max(max(lower - coordinates, coordinates - upper), [], 2);
        violation = max(violation, 0);

    case {4, 8}
        delta = coordinates - p(1:3);
        surface = sum(delta.^2, 2) - p(4)^2;
        if type == 4
            active = surface > 0;
            signed = max(surface, 0);
            violation = max(sqrt(sum(delta.^2, 2)) - p(4), 0);
        else
            active = surface < 0;
            signed = min(surface, 0);
            violation = max(p(4) - sqrt(sum(delta.^2, 2)), 0);
        end
        perAtom = scale2 * signed.^2;
        gradient(active, :) = 4 * scale2 .* ...
            delta(active, :) .* signed(active);

    case {5, 9}
        delta = coordinates - p(1:3);
        axesSquared = p(4:6).^2;
        surface = sum(delta.^2 ./ axesSquared, 2) - p(7)^2;
        if type == 5
            active = surface > 0;
            signed = max(surface, 0);
        else
            active = surface < 0;
            signed = min(surface, 0);
        end
        if type == 5
            perAtom = scale2 * signed.^2;
        else
            % Preserve comprest.f90: outside ellipsoids omit scale2 in
            % the objective although gwalls.f90 retains it in the
            % analytical gradient.
            perAtom = signed.^2;
        end
        gradient(active, :) = 4 * scale2 .* signed(active) .* ...
            delta(active, :) ./ axesSquared;
        violation = abs(signed);

    case {6, 7}
        if type == 6
            lower = p(1:3);
            upper = lower + p(4);
        else
            lower = p(1:3);
            upper = p(4:6);
        end
        inside = all(coordinates > lower & coordinates < upper, 2);
        % Packmol uses half the side length as the comparison point here,
        % without adding the lower corner. Preserve that source behavior.
        midpoint = (upper - lower) / 2;
        distances = zeros(n, 3);
        direction = zeros(n, 3);
        for axis = 1:3
            lowHalf = inside & coordinates(:, axis) <= midpoint(axis);
            highHalf = inside & coordinates(:, axis) > midpoint(axis);
            distances(lowHalf, axis) = ...
                coordinates(lowHalf, axis) - lower(axis);
            distances(highHalf, axis) = ...
                upper(axis) - coordinates(highHalf, axis);
            direction(lowHalf, axis) = 1;
            direction(highHalf, axis) = -1;
        end
        perAtom = scale * sum(distances, 2);
        gradient = scale * direction;
        violation = min(max(distances, 0), [], 2);

    case {10, 11}
        surface = coordinates * p(1:3).' - p(4);
        if type == 10
            signed = min(surface, 0);
        else
            signed = max(surface, 0);
        end
        perAtom = scale * signed.^2;
        gradient = 2 * scale .* signed .* p(1:3);
        violation = abs(signed) / max(norm(p(1:3)), eps);

    case {12, 13}
        delta = coordinates - p(1:3);
        director = p(4:6) / norm(p(4:6));
        axial = delta * director.';
        radialVector = delta - axial .* director;
        radialSquared = sum(radialVector.^2, 2);
        a = -axial;
        b = axial - p(9);
        c = radialSquared - p(7)^2;
        if type == 12
            aa = max(a, 0);
            bb = max(b, 0);
            cc = max(c, 0);
            perAtom = scale2 * (aa.^2 + bb.^2 + cc.^2);
            gradient = scale2 * ( ...
                -2 .* aa .* director + 2 .* bb .* director + ...
                4 .* cc .* radialVector);
            violation = max([aa, bb, max(sqrt(radialSquared) - p(7), 0)], ...
                [], 2);
        else
            aa = min(a, 0);
            bb = min(b, 0);
            cc = min(c, 0);
            fa = aa.^2;
            fb = bb.^2;
            fc = cc.^2;
            perAtom = scale2 * fa .* fb .* fc;
            dfa = -2 .* aa .* director;
            dfb = 2 .* bb .* director;
            dfc = 4 .* cc .* radialVector;
            gradient = scale2 * (dfa .* (fb .* fc) + ...
                dfb .* (fa .* fc) + dfc .* (fa .* fb));
            violation = (axial > 0 & axial < p(9) & ...
                radialSquared < p(7)^2) .* ...
                min([axial, p(9) - axial, ...
                     p(7) - sqrt(radialSquared)], [], 2);
        end

    case {14, 15}
        exponent = -(x - p(1)).^2 ./ (2 * p(3)^2) - ...
            (y - p(2)).^2 ./ (2 * p(4)^2);
        gaussian = zeros(n, 1);
        safe = exponent > -50;
        gaussian(safe) = p(6) * exp(exponent(safe));
        surface = gaussian - (z - p(5));
        if type == 14
            signed = max(surface, 0);
        else
            signed = min(surface, 0);
        end
        perAtom = scale * signed.^2;
        gradient(:, 1) = -2 * scale .* signed .* ...
            (x - p(1)) .* gaussian / p(3)^2;
        gradient(:, 2) = -2 * scale .* signed .* ...
            (y - p(2)) .* gaussian / p(4)^2;
        gradient(:, 3) = -2 * scale .* signed;
        violation = abs(signed);

    otherwise
        error("KSSOLV:Packmol:ConstraintType", ...
            "Unsupported Packmol restraint type %d.", type);
end
f = sum(perAtom);
end
