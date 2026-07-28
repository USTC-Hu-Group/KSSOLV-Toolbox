function values = lorentzian(x, x_0, sigma)
%LORENTZIAN Pymatgen Lorentzian smearing function.
arguments
    x {mustBeNumeric}
    x_0 (1,1) double = 0
    sigma (1,1) double = 1.0
end
values = (1 / pi) .* (0.5 * sigma) ./ ...
    ((double(x) - x_0).^2 + (0.5 * sigma).^2);
end
