function value = f0(energy, fermi, temperature)
%F0 Fermi-Dirac occupation probability.
if temperature <= 0
    error("KSSOLV:Matgenlab:Dos:InvalidTemperature", ...
        "temperature must be positive.");
end
boltzmann = kssolv.analysis.matgenlab.core.Constants. ...
    value("Boltzmann constant in eV/K");
exponent = (double(energy) - double(fermi)) / ...
    (boltzmann * double(temperature));
% Stable logistic sigmoid of -exponent.
value = zeros(size(exponent));
positive = exponent >= 0;
value(positive) = exp(-exponent(positive)) ./ ...
    (1 + exp(-exponent(positive)));
value(~positive) = 1 ./ (1 + exp(exponent(~positive)));
end
