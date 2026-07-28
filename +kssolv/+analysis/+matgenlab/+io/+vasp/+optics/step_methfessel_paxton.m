function value = step_methfessel_paxton(x, n)
%STEP_METHFESSEL_PAXTON VASP Methfessel-Paxton step approximation.
arguments
    x double
    n (1,1) double {mustBeInteger,mustBeNonnegative}
end
series = zeros(size(x));
for index = 1:n
    coefficient = (-1)^index / ...
        (factorial(index) * 4^index * sqrt(pi));
    polynomial = kssolv.analysis.matgenlab.io.vasp.optics. ...
        hermite_physicists(2 * index - 1, x);
    series = series + coefficient .* polynomial;
end
value = (1 + erf(x)) ./ 2 - exp(-(x .* x)) .* series;
end
