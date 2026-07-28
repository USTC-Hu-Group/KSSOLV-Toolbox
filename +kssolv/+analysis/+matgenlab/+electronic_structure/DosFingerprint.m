classdef DosFingerprint
    %DOSFINGERPRINT Immutable density-of-states fingerprint record.

    properties (SetAccess = immutable)
        energies
        densities
        fp_type (1,1) string
        n_bins (1,1) double
        bin_width (1,1) double
    end

    methods
        function obj = DosFingerprint(energies, densities, fpType, ...
                nBins, binWidth)
            obj.energies = double(energies);
            obj.densities = double(densities);
            obj.fp_type = string(fpType);
            obj.n_bins = double(nBins);
            obj.bin_width = double(binWidth);
        end
    end
end
