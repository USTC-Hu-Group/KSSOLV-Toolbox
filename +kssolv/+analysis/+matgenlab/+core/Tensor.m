classdef Tensor < kssolv.analysis.matgenlab.util.MSONable
    %TENSOR General three-dimensional Cartesian tensor.
    %
    % Tensor wraps a MATLAB numeric array while preserving pymatgen's tensor
    % operations and Voigt conventions. Parenthesis indexing is forwarded to
    % the wrapped numeric array and is therefore MATLAB 1-based.

    properties (Constant)
        symbol = "T"
    end

    properties (SetAccess = private)
        data double
        rank (1,1) double
        vscale double
    end

    properties (Dependent, SetAccess = private)
        symmetrized
        voigt_symmetrized
        voigt
    end

    methods
        function obj = Tensor(input_array, vscale, check_rank)
            arguments
                input_array {mustBeNumeric}
                vscale double = []
                check_rank = []
            end
            input_array = double(input_array);
            rank = kssolv.analysis.matgenlab.core.Tensor.tensorRank( ...
                input_array);
            if ~isempty(check_rank) && rank ~= check_rank
                error("KSSOLV:Matgenlab:Tensor:RankMismatch", ...
                    "%s input must be rank %d", ...
                    kssolv.analysis.matgenlab.core.Tensor.shortClass(obj), ...
                    check_rank);
            end
            shape = kssolv.analysis.matgenlab.core.Tensor.tensorShape( ...
                input_array, rank);
            if any(shape ~= 3)
                error("KSSOLV:Matgenlab:Tensor:InvalidDimension", ...
                    "Pymatgen only supports 3-dimensional tensors, and " + ...
                    "default tensor constructor uses standard notation. " + ...
                    "To construct from Voigt notation, use %s.from_voigt", ...
                    kssolv.analysis.matgenlab.core.Tensor.shortClass(obj));
            end
            expectedVshape = ...
                kssolv.analysis.matgenlab.core.Tensor.voigtShape(rank);
            if isempty(vscale)
                vscale = ones(expectedVshape);
            elseif ~isequal(size(vscale), size(ones(expectedVshape)))
                if ~(isvector(vscale) && isvector(ones(expectedVshape)) && ...
                        numel(vscale) == prod(expectedVshape))
                    error("KSSOLV:Matgenlab:Tensor:InvalidVoigtScale", ...
                        "Voigt scaling matrix must be the shape of the Voigt notation matrix or vector.");
                end
                vscale = reshape(vscale, expectedVshape);
            end
            obj.data = input_array;
            obj.rank = rank;
            obj.vscale = double(vscale);
        end

        function value = double(obj)
            value = obj.data;
        end

        function result = copy(obj)
            result = obj.newLike(obj.data, obj.vscale);
        end

        function varargout = size(obj, varargin)
            [varargout{1:nargout}] = size(obj.data, varargin{:});
        end

        function n = length(obj)
            n = length(obj.data);
        end

        function ind = end(obj, k, n)
            shape = size(obj.data);
            if k < n
                ind = shape(k);
            else
                ind = prod(shape(k:end));
            end
        end

        function varargout = subsref(obj, subscript)
            if subscript(1).type == "()"
                result = obj.data(subscript(1).subs{:});
                if numel(subscript) > 1
                    result = builtin("subsref", result, subscript(2:end));
                end
                varargout{1} = result;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, subscript);
            end
        end

        function obj = subsasgn(obj, subscript, value)
            if subscript(1).type == "()"
                if isa(value, "kssolv.analysis.matgenlab.core.Tensor")
                    value = double(value);
                end
                obj.data = builtin("subsasgn", obj.data, subscript, value);
            else
                obj = builtin("subsasgn", obj, subscript, value);
            end
        end

        function result = plus(left, right)
            [leftData, rightData, template] = ...
                kssolv.analysis.matgenlab.core.Tensor.operands(left, right);
            result = template.newLike(leftData + rightData, template.vscale);
        end

        function result = minus(left, right)
            [leftData, rightData, template] = ...
                kssolv.analysis.matgenlab.core.Tensor.operands(left, right);
            result = template.newLike(leftData - rightData, template.vscale);
        end

        function result = times(left, right)
            [leftData, rightData, template] = ...
                kssolv.analysis.matgenlab.core.Tensor.operands(left, right);
            result = template.newLike(leftData .* rightData, template.vscale);
        end

        function result = mtimes(left, right)
            if isa(left, "kssolv.analysis.matgenlab.core.Tensor") && ...
                    isa(right, "kssolv.analysis.matgenlab.core.Tensor")
                result = double(left) * double(right);
            elseif isa(left, "kssolv.analysis.matgenlab.core.Tensor") && ...
                    isscalar(right)
                result = times(left, right);
            elseif isa(right, "kssolv.analysis.matgenlab.core.Tensor") && ...
                    isscalar(left)
                result = times(left, right);
            else
                if isa(left, "kssolv.analysis.matgenlab.core.Tensor")
                    result = double(left) * right;
                else
                    result = left * double(right);
                end
            end
        end

        function result = rdivide(left, right)
            [leftData, rightData, template] = ...
                kssolv.analysis.matgenlab.core.Tensor.operands(left, right);
            result = template.newLike(leftData ./ rightData, template.vscale);
        end

        function result = mrdivide(left, right)
            if isa(left, "kssolv.analysis.matgenlab.core.Tensor") && ...
                    isscalar(right)
                result = rdivide(left, right);
            else
                result = double(left) / double(right);
            end
        end

        function result = uminus(obj)
            result = obj.newLike(-obj.data, obj.vscale);
        end

        function result = abs(obj)
            result = abs(obj.data);
        end

        function tf = eq(left, right)
            tf = double(left) == double(right);
        end

        function tf = ne(left, right)
            tf = ~(left == right);
        end

        function result = zeroed(obj, tol)
            arguments
                obj
                tol (1,1) double {mustBeNonnegative} = 0.001
            end
            values = obj.data;
            values(abs(values) < tol) = 0;
            result = obj.newLike(values, obj.vscale);
        end

        function result = transform(obj, symm_op)
            if ~isa(symm_op, "kssolv.analysis.matgenlab.core.SymmOp")
                error("KSSOLV:Matgenlab:Tensor:InvalidSymmetryOperation", ...
                    "symm_op must be a SymmOp.");
            end
            result = obj.newLike( ...
                symm_op.transform_tensor(obj.data), obj.vscale);
        end

        function result = rotate(obj, matrix, tol)
            arguments
                obj
                matrix
                tol (1,1) double {mustBeNonnegative} = 0.001
            end
            rotation = kssolv.analysis.matgenlab.core.SquareTensor( ...
                double(matrix));
            if ~rotation.is_rotation(tol)
                error("KSSOLV:Matgenlab:Tensor:InvalidRotation", ...
                    "Rotation matrix is not valid.");
            end
            operation = kssolv.analysis.matgenlab.core.SymmOp. ...
                from_rotation_and_translation(double(rotation), [0,0,0]);
            result = obj.transform(operation);
        end

        function result = einsum_sequence(obj, other_arrays, einsum_string)
            arguments
                obj
                other_arrays cell
                einsum_string (1,1) string = ""
            end
            arrays = [{obj.data}, cellfun(@doubleArray, other_arrays, ...
                UniformOutput = false)];
            if einsum_string == ""
                letters = 'abcdefghijklmnopqrstuvwxyz';
                expression = string(letters(1:obj.rank));
                otherRanks = cellfun(@(array) ...
                    kssolv.analysis.matgenlab.core.Tensor.arrayRank(array), ...
                    arrays(2:end));
                index = obj.rank - sum(otherRanks) + 1;
                for arrayRank = otherRanks
                    expression = expression + "," + ...
                        string(letters(index:index+arrayRank-1));
                    index = index + arrayRank;
                end
                einsum_string = expression;
            end
            result = kssolv.analysis.matgenlab.core.Tensor. ...
                einsum(einsum_string, arrays);
        end

        function result = project(obj, direction)
            unitVector = ...
                kssolv.analysis.matgenlab.core.get_uvec(direction);
            result = obj.einsum_sequence( ...
                repmat({unitVector}, 1, obj.rank));
        end

        function result = average_over_unit_sphere(obj, quad)
            if nargin < 2 || isempty(quad)
                quad = ...
                    kssolv.analysis.matgenlab.core.Tensor.defaultQuadrature();
            end
            if isa(quad, "dictionary")
                points = quad("points");
                weights = quad("weights");
            else
                points = quad.points;
                weights = quad.weights;
            end
            result = 0;
            for index = 1:numel(weights)
                result = result + weights(index) * ...
                    obj.project(points(index,:));
            end
        end

        function groups = get_grouped_indices(obj, voigt, options)
            arguments
                obj
                voigt (1,1) logical = false
                options.atol (1,1) double {mustBeNonnegative} = 1e-8
                options.rtol (1,1) double {mustBeNonnegative} = 1e-5
            end
            if voigt
                values = obj.voigt;
            else
                values = obj.data;
            end
            allSubs = ...
                kssolv.analysis.matgenlab.core.Tensor.allSubscripts( ...
                size(values), kssolv.analysis.matgenlab.core.Tensor. ...
                arrayRank(values));
            remaining = true(size(allSubs,1),1);
            groups = {};
            targets = [0; values(:)];
            for targetIndex = 1:numel(targets)
                if targetIndex == 1
                    target = 0;
                else
                    first = find(remaining, 1);
                    if isempty(first)
                        break
                    end
                    target = values(kssolv.analysis.matgenlab.core.Tensor. ...
                        subscriptIndex(size(values), allSubs(first,:)));
                end
                closeMask = abs(values(:) - target) <= ...
                    options.atol + options.rtol * abs(target);
                selectedLinear = find(closeMask);
                selected = allSubs(selectedLinear,:);
                selectedRemaining = remaining(selectedLinear);
                selected = selected(selectedRemaining,:);
                selectedLinear = selectedLinear(selectedRemaining);
                if ~isempty(selected)
                    groups{end+1} = selected; %#ok<AGROW>
                    remaining(selectedLinear) = false;
                end
                if ~any(remaining)
                    break
                end
            end
        end

        function result = get_symbol_dict(obj, voigt, zero_index, options)
            arguments
                obj
                voigt (1,1) logical = true
                zero_index (1,1) logical = false
                options.atol (1,1) double {mustBeNonnegative} = 1e-8
                options.rtol (1,1) double {mustBeNonnegative} = 1e-5
            end
            if voigt
                values = obj.voigt;
            else
                values = obj.data;
            end
            groups = obj.get_grouped_indices(voigt, ...
                atol = options.atol, rtol = options.rtol);
            result = struct();
            for index = 1:numel(groups)
                subs = groups{index}(1,:);
                linear = kssolv.analysis.matgenlab.core.Tensor. ...
                    subscriptIndex(size(values), subs);
                value = values(linear);
                if abs(value) <= options.atol + options.rtol * abs(value)
                    continue
                end
                if zero_index
                    subs = subs - 1;
                end
                name = char(obj.symbol + "_" + ...
                    join(string(subs), ""));
                result.(name) = value;
            end
        end

        function result = round(obj, decimals)
            arguments
                obj
                decimals (1,1) double {mustBeInteger} = 0
            end
            scale = 10 ^ decimals;
            result = obj.newLike(round(obj.data * scale) / scale, obj.vscale);
        end

        function result = get.symmetrized(obj)
            if obj.rank <= 1
                result = obj.copy();
                return
            end
            permutations = perms(1:obj.rank);
            values = zeros(size(obj.data));
            for index = 1:size(permutations,1)
                values = values + permute(obj.data, permutations(index,:));
            end
            result = obj.newLike(values / size(permutations,1), obj.vscale);
        end

        function result = get.voigt_symmetrized(obj)
            if mod(obj.rank,2) ~= 0 || obj.rank < 2
                error("KSSOLV:Matgenlab:Tensor:InvalidVoigtSymmetrization", ...
                    "V-symmetrization requires rank even and >= 2");
            end
            values = obj.voigt;
            vrank = obj.rank / 2;
            permutations = perms(1:vrank);
            average = zeros(size(values));
            for index = 1:size(permutations,1)
                if vrank == 1
                    permuted = values;
                else
                    permuted = permute(values, permutations(index,:));
                end
                average = average + permuted;
            end
            result = feval(string(class(obj)) + ".from_voigt", ...
                average / size(permutations,1));
        end

        function tf = is_symmetric(obj, tol)
            arguments
                obj
                tol (1,1) double {mustBeNonnegative} = 1e-5
            end
            tf = all(abs(obj.data - double(obj.symmetrized)) <= tol, "all");
        end

        function result = fit_to_structure(obj, structure, symprec)
            arguments
                obj
                structure
                symprec (1,1) double {mustBePositive} = 0.1
            end
            operations = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                symmetry_operations(structure, symprec);
            values = zeros(size(obj.data));
            for index = 1:numel(operations)
                values = values + ...
                    double(obj.transform(operations{index}));
            end
            result = obj.newLike(values / numel(operations), obj.vscale);
        end

        function tf = is_fit_to_structure(obj, structure, tol)
            arguments
                obj
                structure
                tol (1,1) double {mustBeNonnegative} = 0.01
            end
            fitted = obj.fit_to_structure(structure);
            tf = all(abs(obj.data - double(fitted)) <= tol, "all");
        end

        function values = get.voigt(obj)
            map = ...
                kssolv.analysis.matgenlab.core.Tensor.get_voigt_dict( ...
                obj.rank);
            vshape = ...
                kssolv.analysis.matgenlab.core.Tensor.voigtShape(obj.rank);
            values = zeros(vshape);
            for index = 1:size(map.standard_indices,1)
                source = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    subscriptIndex(size(obj.data), ...
                    map.standard_indices(index,:));
                target = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    subscriptIndex(size(values), ...
                    map.voigt_indices(index,:));
                values(target) = obj.data(source);
            end
            if ~obj.is_voigt_symmetric()
                warning("KSSOLV:Matgenlab:Tensor:NonVoigtSymmetric", ...
                    "Tensor is not symmetric, information may be lost in Voigt conversion.");
            end
            values = values .* obj.vscale;
        end

        function tf = is_voigt_symmetric(obj, tol)
            arguments
                obj
                tol (1,1) double {mustBeNonnegative} = 1e-6
            end
            swaps = floor(obj.rank / 2);
            tf = true;
            for mask = 0:(2^swaps - 1)
                order = 1:obj.rank;
                for pair = 1:swaps
                    if bitget(mask, pair)
                        start = mod(obj.rank,2) + 2*pair - 1;
                        order([start,start+1]) = order([start+1,start]);
                    end
                end
                if obj.rank > 1
                    delta = obj.data - permute(obj.data, order);
                    if any(abs(delta) > tol, "all")
                        tf = false;
                        return
                    end
                end
            end
        end

        function result = convert_to_ieee(obj, structure, initial_fit, ...
                refine_rotation)
            arguments
                obj
                structure
                initial_fit (1,1) logical = true
                refine_rotation (1,1) logical = true
            end
            rotation = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                get_ieee_rotation(structure, refine_rotation);
            result = obj;
            if initial_fit
                result = result.fit_to_structure(structure);
            end
            result = result.rotate(double(rotation), 1e-2);
        end

        function result = structure_transform(obj, original_structure, ...
                new_structure, refine_rotation)
            arguments
                obj
                original_structure
                new_structure
                refine_rotation (1,1) logical = true
            end
            first = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                get_ieee_rotation(original_structure, refine_rotation);
            second = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                get_ieee_rotation(new_structure, refine_rotation);
            result = obj.rotate(double(first));
            result = result.rotate(double(second).');
        end

        function result = populate(obj, structure, prec, maxiter, ...
                verbose, precond, vsym)
            arguments
                obj
                structure
                prec (1,1) double {mustBePositive} = 1e-5
                maxiter (1,1) double {mustBeInteger,mustBePositive} = 200
                verbose (1,1) logical = false
                precond (1,1) logical = true
                vsym (1,1) logical = true
            end
            guess = zeros(size(obj.data));
            fixedMask = abs(obj.data) > prec;
            guess(fixedMask) = obj.data(fixedMask);
            if precond
                operations = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    symmetry_operations(structure, 0.1);
                for index = 1:numel(operations)
                    rotated = operations{index}.transform_tensor(guess);
                    guess = mergeValues(guess, rotated, prec);
                end
                if vsym
                    temporary = obj.newLike(guess, obj.vscale);
                    if mod(obj.rank,2) == 0
                        % pymatgen's population preconditioner merges
                        % nonzero Voigt permutations instead of averaging
                        % them with still-unpopulated zero entries.
                        voigtGuess = temporary.voigt;
                        voigtRank = obj.rank / 2;
                        if voigtRank > 1
                            orders = perms(1:voigtRank);
                            for permutationIndex = 1:size(orders, 1)
                                voigtGuess = mergeValues(voigtGuess, ...
                                    permute(voigtGuess, ...
                                    orders(permutationIndex, :)), prec);
                            end
                        end
                        guess = double(kssolv.analysis.matgenlab.core. ...
                            Tensor.from_voigt(voigtGuess));
                    end
                end
            end
            previous = obj.newLike(guess, obj.vscale);
            converged = false;
            for iteration = 1:maxiter
                next = previous.fit_to_structure(structure);
                if vsym && mod(obj.rank,2) == 0
                    next = next.voigt_symmetrized;
                end
                difference = abs(double(previous) - double(next));
                if all(difference < prec, "all")
                    converged = true;
                    previous = next;
                    break
                end
                values = double(next);
                values(fixedMask) = obj.data(fixedMask);
                previous = obj.newLike(values, obj.vscale);
                if verbose
                    fprintf("Iteration %d: %.15g\n", ...
                        iteration-1, max(difference,[],"all"));
                end
            end
            if ~converged
                warning("KSSOLV:Matgenlab:Tensor:PopulationNotConverged", ...
                    "Populated tensor did not converge; max difference is %.15g.", ...
                    max(abs(obj.data-double(previous)),[],"all"));
            end
            result = previous;
        end

        function data = asDict(obj, voigt)
            arguments
                obj
                voigt (1,1) logical = false
            end
            if voigt
                inputArray = obj.voigt;
            else
                inputArray = obj.data;
            end
            data = struct( ...
                "x_module", "pymatgen.core.tensors", ...
                "x_class", ...
                kssolv.analysis.matgenlab.core.Tensor.shortClass(obj), ...
                "input_array", inputArray);
            if voigt
                data.voigt = true;
            end
        end

        function data = as_dict(obj, varargin)
            data = obj.asDict(varargin{:});
        end
    end

    methods (Static)
        function map = get_voigt_dict(rank)
            arguments
                rank (1,1) double {mustBeInteger,mustBeNonnegative}
            end
            standard = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                allSubscripts(repmat(3,1,max(rank,1)), rank);
            reverse = [1,6,5;6,2,4;5,4,3];
            voigtRank = mod(rank,2) + floor(rank/2);
            voigt = zeros(size(standard,1), voigtRank);
            for row = 1:size(standard,1)
                target = [];
                if mod(rank,2) == 1
                    target = standard(row,1);
                end
                for pair = 1:floor(rank/2)
                    start = mod(rank,2) + 2*pair - 1;
                    target(end+1) = reverse( ...
                        standard(row,start), standard(row,start+1)); %#ok<AGROW>
                end
                voigt(row,:) = target;
            end
            map = struct("standard_indices", standard, ...
                "voigt_indices", voigt);
        end

        function obj = from_voigt(voigt_input)
            obj = kssolv.analysis.matgenlab.core.Tensor. ...
                fromVoigtForClass(voigt_input, ...
                "kssolv.analysis.matgenlab.core.Tensor");
        end

        function rotation = get_ieee_rotation(structure, refine_rotation)
            arguments
                structure
                refine_rotation (1,1) logical = true
            end
            dataset = ...
                kssolv.analysis.matgenlab.core.Tensor.spglibDataset( ...
                structure, 0.01);
            lattice = structure.lattice.matrix;
            if isfield(dataset, "transformation_matrix")
                transform = double(dataset.transformation_matrix);
                conventional = (lattice.' / transform).';
            else
                conventional = lattice;
            end
            lengths = vecnorm(conventional,2,2);
            angles = kssolv.analysis.matgenlab.core.Lattice( ...
                conventional).angles;
            number = double(dataset.spacegroup_number);
            if number <= 2
                system = "triclinic";
            elseif number <= 15
                system = "monoclinic";
            elseif number <= 74
                system = "orthorhombic";
            elseif number <= 142
                system = "tetragonal";
            elseif number <= 167
                system = "trigonal";
            elseif number <= 194
                system = "hexagonal";
            else
                system = "cubic";
            end
            matrix = zeros(3);
            switch system
                case "cubic"
                    matrix = conventional ./ lengths;
                case "tetragonal"
                    [~, order] = sort(lengths);
                    matrix = conventional(order,:) ./ lengths(order);
                    if abs(lengths(3)-lengths(2)) < ...
                            abs(lengths(2)-lengths(1))
                        matrix([1,3],:) = matrix([3,1],:);
                    end
                    matrix(2,:) = ...
                        kssolv.analysis.matgenlab.core.get_uvec( ...
                        cross(matrix(3,:), matrix(1,:)));
                case "orthorhombic"
                    [~, order] = sort(lengths);
                    normalized = conventional(order,:) ./ lengths(order);
                    matrix = circshift(normalized, 2, 1);
                case {"trigonal","hexagonal"}
                    [~, axisIndex] = min(abs(angles - 120));
                    others = setdiff(1:3, axisIndex, "stable");
                    matrix(3,:) = ...
                        kssolv.analysis.matgenlab.core.get_uvec( ...
                        conventional(axisIndex,:));
                    matrix(1,:) = ...
                        kssolv.analysis.matgenlab.core.get_uvec( ...
                        conventional(others(1),:));
                    matrix(2,:) = ...
                        kssolv.analysis.matgenlab.core.get_uvec( ...
                        cross(matrix(3,:), matrix(1,:)));
                case "monoclinic"
                    [~, uniqueIndex] = max(abs(angles - 90));
                    others = setdiff(1:3, uniqueIndex);
                    matrix(2,:) = ...
                        kssolv.analysis.matgenlab.core.get_uvec( ...
                        conventional(uniqueIndex,:));
                    [~, shortest] = min(lengths(others));
                    matrix(3,:) = conventional(others(shortest),:) / ...
                        lengths(others(shortest));
                    matrix(1,:) = cross(matrix(2,:), matrix(3,:));
                otherwise
                    [~, order] = sort(lengths);
                    matrix = conventional(order,:) ./ lengths(order);
                    matrix(2,:) = ...
                        kssolv.analysis.matgenlab.core.get_uvec( ...
                        cross(matrix(3,:), matrix(1,:)));
                    matrix(1,:) = cross(matrix(2,:), matrix(3,:));
            end
            rotation = ...
                kssolv.analysis.matgenlab.core.SquareTensor(matrix);
            if refine_rotation
                rotation = rotation.refine_rotation();
            end
        end

        function obj = from_values_indices(values, indices, options)
            arguments
                values double
                indices double
                options.populate (1,1) logical = false
                options.structure = []
                options.voigt_rank = []
                options.vsym (1,1) logical = true
                options.verbose (1,1) logical = false
            end
            if size(indices,1) ~= numel(values)
                error("KSSOLV:Matgenlab:Tensor:ValuesIndicesMismatch", ...
                    "values and indices must have equal lengths.");
            end
            % Accept Python zero-based indices and MATLAB one-based indices.
            if any(indices(:) == 0)
                indices = indices + 1;
            end
            if ~isempty(options.voigt_rank)
                shape = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    voigtShape(options.voigt_rank);
            else
                shape = ceil(max(indices,[],1) / 3) * 3;
            end
            base = zeros(shape);
            for row = 1:size(indices,1)
                linear = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    subscriptIndex(size(base), indices(row,:));
                base(linear) = values(row);
            end
            if any(shape == 6)
                obj = kssolv.analysis.matgenlab.core.Tensor.from_voigt(base);
            else
                obj = kssolv.analysis.matgenlab.core.Tensor(base);
            end
            if options.populate
                if isempty(options.structure)
                    error("KSSOLV:Matgenlab:Tensor:MissingStructure", ...
                        "Populate option must include structure input");
                end
                obj = obj.populate(options.structure, 1e-5, 200, ...
                    options.verbose, true, options.vsym);
            elseif ~isempty(options.structure)
                obj = obj.fit_to_structure(options.structure);
            end
        end

        function obj = from_dict(data)
            if isfield(data, "voigt") && data.voigt
                obj = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    from_voigt(data.input_array);
            else
                obj = ...
                    kssolv.analysis.matgenlab.core.Tensor(data.input_array);
            end
        end

        function operations = symmetry_operations(structure, symprec)
            arguments
                structure
                symprec (1,1) double {mustBePositive} = 0.1
            end
            dataset = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                spglibDataset(structure, symprec);
            count = double(dataset.n_operations);
            operations = cell(1,count);
            lattice = structure.lattice.matrix;
            for index = 1:count
                fractionalRotation = squeeze( ...
                    dataset.rotations(index,:,:));
                cartesianRotation = ...
                    lattice.' * double(fractionalRotation) / lattice.';
                translation = ...
                    double(dataset.translations(index,:)) * lattice;
                operations{index} = ...
                    kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_rotation_and_translation( ...
                    cartesianRotation, translation);
            end
        end
    end

    methods (Access = protected)
        function result = newLike(obj, values, vscale)
            result = feval(class(obj), values, vscale);
        end
    end

    methods (Static, Access = protected)
        function obj = fromVoigtForClass(voigt_input, className)
            values = double(voigt_input);
            shape = size(values);
            if isvector(values)
                count = numel(values);
                if count == 3
                    rank = 1;
                    shape = [1,3];
                elseif count == 6
                    rank = 2;
                    shape = [1,6];
                else
                    error("KSSOLV:Matgenlab:Tensor:InvalidVoigtShape", ...
                        "Invalid shape for Voigt matrix");
                end
                values = reshape(values, shape);
            else
                dimensions = shape(shape > 1);
                if any(~ismember(dimensions,[3,6]))
                    error("KSSOLV:Matgenlab:Tensor:InvalidVoigtShape", ...
                        "Invalid shape for Voigt matrix");
                end
                rank = sum(dimensions == 3) + 2*sum(dimensions == 6);
            end
            if rank == 1
                fullShape = [1,3];
            else
                fullShape = repmat(3,1,rank);
            end
            full = zeros(fullShape);
            temp = feval(className, full);
            expected = ...
                kssolv.analysis.matgenlab.core.Tensor.voigtShape(rank);
            if ~isequal(size(values), size(zeros(expected)))
                if ~(isvector(values) && prod(expected) == numel(values))
                    error("KSSOLV:Matgenlab:Tensor:InvalidVoigtShape", ...
                        "Invalid shape for Voigt matrix");
                end
                values = reshape(values, expected);
            end
            values = values ./ temp.vscale;
            map = ...
                kssolv.analysis.matgenlab.core.Tensor.get_voigt_dict(rank);
            for index = 1:size(map.standard_indices,1)
                target = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    subscriptIndex(size(full), ...
                    map.standard_indices(index,:));
                source = ...
                    kssolv.analysis.matgenlab.core.Tensor. ...
                    subscriptIndex(size(values), ...
                    map.voigt_indices(index,:));
                full(target) = values(source);
            end
            obj = feval(className, full);
        end
    end

    methods (Static, Access = private)
        function rank = tensorRank(array)
            if isvector(array) && numel(array) == 3
                rank = 1;
            else
                rank = ndims(array);
            end
        end

        function shape = tensorShape(array, rank)
            if rank == 1
                shape = numel(array);
            else
                shape = size(array);
            end
        end

        function rank = arrayRank(array)
            if isvector(array)
                rank = 1;
            else
                rank = ndims(array);
            end
        end

        function shape = voigtShape(rank)
            if rank == 0
                shape = [1,1];
            elseif rank == 1
                shape = [1,3];
            else
                dims = [repmat(3,1,mod(rank,2)), ...
                    repmat(6,1,floor(rank/2))];
                if isscalar(dims)
                    shape = [1,dims];
                else
                    shape = dims;
                end
            end
        end

        function [leftData, rightData, template] = operands(left, right)
            if isa(left, "kssolv.analysis.matgenlab.core.Tensor")
                leftData = left.data;
                template = left;
            else
                leftData = left;
                template = right;
            end
            if isa(right, "kssolv.analysis.matgenlab.core.Tensor")
                rightData = right.data;
            else
                rightData = right;
            end
        end

        function name = shortClass(obj)
            parts = split(string(class(obj)), ".");
            name = parts(end);
        end

        function result = einsum(expression, arrays)
            expression = erase(expression, " ");
            pieces = split(expression, "->");
            inputLabels = split(pieces(1), ",");
            if numel(inputLabels) ~= numel(arrays)
                error("KSSOLV:Matgenlab:Tensor:InvalidEinsum", ...
                    "Einstein expression has the wrong number of operands.");
            end
            if numel(pieces) == 2
                outputLabels = char(pieces(2));
            else
                allLabels = char(join(inputLabels,""));
                uniqueLabels = unique(allLabels);
                outputLabels = '';
                for label = uniqueLabels
                    if sum(allLabels == label) == 1
                        outputLabels(end+1) = label; %#ok<AGROW>
                    end
                end
                outputLabels = sort(outputLabels);
            end
            labels = unique(char(join(inputLabels,"")), "stable");
            dimensions = zeros(1,numel(labels));
            for operand = 1:numel(arrays)
                operandLabels = char(inputLabels(operand));
                operandSize = size(arrays{operand});
                if isvector(arrays{operand})
                    operandSize = numel(arrays{operand});
                end
                if numel(operandLabels) ~= numel(operandSize)
                    error("KSSOLV:Matgenlab:Tensor:InvalidEinsum", ...
                        "Operand rank does not match Einstein labels.");
                end
                for index = 1:numel(operandLabels)
                    position = find(labels == operandLabels(index),1);
                    if dimensions(position) ~= 0 && ...
                            dimensions(position) ~= operandSize(index)
                        error("KSSOLV:Matgenlab:Tensor:InvalidEinsum", ...
                            "Einstein label dimensions do not agree.");
                    end
                    dimensions(position) = operandSize(index);
                end
            end
            assignments = ...
                kssolv.analysis.matgenlab.core.Tensor. ...
                allSubscripts(dimensions, numel(dimensions));
            if isempty(outputLabels)
                result = 0;
            else
                outDims = arrayfun(@(label) ...
                    dimensions(labels == label), outputLabels);
                if isscalar(outDims)
                    result = zeros(1,outDims);
                else
                    result = zeros(outDims);
                end
            end
            for row = 1:size(assignments,1)
                product = 1;
                for operand = 1:numel(arrays)
                    operandLabels = char(inputLabels(operand));
                    subs = arrayfun(@(label) ...
                        assignments(row,labels == label), operandLabels);
                    linear = ...
                        kssolv.analysis.matgenlab.core.Tensor. ...
                        subscriptIndex(size(arrays{operand}), subs);
                    product = product * arrays{operand}(linear);
                end
                if isempty(outputLabels)
                    result = result + product;
                else
                    outSubs = arrayfun(@(label) ...
                        assignments(row,labels == label), outputLabels);
                    linear = ...
                        kssolv.analysis.matgenlab.core.Tensor. ...
                        subscriptIndex(size(result), outSubs);
                    result(linear) = result(linear) + product; %#ok<AGROW>
                end
            end
        end

        function subs = allSubscripts(shape, rank)
            if rank == 0
                subs = zeros(1,0);
                return
            end
            shape = reshape(shape,1,[]);
            if rank == 1
                shape = max(shape);
            end
            shape = shape(1:rank);
            grids = cell(1,rank);
            ranges = arrayfun(@(n) 1:n, shape, UniformOutput=false);
            [grids{:}] = ndgrid(ranges{:});
            subs = zeros(prod(shape),rank);
            for index = 1:rank
                subs(:,index) = grids{index}(:);
            end
        end

        function linear = subscriptIndex(shape, subs)
            count = numel(subs);
            shape = reshape(shape,1,[]);
            if count == 1
                linear = subs(1);
                return
            end
            if numel(shape) < count
                shape(end+1:count) = 1;
            end
            args = num2cell(subs);
            shape = shape(1:count);
            linear = sub2ind(shape, args{:});
        end

        function quad = defaultQuadrature()
            % Product Gauss-Legendre/azimuth quadrature. It integrates
            % Cartesian tensor projection polynomials through degree 39,
            % exceeding the degree needed by pymatgen's material tensors.
            persistent cached
            if ~isempty(cached)
                quad = cached;
                return
            end
            n = 20;
            beta = (1:n-1) ./ sqrt(4*(1:n-1).^2 - 1);
            jacobi = diag(beta,1) + diag(beta,-1);
            [vectors, roots] = eig(jacobi, "vector");
            [z, order] = sort(roots);
            zWeights = 2 * vectors(1,order).^2;
            phiCount = 40;
            phi = (0:phiCount-1).' * (2*pi/phiCount);
            points = zeros(n*phiCount,3);
            weights = zeros(n*phiCount,1);
            row = 0;
            for zIndex = 1:n
                radius = sqrt(max(0,1-z(zIndex)^2));
                for phiIndex = 1:phiCount
                    row = row + 1;
                    points(row,:) = [ ...
                        radius*cos(phi(phiIndex)), ...
                        radius*sin(phi(phiIndex)), z(zIndex)];
                    weights(row) = zWeights(zIndex) / (2*phiCount);
                end
            end
            cached = struct("points",points,"weights",weights);
            quad = cached;
        end

        function dataset = spglibDataset(structure, symprec)
            types = int32(structure.atomic_numbers(:));
            dataset = kssolv.analysis.spglib.Spglib.getDataset( ...
                structure.lattice.matrix, structure.frac_coords, types, ...
                uint16(structure.num_sites), symprec);
            if isempty(dataset) || dataset.n_operations < 1
                error("KSSOLV:Matgenlab:Tensor:SpglibFailure", ...
                    "spglib could not determine structure symmetry.");
            end
        end
    end
end

function value = doubleArray(value)
value = double(value);
end

function merged = mergeValues(old, new, tolerance)
merged = old;
oldMask = abs(old) > tolerance;
newMask = abs(new) > tolerance;
onlyNew = ~oldMask & newMask;
both = oldMask & newMask;
merged(both) = (old(both) + new(both)) / 2;
merged(onlyNew) = new(onlyNew);
end
