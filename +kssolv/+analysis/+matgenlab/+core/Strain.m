classdef Strain < kssolv.analysis.matgenlab.core.SquareTensor
    %STRAIN Symmetric Green-Lagrange strain tensor.

    properties (Dependent, SetAccess = private)
        von_mises_strain
    end

    methods
        function obj = Strain(strainMatrix, varargin)
            strainMatrix = double(strainMatrix);
            if isvector(strainMatrix) && numel(strainMatrix) == 6
                strainMatrix = reshape(strainMatrix, 1, 6);
                strainMatrix(4:6) = strainMatrix(4:6) / 2;
                square = ...
                    kssolv.analysis.matgenlab.core.SquareTensor. ...
                    from_voigt(strainMatrix);
                strainMatrix = double(square);
            end
            obj@kssolv.analysis.matgenlab.core.SquareTensor( ...
                strainMatrix, [1, 1, 1, 2, 2, 2]);
            if max(abs(strainMatrix - strainMatrix.'), [], "all") > 1e-8
                error("KSSOLV:Matgenlab:Strain:Symmetry", ...
                    "Strain must be initialized with a symmetric matrix.");
            end
            % varargin accepts Tensor.newLike's vscale argument.
        end

        function result = get_deformation_matrix(obj, shape)
            if nargin < 2, shape = "upper"; end
            result = kssolv.analysis.matgenlab.core. ...
                convert_strain_to_deformation(obj, shape);
        end

        function value = get.von_mises_strain(obj)
            strain = double(obj);
            deviator = strain - trace(strain) / 3 * eye(3);
            value = sqrt(sum(deviator .* deviator, "all") * 2 / 3);
        end

        function value = asDict(obj, voigt)
            if nargin < 2, voigt = false; end
            value = asDict@kssolv.analysis.matgenlab.core.Tensor(obj, voigt);
            value.x_module = "pymatgen.core.elasticity.strain";
            value.x_class = "Strain";
        end
    end

    methods (Static)
        function obj = from_deformation(deformation)
            matrix = double(deformation);
            obj = kssolv.analysis.matgenlab.core.Strain( ...
                0.5 * (matrix.' * matrix - eye(3)));
        end

        function obj = from_index_amount(index, amount)
            if isscalar(index)
                if index < 1 || index > 6 || index ~= fix(index)
                    error("KSSOLV:Matgenlab:Strain:Index", ...
                        "Voigt index uses MATLAB 1-based values from 1 to 6.");
                end
                voigt = zeros(1, 6);
                voigt(index) = amount;
                obj = kssolv.analysis.matgenlab.core.Strain(voigt);
                return
            end
            index = reshape(double(index), 1, []);
            if numel(index) ~= 2 || any(index < 1) || any(index > 3)
                error("KSSOLV:Matgenlab:Strain:Index", ...
                    "Index must be a 2-tuple or a Voigt index.");
            end
            matrix = zeros(3);
            matrix(index(1), index(2)) = amount;
            matrix(index(2), index(1)) = amount;
            obj = kssolv.analysis.matgenlab.core.Strain(matrix);
        end

        function obj = from_voigt(voigtInput)
            obj = kssolv.analysis.matgenlab.core.Strain(voigtInput);
        end

        function obj = from_dict(value)
            if isfield(value, "voigt") && value.voigt
                obj = kssolv.analysis.matgenlab.core.Strain. ...
                    from_voigt(value.input_array);
            else
                obj = kssolv.analysis.matgenlab.core.Strain( ...
                    value.input_array);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Strain.from_dict(value);
        end
    end
end
