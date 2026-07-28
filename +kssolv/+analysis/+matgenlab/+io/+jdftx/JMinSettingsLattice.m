classdef JMinSettingsLattice < kssolv.analysis.matgenlab.io.jdftx.JMinSettings
    %JMINSETTINGSLATTICE Lattice minimizer settings.
    methods
        function obj = JMinSettingsLattice(params)
            if nargin < 1
                params = struct();
            end
            obj@kssolv.analysis.matgenlab.io.jdftx.JMinSettings(params);
        end
    end
end
