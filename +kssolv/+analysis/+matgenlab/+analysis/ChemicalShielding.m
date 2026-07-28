classdef ChemicalShielding < kssolv.analysis.matgenlab.core.SquareTensor
    %CHEMICALSHIELDING NMR chemical-shielding tensor notations.

    properties (Dependent, SetAccess = private)
        principal_axis_system
        haeberlen_values
        mehring_values
        maryland_values
    end

    methods
        function obj = ChemicalShielding(input, vscale)
            if nargin < 2, vscale = []; end
            if isvector(input) && numel(input) == 3
                input = diag(double(input));
            end
            if ~isequal(size(input), [3,3])
                error("KSSOLV:Matgenlab:ChemicalShielding:InvalidShape", ...
                    "ChemicalShielding input must be length 3 or 3-by-3.");
            end
            obj@kssolv.analysis.matgenlab.core.SquareTensor(input, vscale);
        end

        function value = get.principal_axis_system(obj)
            eigenvalues = sort(eig(double(obj.symmetrized)));
            value = kssolv.analysis.matgenlab.analysis. ...
                ChemicalShielding(diag(eigenvalues));
        end

        function value = get.haeberlen_values(obj)
            diagonal = diag(double(obj.principal_axis_system));
            sigmaIso = trace(double(obj.principal_axis_system)) / 3;
            [~, order] = sort(abs(diagonal - sigmaIso));
            sigmaYy = diagonal(order(1));
            sigmaXx = diagonal(order(2));
            sigmaZz = diagonal(order(3));
            delta = sigmaZz - 0.5 * (sigmaXx + sigmaYy);
            zeta = sigmaZz - sigmaIso;
            value = struct("sigma_iso", sigmaIso, ...
                "delta_sigma_iso", delta, "zeta", zeta, ...
                "eta", (sigmaYy - sigmaXx) / zeta);
        end

        function value = get.mehring_values(obj)
            diagonal = diag(double(obj.principal_axis_system));
            value = struct("sigma_iso", sum(diagonal) / 3, ...
                "sigma_11", diagonal(1), "sigma_22", diagonal(2), ...
                "sigma_33", diagonal(3));
        end

        function value = get.maryland_values(obj)
            diagonal = diag(double(obj.principal_axis_system));
            sigmaIso = sum(diagonal) / 3;
            omega = diagonal(3) - diagonal(1);
            value = struct("sigma_iso", sigmaIso, "omega", omega, ...
                "kappa", 3 * (diagonal(2) - sigmaIso) / omega);
        end
    end

    methods (Static)
        function obj = from_maryland_notation(sigmaIso, omega, kappa)
            sigma22 = sigmaIso + kappa * omega / 3;
            sigma11 = (3 * sigmaIso - omega - sigma22) / 2;
            sigma33 = 3 * sigmaIso - sigma22 - sigma11;
            obj = kssolv.analysis.matgenlab.analysis. ...
                ChemicalShielding([sigma11, sigma22, sigma33]);
        end
    end
end
