classdef DielectricAnalysis
    %DIELECTRICANALYSIS Optical properties derived from dielectric tensors.

    properties (SetAccess = private)
        energies double
        eps_real double
        eps_imag double
        wavelengths double
        n double
        k double
        R double
        L double
        T double
    end

    methods
        function obj = DielectricAnalysis(energies, eps_real, eps_imag)
            obj.energies = double(energies);
            obj.eps_real = double(eps_real);
            obj.eps_imag = double(eps_imag);
            % scipy.constants CODATA values frozen by pymatgen 2026.5.4.
            obj.wavelengths = 1239.8419843320028 ./ obj.energies;
            magnitude = sqrt(obj.eps_real .^ 2 + obj.eps_imag .^ 2);
            obj.n = sqrt(magnitude + obj.eps_real) ./ sqrt(2);
            obj.k = sqrt(magnitude - obj.eps_real) ./ sqrt(2);
            obj.R = ((obj.n - 1) .^ 2 + obj.k .^ 2) ./ ...
                ((obj.n + 1) .^ 2 + obj.k .^ 2);
            obj.L = obj.eps_imag ./ ...
                (obj.eps_real .^ 2 + obj.eps_imag .^ 2);
            obj.T = 1 - obj.R - obj.L;
        end
    end

    methods (Static)
        function obj = from_vasprun(vasprun)
            dielectric = vasprun.dielectric;
            obj = kssolv.analysis.matgenlab.analysis.DielectricAnalysis( ...
                dielectric{1}, dielectric{2}, dielectric{3});
        end
    end
end
