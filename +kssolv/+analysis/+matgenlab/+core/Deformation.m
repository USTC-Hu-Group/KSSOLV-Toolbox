classdef Deformation < kssolv.analysis.matgenlab.core.SquareTensor
    %DEFORMATION Three-dimensional deformation-gradient tensor.

    properties (Dependent, SetAccess = private)
        green_lagrange_strain
    end

    methods
        function obj = Deformation(deformationGradient, vscale)
            if nargin < 2, vscale = []; end
            deformationGradient = double(deformationGradient);
            obj@kssolv.analysis.matgenlab.core.SquareTensor( ...
                deformationGradient, vscale);
        end

        function result = is_independent(obj, tolerance)
            if nargin < 2, tolerance = 1e-8; end
            result = size(obj.get_perturbed_indices(tolerance), 1) == 1;
        end

        function indices = get_perturbed_indices(obj, tolerance)
            if nargin < 2, tolerance = 1e-8; end
            [rows, columns] = find(abs(double(obj) - eye(3)) > tolerance);
            indices = [rows, columns];
        end

        function result = get.green_lagrange_strain(obj)
            result = ...
                kssolv.analysis.matgenlab.core.Strain.from_deformation(obj);
        end

        function structure = apply_to_structure(obj, structure)
            structure = structure.copy();
            oldLattice = structure.lattice.matrix;
            newLattice = (double(obj) * oldLattice.').';
            structure = structure.set_lattice_preserve_fractional( ...
                kssolv.analysis.matgenlab.core.Lattice(newLattice));
        end

        function value = asDict(obj, voigt)
            if nargin < 2, voigt = false; end
            value = asDict@kssolv.analysis.matgenlab.core.Tensor(obj, voigt);
            value.x_module = "pymatgen.core.elasticity.strain";
            value.x_class = "Deformation";
        end
    end

    methods (Static)
        function obj = from_index_amount(matrixPosition, amount)
            matrixPosition = reshape(double(matrixPosition), 1, 2);
            if any(matrixPosition < 1) || any(matrixPosition > 3)
                error("KSSOLV:Matgenlab:Deformation:Index", ...
                    "matrix_pos uses MATLAB 1-based indices from 1 to 3.");
            end
            matrix = eye(3);
            matrix(matrixPosition(1), matrixPosition(2)) = ...
                matrix(matrixPosition(1), matrixPosition(2)) + amount;
            obj = kssolv.analysis.matgenlab.core.Deformation(matrix);
        end

        function obj = from_voigt(voigtInput)
            square = ...
                kssolv.analysis.matgenlab.core.SquareTensor.from_voigt( ...
                    voigtInput);
            obj = kssolv.analysis.matgenlab.core.Deformation(double(square));
        end

        function obj = from_dict(value)
            if isfield(value, "voigt") && value.voigt
                obj = kssolv.analysis.matgenlab.core.Deformation. ...
                    from_voigt(value.input_array);
            else
                obj = kssolv.analysis.matgenlab.core.Deformation( ...
                    value.input_array);
            end
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.core.Deformation.from_dict(value);
        end
    end
end
