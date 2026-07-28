function value = delta_methfessel_paxton(x, n)
%DELTA_METHFESSEL_PAXTON VASP Methfessel-Paxton delta approximation.
arguments
    x double
    n (1,1) double {mustBeInteger,mustBeNonnegative}
end
series = zeros(size(x));
for index = 0:n
    coefficient = (-1)^index / ...
        (factorial(index) * 4^index * sqrt(pi));
    polynomial = kssolv.analysis.matgenlab.io.vasp.optics. ...
        hermite_physicists(2 * index, x);
    series = series + coefficient .* polynomial;
end
value = exp(-(x .* x)) .* series;
end
