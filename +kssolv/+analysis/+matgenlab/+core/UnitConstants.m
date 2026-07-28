classdef UnitConstants
    %UNITCONSTANTS Public conversion constants from pymatgen.core.units.

    properties (Constant)
        Ha_to_eV = 27.21138624598059
        eV_to_Ha = 1 / 27.21138624598059
        Ry_to_eV = 27.21138624598059 / 2
        amu_to_kg = 1.66053906892e-27
        mile_to_meters = 1609.3439999999998
        bohr_to_angstrom = 0.529177210544
        bohr_to_ang = 0.529177210544
        ang_to_bohr = 1 / 0.529177210544
        kCal_to_kJ = 4.184
        kb = 8.617333262145179e-5
    end
end
