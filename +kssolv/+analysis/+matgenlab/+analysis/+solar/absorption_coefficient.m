function [energies,coefficient]=absorption_coefficient(dielectric)
%ABSORPTION_COEFFICIENT Isotropic optical absorption in cm^-1.
energies=double(dielectric{1}(:));
realValues=kssolv.analysis.matgenlab.analysis.solar. ...
    parse_dielectric_data(dielectric{2});
imagValues=kssolv.analysis.matgenlab.analysis.solar. ...
    parse_dielectric_data(dielectric{3});
epsilon1=mean(realValues,2);
epsilon2=mean(imagValues,2);
evToReciprocalCm=1/(4.135667696e-15*299792458*1e2);
coefficient=2*sqrt(2)*pi*evToReciprocalCm.*energies.* ...
    sqrt(-epsilon1+sqrt(epsilon1.^2+epsilon2.^2));
end
