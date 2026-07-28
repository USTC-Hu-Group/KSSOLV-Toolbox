classdef ExcitationSpectrum < kssolv.analysis.matgenlab.core.Spectrum
    %EXCITATIONSPECTRUM Energy/intensity spectrum specialization.

    methods
        function obj = ExcitationSpectrum(x, y)
            obj@kssolv.analysis.matgenlab.core.Spectrum(x, y);
        end
    end

    methods (Access = protected)
        function value = xLabel(~), value = "Energy (eV)"; end
        function value = yLabel(~), value = "Intensity"; end
    end
end
