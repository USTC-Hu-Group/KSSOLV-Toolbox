function eta = eta_from_seebeck(seebeck, lambda)
%ETA_FROM_SEEBECK Invert the single-parabolic-band Seebeck relationship.
if nargin < 2 || isempty(lambda), lambda = 0.5; end
target = abs(double(seebeck));
objective = @(value) abs( ...
    kssolv.analysis.matgenlab.electronic_structure. ...
    seebeck_spb(value, lambda) - target);
eta = fminbnd(objective, -30, 60, ...
    optimset("TolX", 1e-9, "Display", "off"));
end
