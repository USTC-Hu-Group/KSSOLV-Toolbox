classdef NthOrderElasticTensor < kssolv.analysis.matgenlab.core.Tensor
    %NTHORDERELASTICTENSOR Elastic constant tensor of arbitrary order.

    properties (Constant)
        GPa_to_eV_A3 = 0.006241509074460763
    end

    properties (Dependent, SetAccess = private)
        order
    end

    methods
        function obj = NthOrderElasticTensor(inputArray, checkRank, tol)
            if nargin < 2, checkRank = []; end
            if nargin < 3, tol = 1e-4; end
            obj@kssolv.analysis.matgenlab.core.Tensor( ...
                inputArray, [], checkRank);
            if mod(obj.rank, 2) ~= 0
                error("KSSOLV:Matgenlab:ElasticTensor:OddRank", ...
                    "ElasticTensor must have even rank.");
            end
            if ~obj.is_voigt_symmetric(tol)
                warning("KSSOLV:Matgenlab:ElasticTensor:VoigtSymmetry", ...
                    "Input elastic tensor does not satisfy standard " + ...
                    "Voigt symmetries.");
            end
        end

        function value = get.order(obj)
            value = obj.rank / 2;
        end

        function stress = calculate_stress(obj, strain)
            values = double(strain);
            if isvector(values) && numel(values) == 6
                strain = kssolv.analysis.matgenlab.core.Strain. ...
                    from_voigt(values);
            elseif isequal(size(values), [3, 3])
                strain = kssolv.analysis.matgenlab.core.Strain(values);
            else
                error("KSSOLV:Matgenlab:ElasticTensor:StrainShape", ...
                    "Strain must be 3-by-3 or length-6 Voigt notation.");
            end
            % Contract the trailing strain-index pairs directly. The
            % reshape formulation is equivalent to repeated einsum but
            % remains practical for sixth- and eighth-rank tensors.
            values = double(obj);
            strainVector = reshape(double(strain), 9, 1);
            currentRank = obj.rank;
            for contraction = 1:(obj.order - 1)
                values = reshape(values, 3^(currentRank - 2), 9) * ...
                    strainVector;
                currentRank = currentRank - 2;
                values = reshape(values, repmat(3, 1, currentRank));
            end
            values = values / factorial(obj.order - 1);
            stress = kssolv.analysis.matgenlab.core.Stress(values);
        end

        function value = energy_density(obj, strain, convertGPaToEV)
            if nargin < 3, convertGPaToEV = true; end
            strain = kssolv.analysis.matgenlab.core.Strain(strain);
            value = sum(double(obj.calculate_stress(strain)) .* ...
                double(strain), "all") / obj.order;
            if convertGPaToEV
                value = value * obj.GPa_to_eV_A3;
            end
        end

        function value = asDict(obj, voigt)
            if nargin < 2, voigt = false; end
            if voigt, inputArray = obj.voigt; else, inputArray = double(obj); end
            value = struct( ...
                "x_module", "pymatgen.core.elasticity.elastic", ...
                "x_class", "NthOrderElasticTensor", ...
                "input_array", inputArray);
            if voigt, value.voigt = true; end
        end
    end

    methods (Static)
        function obj = from_voigt(values)
            tensor = ...
                kssolv.analysis.matgenlab.core.Tensor.from_voigt(values);
            obj = kssolv.analysis.matgenlab.core. ...
                NthOrderElasticTensor(double(tensor));
        end

        function obj = from_diff_fit(strains, stresses, ...
                equilibriumStress, order, tol)
            if nargin < 3, equilibriumStress = []; end
            if nargin < 4, order = 2; end
            if nargin < 5, tol = 1e-10; end
            values = kssolv.analysis.matgenlab.core.diff_fit( ...
                strains, stresses, equilibriumStress, order, tol);
            obj = values{order - 1};
        end

        function obj = from_dict(value)
            if isfield(value, "voigt") && value.voigt
                obj = kssolv.analysis.matgenlab.core. ...
                    NthOrderElasticTensor.from_voigt( ...
                    value.input_array);
            else
                obj = kssolv.analysis.matgenlab.core. ...
                    NthOrderElasticTensor(value.input_array);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core. ...
                NthOrderElasticTensor.from_dict(value);
        end
    end

    methods (Access = protected)
        function result = newLike(obj, values, vscale) %#ok<INUSD>
            result = feval(class(obj), values);
        end
    end
end
