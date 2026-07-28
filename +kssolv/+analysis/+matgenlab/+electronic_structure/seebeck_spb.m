function value = seebeck_spb(eta, lambda)
%SEEBECK_SPB Single-parabolic-band Seebeck coefficient in microvolt/K.
if nargin < 2 || isempty(lambda), lambda = 0.5; end
numerator = fermiDiracIntegral(1 + lambda, eta);
denominator = fermiDiracIntegral(lambda, eta);
value = boltzmann() / electronCharge() .* ...
    ((2 + lambda) .* numerator ./ ((1 + lambda) .* denominator) ...
    - eta) * 1e6;
end

function value = fermiDiracIntegral(order, eta)
value = arrayfun(@(e) integral(@(x) x.^order .* stableFermi(x-e), ...
    0, inf, "RelTol", 1e-9, "AbsTol", 1e-12), eta);
end

function value = stableFermi(x)
value = zeros(size(x));
mask = x > 40;
value(mask) = exp(-x(mask));
value(~mask) = 1 ./ (1 + exp(x(~mask)));
end

function value = boltzmann()
value = 1.380649e-23;
end

function value = electronCharge()
value = 1.602176634e-19;
end
