classdef ComplianceTensor < kssolv.analysis.matgenlab.core.Tensor
    %COMPLIANCETENSOR Elastic compliance tensor with engineering shear scale.

    methods
        function obj = ComplianceTensor(inputArray)
            scale = ones(6);
            scale(4:6, :) = 2 * scale(4:6, :);
            scale(:, 4:6) = 2 * scale(:, 4:6);
            obj@kssolv.analysis.matgenlab.core.Tensor(inputArray, scale, 4);
        end

        function value = asDict(obj, voigt)
            if nargin < 2, voigt = false; end
            if voigt, inputArray = obj.voigt; else, inputArray = double(obj); end
            value = struct( ...
                "x_module", "pymatgen.core.elasticity.elastic", ...
                "x_class", "ComplianceTensor", ...
                "input_array", inputArray);
            if voigt, value.voigt = true; end
        end
    end

    methods (Static)
        function obj = from_voigt(values)
            values = double(values);
            if ~isequal(size(values), [6, 6])
                error("KSSOLV:Matgenlab:ComplianceTensor:VoigtShape", ...
                    "Compliance Voigt input must be 6-by-6.");
            end
            scale = ones(6);
            scale(4:6, :) = 2 * scale(4:6, :);
            scale(:, 4:6) = 2 * scale(:, 4:6);
            unscaled = values ./ scale;
            base = kssolv.analysis.matgenlab.core.Tensor. ...
                from_voigt(unscaled);
            obj = kssolv.analysis.matgenlab.core. ...
                ComplianceTensor(double(base));
        end

        function obj = from_dict(value)
            if isfield(value, "voigt") && value.voigt
                obj = kssolv.analysis.matgenlab.core. ...
                    ComplianceTensor.from_voigt(value.input_array);
            else
                obj = kssolv.analysis.matgenlab.core. ...
                    ComplianceTensor(value.input_array);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core. ...
                ComplianceTensor.from_dict(value);
        end
    end

    methods (Access = protected)
        function result = newLike(~, values, vscale) %#ok<INUSD>
            result = kssolv.analysis.matgenlab.core. ...
                ComplianceTensor(values);
        end
    end
end
