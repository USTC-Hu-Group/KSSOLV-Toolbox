classdef Constants
    %CONSTANTS CODATA 2022 constants used by pymatgen-core.
    %
    % This is the MATLAB counterpart of pymatgen.core.constants at
    % pymatgen-core v2026.7.24.  Constants that are exact under the 2019 SI
    % definition are kept as decimal literals to make reference comparisons
    % reproducible.

    properties (Constant)
        e = 1.602176634e-19
        N_A = 6.02214076e23
        Avogadro = 6.02214076e23
        Boltzmann = 1.380649e-23
        k = 1.380649e-23
        h = 6.62607015e-34
        hbar = 1.0545718176461565e-34
        c = 299792458.0
        m_e = 9.1093837139e-31
        epsilon_0 = 8.8541878188e-12
        R = 8.31446261815324
        mile = 1609.3439999999998
        calorie = 4.184
        tera = 1e12
        milli = 1e-3
        centi = 1e-2
    end

    methods (Static)
        function constants = physical_constants()
            %PHYSICAL_CONSTANTS CODATA values keyed by their scipy names.
            names = [ ...
                "electron volt-hartree relationship"
                "atomic mass unit-kilogram relationship"
                "Bohr radius"
                "Boltzmann constant in eV/K"
                "atomic unit of length"
                "Rydberg constant times hc in eV"
                "Boltzmann constant in Hz/K"
                "hertz-joule relationship"
                "hertz-electron volt relationship"
                "hertz-hartree relationship"
                "hertz-inverse meter relationship"
                "Angstrom star"
                "Planck constant"
                "Boltzmann constant"];
            values = { ...
                {0.036749322175665, "E_h", 4e-14}
                {1.66053906892e-27, "kg", 5.2e-37}
                {5.29177210544e-11, "m", 8.2e-21}
                {8.617333262145179e-5, "eV K^-1", 0.0}
                {5.29177210544e-11, "m", 8.2e-21}
                {13.60569312299, "eV", 1.5e-11}
                {20836619123.327576, "Hz K^-1", 0.0}
                {6.62607015e-34, "J", 0.0}
                {4.135667696923859e-15, "eV", 0.0}
                {1.5198298460574e-16, "E_h", 1.7e-28}
                {3.3356409519815204e-9, "m^-1", 0.0}
                {1.00001495e-10, "m", 9e-17}
                {6.62607015e-34, "J Hz^-1", 0.0}
                {1.380649e-23, "J K^-1", 0.0}};
            constants = dictionary(names, values);
        end

        function result = value(key)
            arguments
                key (1,1) string
            end
            constants = ...
                kssolv.analysis.matgenlab.core.Constants.physical_constants();
            if ~isKey(constants, key)
                error("KSSOLV:Matgenlab:Constants:UnknownConstant", ...
                    "Unknown physical constant '%s'.", key);
            end
            entry = constants(key);
            if iscell(entry) && isscalar(entry) && iscell(entry{1})
                entry = entry{1};
            end
            result = entry{1};
        end
    end
end
