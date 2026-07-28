classdef NDCalculator < ...
        kssolv.analysis.matgenlab.analysis.AbstractDiffractionPatternCalculator
    %NDCALCULATOR Calculate powder neutron diffraction patterns.

    properties (SetAccess = private)
        wavelength (1,1) double = 1.54184
        symprec (1,1) double = 0
        debye_waller_factors = struct()
    end

    methods
        function obj = NDCalculator(wavelength, symprec, debyeWallerFactors)
            if nargin >= 1 && ~isempty(wavelength)
                obj.wavelength = double(wavelength);
            end
            if nargin >= 2 && ~isempty(symprec)
                obj.symprec = double(symprec);
            end
            if nargin >= 3 && ~isempty(debyeWallerFactors)
                obj.debye_waller_factors = debyeWallerFactors;
            end
            if ~isscalar(obj.wavelength) || ...
                    ~isfinite(obj.wavelength) || obj.wavelength <= 0
                error("KSSOLV:Matgenlab:NDCalculator:Wavelength", ...
                    "wavelength must be a finite positive scalar.");
            end
        end

        function pattern = get_pattern( ...
                obj, structure, scaled, two_theta_range)
            if nargin < 3 || isempty(scaled), scaled = true; end
            if nargin < 4, two_theta_range = [0, 90]; end
            pattern = ...
                kssolv.analysis.matgenlab.analysis. ...
                powder_diffraction_pattern( ...
                "neutron", structure, obj.wavelength, obj.symprec, ...
                obj.debye_waller_factors, logical(scaled), ...
                two_theta_range);
        end
    end
end
