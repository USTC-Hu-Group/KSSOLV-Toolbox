classdef PiezoTensor < kssolv.analysis.matgenlab.core.Tensor
    %PIEZOTENSOR Rank-three piezoelectric tensor.

    methods
        function obj = PiezoTensor(input, tolerance)
            if nargin < 2 || isempty(tolerance), tolerance = 1e-3; end
            if ndims(input) ~= 3 || ~isequal(size(input), [3,3,3])
                error("KSSOLV:Matgenlab:PiezoTensor:InvalidRank", ...
                    "PiezoTensor input must be rank 3 with shape 3-by-3-by-3.");
            end
            obj@kssolv.analysis.matgenlab.core.Tensor(input, [], 3);
            if any(abs(double(obj) - permute(double(obj), [1,3,2])) > ...
                    tolerance, "all")
                warning("KSSOLV:Matgenlab:PiezoTensor:NonSymmetric", ...
                    "Input piezo tensor does not satisfy standard symmetries.");
            end
        end
    end

    methods (Static)
        function obj = from_vasp_voigt(input)
            if ~isequal(size(input), [3,6])
                error("KSSOLV:Matgenlab:PiezoTensor:InvalidVoigtShape", ...
                    "Invalid shape for VASP Voigt matrix.");
            end
            mapping = [1,1;2,2;3,3;1,2;2,3;1,3];
            tensor = zeros(3,3,3);
            for dimension = 1:3
                for position = 1:6
                    first = mapping(position,1);
                    second = mapping(position,2);
                    tensor(dimension,first,second) = input(dimension,position);
                    tensor(dimension,second,first) = input(dimension,position);
                end
            end
            obj = kssolv.analysis.matgenlab.analysis.PiezoTensor(tensor);
        end

        function obj = from_voigt(input)
            if ~isequal(size(input), [3,6])
                error("KSSOLV:Matgenlab:PiezoTensor:InvalidVoigtShape", ...
                    "Invalid shape for Voigt matrix.");
            end
            % pymatgen Tensor Voigt ordering is xx, yy, zz, yz, xz, xy.
            vasp = input(:, [1,2,3,6,4,5]);
            obj = kssolv.analysis.matgenlab.analysis. ...
                PiezoTensor.from_vasp_voigt(vasp);
        end
    end
end
