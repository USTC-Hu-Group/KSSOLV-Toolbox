classdef JMinSettingsFluid < kssolv.analysis.matgenlab.io.jdftx.JMinSettings
    %JMINSETTINGSFLUID Fluid minimizer settings.
    methods
        function obj = JMinSettingsFluid(params)
            if nargin < 1
                params = struct();
            end
            obj@kssolv.analysis.matgenlab.io.jdftx.JMinSettings(params);
        end
    end
end
