classdef JMinSettingsIonic < kssolv.analysis.matgenlab.io.jdftx.JMinSettings
    %JMINSETTINGSIONIC Ionic minimizer settings.
    methods
        function obj = JMinSettingsIonic(params)
            if nargin < 1
                params = struct();
            end
            obj@kssolv.analysis.matgenlab.io.jdftx.JMinSettings(params);
        end
    end
end
