classdef PhononDosFingerprint
    %PHONONDOSFINGERPRINT Immutable phonon DOS fingerprint record.

    properties (SetAccess = immutable)
        frequencies
        densities
        n_bins (1,1) double
        bin_width (1,1) double
    end

    methods
        function obj=PhononDosFingerprint( ...
                frequencies,densities,nBins,binWidth)
            obj.frequencies=double(frequencies);
            obj.densities=double(densities);
            obj.n_bins=double(nBins);
            obj.bin_width=double(binWidth);
        end
    end
end
