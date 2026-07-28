function value = delta_func(x, ismear)
%DELTA_FUNC Replicate VASP's delta function.
arguments
    x double
    ismear (1,1) double {mustBeInteger}
end
if ismear < -1
    error("KSSOLV:Matgenlab:Optics:UnsupportedSmearing", ...
        "Delta function not implemented for ismear < -1");
elseif ismear == -1
    occupations = kssolv.analysis.matgenlab.io.vasp.optics. ...
        step_func(x, -1);
    value = occupations .* (1 - occupations);
elseif ismear == 0
    value = exp(-(x .* x)) ./ sqrt(pi);
else
    value = kssolv.analysis.matgenlab.io.vasp.optics. ...
        delta_methfessel_paxton(x, ismear);
end
end
