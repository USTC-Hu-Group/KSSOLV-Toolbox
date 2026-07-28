function value = auto_kspacing(bandgap, bandgap_tol)
%AUTO_KSPACING Automatic VASP KSPACING from an electronic band gap.
if nargin < 2, bandgap_tol = 1.0e-4; end
if isempty(bandgap) || bandgap <= bandgap_tol
    value = 0.22;
else
    rmin = max(1.5, 25.22 - 2.87 * bandgap);
    value = min(2 * pi * 1.0265 / (rmin - 1.0183), 0.44);
end
end
