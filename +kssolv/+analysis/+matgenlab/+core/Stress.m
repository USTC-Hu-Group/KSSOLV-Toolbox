classdef Stress < kssolv.analysis.matgenlab.core.SquareTensor
    %STRESS Cauchy stress tensor with common scalar invariants.

    properties (Dependent, SetAccess = private)
        dev_principal_invariants
        von_mises
        mean_stress
        deviator_stress
    end

    methods
        function obj = Stress(stressMatrix, vscale)
            if nargin < 2, vscale = []; end
            stressMatrix = double(stressMatrix);
            obj@kssolv.analysis.matgenlab.core.SquareTensor( ...
                stressMatrix, vscale);
        end

        function value = get.dev_principal_invariants(obj)
            invariants = obj.deviator_stress.principal_invariants;
            value = invariants .* [1, -1, 1];
        end

        function value = get.von_mises(obj)
            obj.requireSymmetric("Von Mises stress");
            invariants = obj.dev_principal_invariants;
            value = sqrt(3 * invariants(2));
        end

        function value = get.mean_stress(obj)
            value = trace(double(obj)) / 3;
        end

        function value = get.deviator_stress(obj)
            value = kssolv.analysis.matgenlab.core.Stress( ...
                double(obj) - obj.mean_stress * eye(3));
        end

        function value = piola_kirchoff_1(obj, deformationGradient)
            deformation = kssolv.analysis.matgenlab.core. ...
                SquareTensor(double(deformationGradient));
            value = kssolv.analysis.matgenlab.core.Stress( ...
                deformation.det * double(obj) * ...
                double(deformation.inv.trans));
        end

        function value = piola_kirchoff_2(obj, deformationGradient)
            deformation = kssolv.analysis.matgenlab.core. ...
                SquareTensor(double(deformationGradient));
            value = kssolv.analysis.matgenlab.core.Stress( ...
                deformation.det * double(deformation.inv) * ...
                double(obj) * double(deformation.inv.trans));
        end

        function value = asDict(obj, voigt)
            if nargin < 2, voigt = false; end
            value = asDict@kssolv.analysis.matgenlab.core.Tensor(obj, voigt);
            value.x_module = "pymatgen.core.elasticity.stress";
            value.x_class = "Stress";
        end
    end

    methods (Access = protected)
        function requireSymmetric(obj, operation)
            if max(abs(double(obj) - double(obj).'), [], "all") > 1e-8
                error("KSSOLV:Matgenlab:Stress:Symmetry", ...
                    "The stress tensor is not symmetric; %s requires one.", ...
                    operation);
            end
        end
    end

    methods (Static)
        function obj = from_voigt(values)
            tensor = kssolv.analysis.matgenlab.core.SquareTensor. ...
                from_voigt(values);
            obj = kssolv.analysis.matgenlab.core.Stress(double(tensor));
        end

        function obj = from_dict(value)
            if isfield(value, "voigt") && value.voigt
                obj = kssolv.analysis.matgenlab.core.Stress. ...
                    from_voigt(value.input_array);
            else
                obj = kssolv.analysis.matgenlab.core.Stress( ...
                    value.input_array);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Stress.from_dict(value);
        end
    end
end
