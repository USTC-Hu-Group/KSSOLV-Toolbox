function coefficients = get_diff_coeff(points, derivativeOrder)
%GET_DIFF_COEFF Finite-difference weights on an arbitrary one-dimensional mesh.
if nargin < 2, derivativeOrder = 1; end
points = reshape(double(points), 1, []);
count = numel(points);
if derivativeOrder < 0 || derivativeOrder >= count || ...
        derivativeOrder ~= fix(derivativeOrder)
    error("KSSOLV:Matgenlab:Elasticity:DerivativeOrder", ...
        "Derivative order must be an integer from zero to N-1.");
end
matrix = zeros(count);
for power = 0:count-1
    matrix(power + 1, :) = points .^ power;
end
target = zeros(count, 1);
target(derivativeOrder + 1) = factorial(derivativeOrder);
coefficients = (matrix \ target).';
end
