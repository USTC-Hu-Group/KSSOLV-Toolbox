function value = get_delta(x0, sigma, nx, dx, ismear)
%GET_DELTA Return a smeared delta function on the VASP output grid.
arguments
    x0 (1,1) double
    sigma (1,1) double {mustBePositive}
    nx (1,1) double {mustBeInteger,mustBePositive}
    dx (1,1) double {mustBePositive}
    ismear (1,1) double {mustBeInteger} = 3
end
xgrid = (0:(nx - 1)) .* dx - x0;
scaled = (xgrid + dx / 2) ./ sigma;
step = kssolv.analysis.matgenlab.io.vasp.optics. ...
    step_func(scaled, ismear);
value = zeros(size(xgrid));
value(2:end) = diff(step) ./ dx;
end
