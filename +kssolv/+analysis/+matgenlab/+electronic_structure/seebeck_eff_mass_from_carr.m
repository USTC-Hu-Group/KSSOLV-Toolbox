function value = seebeck_eff_mass_from_carr(eta, concentration, ...
        temperature, lambda)
%SEEBECK_EFF_MASS_FROM_CARR SPB effective mass in free-electron masses.
if nargin < 4 || isempty(lambda), lambda = 0.5; end %#ok<NASGU>
integralValue = arrayfun(@(e) integral(@(x) sqrt(x) .* ...
    stableFermi(x-e), 0, inf, "RelTol", 1e-9, "AbsTol", 1e-12), eta);
hbar = 6.62607015e-34 / (2 * pi);
numerator = (2 * pi^2 * abs(concentration) * 1e6 ./ ...
    integralValue).^(2/3);
denominator = 2 * electronMass() * 1.380649e-23 * ...
    temperature / hbar^2;
value = numerator ./ denominator;
end

function value = stableFermi(x)
value = zeros(size(x));
mask = x > 40;
value(mask) = exp(-x(mask));
value(~mask) = 1 ./ (1 + exp(x(~mask)));
end

function value = electronMass()
value = 9.1093837015e-31;
end
