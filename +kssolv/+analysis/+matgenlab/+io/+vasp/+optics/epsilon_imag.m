function [egrid, epsdd] = epsilon_imag(cder, eigs, kweights, ...
    efermi, nedos, deltae, ismear, sigma, idir, jdir, mask)
%EPSILON_IMAG Reproduce VASP's EPSILON_IMAG transition sum.
arguments
    cder double
    eigs double
    kweights double
    efermi (1,1) double
    nedos (1,1) double {mustBeInteger,mustBePositive}
    deltae (1,1) double {mustBePositive}
    ismear (1,1) double {mustBeInteger}
    sigma (1,1) double {mustBePositive}
    idir (1,1) double {mustBeInteger,mustBeBetween(idir,1,3)}
    jdir (1,1) double {mustBeInteger,mustBeBetween(jdir,1,3)}
    mask = []
end
expectedEigenShape = [size(cder, 1), size(cder, 3), size(cder, 4)];
if size(eigs, 1) ~= expectedEigenShape(1) || ...
        size(eigs, 2) ~= expectedEigenShape(2) || ...
        size(eigs, 3) ~= expectedEigenShape(3)
    error("KSSOLV:Matgenlab:Optics:EigenShape", ...
        "eigs must have shape [nbands, nkpoints, nspin].");
end
if numel(kweights) ~= size(cder, 3) || sum(kweights) == 0
    error("KSSOLV:Matgenlab:Optics:KpointWeights", ...
        "kweights must contain one nonzero-total weight per k-point.");
end
if isempty(mask)
    cderm = cder;
else
    if ~isequal(size(mask), size(cder))
        error("KSSOLV:Matgenlab:Optics:MaskShape", ...
            "mask and cder must have identical shapes.");
    end
    cderm = cder .* mask;
end
egrid = (0:(nedos - 1)) .* deltae;
epsdd = complex(zeros(size(egrid)));
nonzero = find(cderm);
if isempty(nonzero), return; end
[band0, band1, ~, ~, ~] = ind2sub(size(cderm), nonzero);
band0Range = min(band0):max(band0);
band1Range = min(band1):max(band1);
normWeights = reshape(kweights, 1, []) ./ sum(kweights);
shifted = eigs - efermi;
rspin = 3 - size(cderm, 4);
for ib = band0Range
    for jb = band1Range
        for ik = 1:size(cderm, 3)
            for spin = 1:size(cderm, 4)
                fermiI = kssolv.analysis.matgenlab.io.vasp.optics. ...
                    step_func(shifted(ib, ik, spin) / sigma, ismear);
                fermiJ = kssolv.analysis.matgenlab.io.vasp.optics. ...
                    step_func(shifted(jb, ik, spin) / sigma, ismear);
                weight = (fermiJ - fermiI) * rspin * normWeights(ik);
                transition = cderm(ib, jb, ik, spin, idir) .* ...
                    conj(cderm(ib, jb, ik, spin, jdir));
                if weight == 0 || ~any(transition, "all"), continue; end
                energy = eigs(jb, ik, spin) - eigs(ib, ik, spin);
                smeared = kssolv.analysis.matgenlab.io.vasp.optics. ...
                    get_delta(energy, sigma, nedos, deltae, ismear);
                epsdd = epsdd + smeared .* weight .* transition;
            end
        end
    end
end
end
