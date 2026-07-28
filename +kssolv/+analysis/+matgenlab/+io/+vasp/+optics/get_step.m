function value = get_step(x0, sigma, nx, dx, ismear)
%GET_STEP Return a smeared step function on the VASP output grid.
arguments
    x0 (1,1) double
    sigma (1,1) double {mustBePositive}
    nx (1,1) double {mustBeInteger,mustBePositive}
    dx (1,1) double {mustBePositive}
    ismear (1,1) double {mustBeInteger}
end
xgrid = (0:(nx - 1)) .* dx - x0;
scaled = (xgrid + dx / 2) ./ sigma;
value = kssolv.analysis.matgenlab.io.vasp.optics. ...
    step_func(scaled, ismear);
end
