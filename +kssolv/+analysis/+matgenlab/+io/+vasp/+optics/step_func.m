function value = step_func(x, ismear)
%STEP_FUNC Replicate VASP's occupation step function.
arguments
    x double
    ismear (1,1) double {mustBeInteger}
end
if ismear < -1
    error("KSSOLV:Matgenlab:Optics:UnsupportedSmearing", ...
        "Delta function not implemented for ismear < -1");
elseif ismear == -1
    value = 1 ./ (1 + exp(-x));
elseif ismear == 0
    value = 0.5 + 0.5 .* erf(x);
else
    value = kssolv.analysis.matgenlab.io.vasp.optics. ...
        step_methfessel_paxton(x, ismear);
end
end
