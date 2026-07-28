function value = get_linear_interpolated_value(x_values, y_values, x)
%GET_LINEAR_INTERPOLATED_VALUE Piecewise linear interpolation without extrapolation.
xValues = double(x_values(:));
yValues = double(y_values(:));
if numel(xValues) ~= numel(yValues)
    error("KSSOLV:Matgenlab:Coord:LengthMismatch", ...
        "x_values and y_values must have the same length.");
end
[xValues, order] = sort(xValues);
yValues = yValues(order);
idx = find(xValues > x, 1);
if isempty(idx) || idx == 1
    error("KSSOLV:Matgenlab:Coord:InterpolationOutOfRange", ...
        "%g is out of range of provided x_values (%g, %g)", ...
        x, min(xValues), max(xValues));
end
x1 = xValues(idx - 1); x2 = xValues(idx);
y1 = yValues(idx - 1); y2 = yValues(idx);
value = y1 + (y2 - y1) / (x2 - x1) * (x - x1);
end
