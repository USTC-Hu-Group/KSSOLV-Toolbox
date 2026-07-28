function polarization=calc_ionic(site,structure,zval)
%CALC_IONIC Ionic dipole contribution in electron-Angstrom.
polarization=structure.lattice.lengths.*(-site.frac_coords*zval);
end
