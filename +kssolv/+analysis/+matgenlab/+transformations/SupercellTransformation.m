classdef SupercellTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess = private)
        scaling_matrix (3,3) double
    end
    methods
        function obj = SupercellTransformation(matrix)
            if nargin < 1, matrix = eye(3); end
            matrix = double(matrix);
            if ~isequal(size(matrix),[3,3]) || ...
                    any(matrix ~= fix(matrix),"all") || det(matrix) == 0
                error("KSSOLV:Matgenlab:SupercellTransformation:Matrix", ...
                    "Scaling matrix must be nonsingular integer 3-by-3.");
            end
            obj.scaling_matrix = matrix;
        end
        function result = apply_transformation(obj, structure, varargin)
            result = structure * obj.scaling_matrix;
        end
    end
    methods (Access = protected)
        function value = inverseTransformation(~)
            value = []; %#ok<NASGU>
            error("KSSOLV:Matgenlab:SupercellTransformation:Inverse", ...
                "A supercell transformation has no general inverse.");
        end
    end
    methods (Static)
        function obj = from_scaling_factors(a,b,c)
            if nargin < 1, a = 1; end
            if nargin < 2, b = 1; end
            if nargin < 3, c = 1; end
            obj = kssolv.analysis.matgenlab.transformations. ...
                SupercellTransformation(diag([a,b,c]));
        end
        function obj = from_boundary_distance( ...
                structure, minimum, allowRotation, maxAtoms)
            if nargin < 2, minimum = 6; end
            if nargin < 3, allowRotation = false; end
            if nargin < 4, maxAtoms = -1; end
            unit = eye(3);
            distances = arrayfun(@(index) ...
                structure.lattice.d_hkl(unit(index,:)), 1:3);
            expand = int8(minimum ./ distances);
            if allowRotation && nnz(expand) > 1
                values = double(expand);
                a=values(1);b=values(2);c=values(3);
                matrix=[max(a,1),double(a~=0&&b~=0),double(a~=0&&c~=0); ...
                    -double(b~=0&&a~=0),max(b,1),double(b~=0&&c~=0); ...
                    -double(c~=0&&a~=0),-double(c~=0&&b~=0),max(c,1)];
                candidate = structure * matrix;
                enough = arrayfun(@(index) ...
                    candidate.lattice.d_hkl(unit(index,:)) >= minimum, 1:3);
                if all(enough) && (maxAtoms < 0 || ...
                        candidate.num_sites <= maxAtoms)
                    obj = kssolv.analysis.matgenlab.transformations. ...
                        SupercellTransformation(matrix);
                    return
                end
            end
            matrix = eye(3) + diag(double(expand));
            candidate = structure * matrix;
            if maxAtoms > 0 && candidate.num_sites > maxAtoms
                error("KSSOLV:Matgenlab:SupercellTransformation:MaxAtoms", ...
                    "max_atoms exceeded while solving for a supercell.");
            end
            obj = kssolv.analysis.matgenlab.transformations. ...
                SupercellTransformation(matrix);
        end
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.transformations. ...
                SupercellTransformation(value.scaling_matrix);
        end
        function obj = fromDict(value), obj = ...
                kssolv.analysis.matgenlab.transformations. ...
                SupercellTransformation.from_dict(value); end
    end
end
