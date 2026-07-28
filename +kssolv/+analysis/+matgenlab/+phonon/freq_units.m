function value=freq_units(units)
%FREQ_UNITS Return pymatgen-compatible phonon frequency units.
import kssolv.analysis.matgenlab.core.Constants
import kssolv.analysis.matgenlab.phonon.FreqUnits
key=lower(strtrim(string(units)));
switch key
    case "thz"
        value=FreqUnits(1,"THz");
    case "ev"
        value=FreqUnits(Constants.value( ...
            "hertz-electron volt relationship")*Constants.tera,"eV");
    case "mev"
        value=FreqUnits(Constants.value( ...
            "hertz-electron volt relationship")*Constants.tera/ ...
            Constants.milli,"meV");
    case "ha"
        value=FreqUnits(Constants.value( ...
            "hertz-hartree relationship")*Constants.tera,"Ha");
    case {"cm-1","cm^-1"}
        value=FreqUnits(Constants.value( ...
            "hertz-inverse meter relationship")*Constants.tera* ...
            Constants.centi,"cm^{-1}");
    otherwise
        error("KSSOLV:Matgenlab:PhononPlotter:Units", ...
            "Value for units `%s` unknown.",units);
end
end
