function value = kramers_kronig(eps, nedos, deltae, cshift)
%KRAMERS_KRONIG Perform the Kramers-Kronig transform used by VASP.
arguments
    eps double
    nedos (1,1) double {mustBeInteger,mustBePositive}
    deltae (1,1) double {mustBePositive}
    cshift (1,1) double = 0.1
end
if numel(eps) ~= nedos
    error("KSSOLV:Matgenlab:Optics:GridSize", ...
        "eps must contain nedos values.");
end
inputShape = size(eps);
epsRow = reshape(eps, 1, []);
egrid = linspace(0, deltae * nedos, nedos);
value = complex(zeros(1, nedos));
for index = 1:nedos
    cdiff = egrid(index) - egrid + 1i * cshift;
    csum = egrid(index) + egrid + 1i * cshift;
    terms = -0.5 .* (epsRow ./ cdiff - conj(epsRow) ./ csum);
    value(index) = sum(terms) .* (2 / pi) .* deltae;
end
value = reshape(value, inputShape);
end
