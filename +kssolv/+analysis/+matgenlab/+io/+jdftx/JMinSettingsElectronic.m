classdef JMinSettingsElectronic < kssolv.analysis.matgenlab.io.jdftx.JMinSettings
    %JMINSETTINGSELECTRONIC Electronic minimizer settings.
    methods
        function obj = JMinSettingsElectronic(params)
            if nargin < 1
                params = struct();
            end
            obj@kssolv.analysis.matgenlab.io.jdftx.JMinSettings(params);
        end
    end
end
