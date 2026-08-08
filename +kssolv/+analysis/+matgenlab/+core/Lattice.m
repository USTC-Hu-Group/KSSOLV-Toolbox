classdef Lattice < kssolv.analysis.matgenlab.util.MSONable
    %LATTICE Three-dimensional Bravais lattice using row lattice vectors.
    %
    % Fractional and Cartesian coordinates use N-by-3 row arrays:
    %     cartesian = fractional * matrix
    %
    % Compatible with the core behavior of pymatgen-core v2026.7.24
    % (MIT licensed), pymatgen.core.lattice.Lattice.

    properties (Access = private)
        latticeMatrix (3, 3) double
    end

    properties
        pbc = [true, true, true]
    end

    properties (Dependent, SetAccess = private)
        matrix
        lengths
        angles
        volume
        is_orthogonal
        is_3d_periodic
        inv_matrix
        metric_tensor
        a
        b
        c
        abc
        alpha
        beta
        gamma
        parameters
        params_dict
        reciprocal_lattice
        reciprocal_lattice_crystallographic
        lll_matrix
        lll_mapping
        lll_inverse
        selling_vector
    end

    methods
        function obj = Lattice(matrix, pbc)
            arguments
                matrix double
                pbc = [true, true, true]
            end
            if numel(matrix) ~= 9
                error("KSSOLV:Matgenlab:Lattice:InvalidMatrix", ...
                    "Lattice matrix must contain exactly nine elements.");
            end
            if isvector(matrix)
                matrix = reshape(matrix, 3, 3).';
            elseif ~isequal(size(matrix), [3, 3])
                error("KSSOLV:Matgenlab:Lattice:InvalidMatrix", ...
                    "Lattice matrix must be a 3-by-3 array.");
            end
            if any(~isfinite(matrix), "all")
                error("KSSOLV:Matgenlab:Lattice:NonFiniteMatrix", ...
                    "Lattice matrix entries must be finite.");
            end
            if abs(det(matrix)) <= eps(max(1, norm(matrix, "fro")))^3
                error("KSSOLV:Matgenlab:Lattice:SingularMatrix", ...
                    "Lattice matrix must be nonsingular.");
            end
            if ~islogical(pbc) || ~isvector(pbc) || numel(pbc) ~= 3
                error("KSSOLV:Matgenlab:Lattice:InvalidPbc", ...
                    "pbc must contain exactly three logical values.");
            end
            obj.latticeMatrix = double(matrix);
            obj.pbc = pbc;
        end

        function obj = set.pbc(obj, value)
            if ~islogical(value) || ~isvector(value) || numel(value) ~= 3
                error("KSSOLV:Matgenlab:Lattice:InvalidPbc", ...
                    "pbc must contain exactly three logical values.");
            end
            obj.pbc = reshape(value, 1, 3);
        end

        function value = get.matrix(obj)
            value = obj.latticeMatrix;
        end

        function value = get.lengths(obj)
            value = vecnorm(obj.latticeMatrix, 2, 2).';
        end

        function value = get.angles(obj)
            latticeVectors = obj.latticeMatrix;
            lens = obj.lengths;
            cosines = [ ...
                dot(latticeVectors(2, :), latticeVectors(3, :)) / ...
                (lens(2) * lens(3)), ...
                dot(latticeVectors(1, :), latticeVectors(3, :)) / ...
                (lens(1) * lens(3)), ...
                dot(latticeVectors(1, :), latticeVectors(2, :)) / ...
                (lens(1) * lens(2))];
            value = acosd(max(-1, min(1, cosines)));
        end

        function value = get.volume(obj)
            value = abs(det(obj.latticeMatrix));
        end

        function value = get.is_orthogonal(obj)
            value = all(abs(obj.angles - 90) < 1e-5);
        end

        function value = get.is_3d_periodic(obj)
            value = all(obj.pbc);
        end

        function value = get.inv_matrix(obj)
            value = inv(obj.latticeMatrix);
        end

        function value = get.metric_tensor(obj)
            value = obj.latticeMatrix * obj.latticeMatrix.';
        end

        function value = get.a(obj), value = obj.lengths(1); end
        function value = get.b(obj), value = obj.lengths(2); end
        function value = get.c(obj), value = obj.lengths(3); end
        function value = get.abc(obj), value = obj.lengths; end
        function value = get.alpha(obj), value = obj.angles(1); end
        function value = get.beta(obj), value = obj.angles(2); end
        function value = get.gamma(obj), value = obj.angles(3); end

        function value = get.parameters(obj)
            value = [obj.lengths, obj.angles];
        end

        function value = get.params_dict(obj)
            params = obj.parameters;
            value = struct("a", params(1), "b", params(2), "c", params(3), ...
                "alpha", params(4), "beta", params(5), "gamma", params(6));
        end

        function value = get.reciprocal_lattice(obj)
            value = kssolv.analysis.matgenlab.core.Lattice( ...
                inv(obj.latticeMatrix).' * (2 * pi), obj.pbc);
        end

        function value = get.reciprocal_lattice_crystallographic(obj)
            value = kssolv.analysis.matgenlab.core.Lattice( ...
                inv(obj.latticeMatrix).', obj.pbc);
        end

        function value = get.lll_matrix(obj)
            [value, ~] = obj.calculateLll(0.75);
        end

        function value = get.lll_mapping(obj)
            [~, value] = obj.calculateLll(0.75);
        end

        function value = get.lll_inverse(obj)
            value = inv(obj.lll_mapping);
        end

        function value = get.selling_vector(obj)
            aVec = obj.matrix(1, :);
            bVec = obj.matrix(2, :);
            cVec = obj.matrix(3, :);
            dVec = -(aVec + bVec + cVec);
            value = [dot(bVec, cVec), dot(aVec, cVec), dot(aVec, bVec), ...
                dot(aVec, dVec), dot(bVec, dVec), dot(cVec, dVec)];
            value(abs(value) <= 1e-10) = 0;
            reductions = kssolv.analysis.matgenlab.core.Lattice. ...
                sellingReductionMatrices();
            iteration = 0;
            while max(value) > 0
                iteration = iteration + 1;
                if iteration > 1000
                    error("KSSOLV:Matgenlab:Lattice:SellingReductionFailed", ...
                        "Selling reduction failed to converge.");
                end
                [~, index] = max(value);
                value = (reductions(:, :, index) * value.').';
                value(abs(value) <= 1e-10) = 0;
            end
        end

        function tf = eq(obj, other)
            tf = isa(other, "kssolv.analysis.matgenlab.core.Lattice") && ...
                isequal(obj.pbc, other.pbc) && ...
                all(abs(obj.matrix - other.matrix) <= ...
                1e-8 + 1e-5 * abs(other.matrix), "all");
        end

        function tf = ne(obj, other)
            tf = ~eq(obj, other);
        end

        function newObj = copy(obj)
            newObj = kssolv.analysis.matgenlab.core.Lattice( ...
                obj.matrix, obj.pbc);
        end

        function cartesian = get_cartesian_coords(obj, fractional)
            fractional = obj.validateCoords(fractional, "fractional coordinates");
            cartesian = fractional * obj.latticeMatrix;
        end

        function cartesian = getCartesianCoords(obj, fractional)
            cartesian = obj.get_cartesian_coords(fractional);
        end

        function fractional = get_fractional_coords(obj, cartesian)
            cartesian = obj.validateCoords(cartesian, "Cartesian coordinates");
            fractional = cartesian / obj.latticeMatrix;
        end

        function fractional = getFractionalCoords(obj, cartesian)
            fractional = obj.get_fractional_coords(cartesian);
        end

        function coordinates = get_vector_along_lattice_directions( ...
                obj, cartesian)
            coordinates = obj.get_fractional_coords(cartesian) .* obj.lengths;
        end

        function coordinates = getVectorAlongLatticeDirections(obj, cartesian)
            coordinates = obj.get_vector_along_lattice_directions(cartesian);
        end

        function distance = d_hkl(obj, millerIndex)
            if ~isvector(millerIndex) || numel(millerIndex) ~= 3
                error("KSSOLV:Matgenlab:Lattice:InvalidMillerIndex", ...
                    "Miller index must contain exactly three values.");
            end
            hkl = reshape(double(millerIndex), 1, 3);
            if all(hkl == 0)
                distance = Inf;
                return
            end
            metric = obj.reciprocal_lattice_crystallographic.metric_tensor;
            distance = 1 / sqrt(hkl * metric * hkl.');
        end

        function data = as_dict(obj, verbosity)
            if nargin < 2
                verbosity = 0;
            end
            data = struct("x_module", "pymatgen.core.lattice", ...
                "x_class", "Lattice", "matrix", obj.matrix, "pbc", obj.pbc);
            if verbosity > 0
                params = obj.params_dict;
                names = fieldnames(params);
                for idx = 1:numel(names)
                    data.(names{idx}) = params.(names{idx});
                end
                data.volume = obj.volume;
            end
        end

        function data = asDict(obj, verbosity)
            if nargin < 2, verbosity = 0; end
            data = obj.as_dict(verbosity);
        end

        function objOut = scale(obj, newVolume)
            arguments
                obj
                newVolume (1, 1) double {mustBePositive}
            end
            factor = (newVolume / obj.volume)^(1 / 3);
            objOut = kssolv.analysis.matgenlab.core.Lattice( ...
                obj.matrix * factor, obj.pbc);
        end

        function values = dot(obj, coordsA, coordsB, fracCoords)
            arguments
                obj
                coordsA double
                coordsB double
                fracCoords (1, 1) logical = false
            end
            coordsA = obj.validateCoords(coordsA, "coordsA");
            coordsB = obj.validateCoords(coordsB, "coordsB");
            if size(coordsA, 1) ~= size(coordsB, 1)
                error("KSSOLV:Matgenlab:Lattice:CoordinateCountMismatch", ...
                    "Coordinates must have the same length.");
            end
            if ~isreal(coordsA) || ~isreal(coordsB)
                error("KSSOLV:Matgenlab:Lattice:ComplexCoordinates", ...
                    "Complex arrays are not supported.");
            end
            if fracCoords
                coordsA = obj.get_cartesian_coords(coordsA);
                coordsB = obj.get_cartesian_coords(coordsB);
            end
            values = sum(coordsA .* coordsB, 2);
        end

        function values = norm(obj, coords, fracCoords)
            if nargin < 3
                fracCoords = true;
            end
            values = sqrt(obj.dot(coords, coords, fracCoords));
        end

        function [distance, image] = get_distance_and_image( ...
                obj, fracCoords1, fracCoords2, image)
            arguments
                obj
                fracCoords1 double
                fracCoords2 double
                image double = []
            end
            fracCoords1 = reshape(obj.validateCoords(fracCoords1, ...
                "fracCoords1"), 1, 3);
            fracCoords2 = reshape(obj.validateCoords(fracCoords2, ...
                "fracCoords2"), 1, 3);
            if ~isempty(image)
                if ~isvector(image) || numel(image) ~= 3
                    error("KSSOLV:Matgenlab:Lattice:InvalidImage", ...
                        "Periodic image must contain three values.");
                end
                image = reshape(image, 1, 3);
                distance = vecnorm((fracCoords2 + image - fracCoords1) * ...
                    obj.matrix);
                return
            end
            delta = fracCoords2 - fracCoords1;
            [distance, image] = obj.shortestImage(delta);
        end

        function [distance, image] = getDistanceAndImage(obj, varargin)
            [distance, image] = obj.get_distance_and_image(varargin{:});
        end

        function distances = get_all_distances(obj, fracCoords1, fracCoords2)
            fracCoords1 = obj.validateCoords(fracCoords1, "fracCoords1");
            fracCoords2 = obj.validateCoords(fracCoords2, "fracCoords2");
            count1 = size(fracCoords1, 1);
            count2 = size(fracCoords2, 1);
            distances = zeros(count1, count2);
            for idx1 = 1:count1
                for idx2 = 1:count2
                    distances(idx1, idx2) = obj.shortestImage( ...
                        fracCoords2(idx2, :) - fracCoords1(idx1, :));
                end
            end
        end

        function distances = getAllDistances(obj, fracCoords1, fracCoords2)
            distances = obj.get_all_distances(fracCoords1, fracCoords2);
        end

        function varargout = get_points_in_sphere( ...
                obj, fracPoints, center, radius, options)
            arguments
                obj
                fracPoints double
                center double
                radius (1, 1) double {mustBeNonnegative}
                options.zip_results (1, 1) logical = true
            end
            fracPoints = obj.validateCoords(fracPoints, "fracPoints");
            center = reshape(obj.validateCoords(center, "center"), 1, 3);
            if size(center, 1) ~= 1
                error("KSSOLV:Matgenlab:Lattice:InvalidCenter", ...
                    "Sphere center must be a single three-element coordinate.");
            end
            centerFrac = obj.get_fractional_coords(center);
            reciprocalLengths = obj.reciprocal_lattice.lengths;
            maxImages = ceil((radius + 0.15) * reciprocalLengths / (2 * pi));
            ranges = cell(1, 3);
            for dim = 1:3
                if obj.pbc(dim)
                    lower = floor(centerFrac(dim) - maxImages(dim) - ...
                        max(fracPoints(:, dim), [], "omitnan"));
                    upper = ceil(centerFrac(dim) + maxImages(dim) - ...
                        min(fracPoints(:, dim), [], "omitnan"));
                    ranges{dim} = lower:upper;
                else
                    ranges{dim} = 0;
                end
            end
            [i1, i2, i3] = ndgrid(ranges{1}, ranges{2}, ranges{3});
            candidateImages = [i1(:), i2(:), i3(:)];
            fractional = zeros(0, 3);
            distances = zeros(0, 1);
            indices = zeros(0, 1);
            images = zeros(0, 3);
            radiusSquared = radius^2 + 1e-12;
            for pointIndex = 1:size(fracPoints, 1)
                shifted = fracPoints(pointIndex, :) + candidateImages;
                cartDelta = obj.get_cartesian_coords(shifted) - center;
                distanceSquared = sum(cartDelta.^2, 2);
                keep = distanceSquared <= radiusSquared;
                if any(keep)
                    fractional = [fractional; shifted(keep, :)]; %#ok<AGROW>
                    distances = [distances; sqrt(distanceSquared(keep))]; %#ok<AGROW>
                    indices = [indices; repmat(pointIndex, sum(keep), 1)]; %#ok<AGROW>
                    images = [images; candidateImages(keep, :)]; %#ok<AGROW>
                end
            end
            if ~isempty(distances)
                [distances, order] = sort(distances);
                fractional = fractional(order, :);
                indices = indices(order);
                images = images(order, :);
            end
            if nargout <= 1
                if options.zip_results
                    result = cell(numel(distances), 4);
                    for idx = 1:numel(distances)
                        result(idx, :) = {fractional(idx,:), distances(idx), ...
                            indices(idx), images(idx,:)};
                    end
                else
                    result = {fractional, distances, indices, images};
                end
                varargout{1} = result;
                return
            end
            outputs = {fractional, distances, indices, images};
            varargout = outputs(1:nargout);
        end

        function varargout = getPointsInSphere(obj, varargin)
            [varargout{1:nargout}] = obj.get_points_in_sphere(varargin{:});
        end

        function varargout = get_points_in_sphere_py(obj, varargin)
            [varargout{1:nargout}] = obj.get_points_in_sphere(varargin{:});
        end

        function varargout = get_points_in_sphere_old(obj, varargin)
            [varargout{1:nargout}] = obj.get_points_in_sphere(varargin{:});
        end

        function tf = is_hexagonal(obj, hexAngleTol, hexLengthTol)
            if nargin < 2, hexAngleTol = 5; end
            if nargin < 3, hexLengthTol = 0.01; end
            rightAngles = find(abs(obj.angles - 90) <= hexAngleTol);
            hexAngles = find(abs(obj.angles - 60) <= hexAngleTol | ...
                abs(obj.angles - 120) <= hexAngleTol);
            tf = numel(rightAngles) == 2 && isscalar(hexAngles) && ...
                abs(obj.lengths(rightAngles(1)) - ...
                obj.lengths(rightAngles(2))) <= hexLengthTol;
        end

        function tf = isHexagonal(obj, varargin)
            tf = obj.is_hexagonal(varargin{:});
        end

        function reduced = get_lll_reduced_lattice(obj, delta)
            if nargin < 2, delta = 0.75; end
            if delta <= 0.25 || delta >= 1
                error("KSSOLV:Matgenlab:Lattice:InvalidLllDelta", ...
                    "LLL delta must be in the interval (0.25, 1).");
            end
            [reducedMatrix, ~] = obj.calculateLll(delta);
            reduced = kssolv.analysis.matgenlab.core.Lattice( ...
                reducedMatrix, obj.pbc);
        end

        function reduced = getLllReducedLattice(obj, delta)
            if nargin < 2, delta = 0.75; end
            reduced = obj.get_lll_reduced_lattice(delta);
        end

        function coords = get_lll_frac_coords(obj, fracCoords)
            coords = obj.validateCoords(fracCoords, "fracCoords") * ...
                obj.lll_inverse;
        end

        function coords = get_frac_coords_from_lll(obj, lllFracCoords)
            coords = obj.validateCoords(lllFracCoords, "lllFracCoords") * ...
                obj.lll_mapping;
        end

        function mappings = find_all_mappings(obj, otherLattice, ltol, ...
                atol, skipRotationMatrix)
            arguments
                obj
                otherLattice (1, 1) kssolv.analysis.matgenlab.core.Lattice
                ltol (1, 1) double {mustBeNonnegative} = 1e-5
                atol (1, 1) double {mustBeNonnegative} = 1
                skipRotationMatrix (1, 1) logical = false
            end
            targetLengths = otherLattice.lengths;
            targetAngles = otherLattice.angles;
            [fractional, distances] = obj.get_points_in_sphere( ...
                [0, 0, 0], [0, 0, 0], max(targetLengths) * (1 + ltol));
            cartesian = obj.get_cartesian_coords(fractional);
            candidates = cell(1, 3);
            candidateFractions = cell(1, 3);
            candidateLengths = cell(1, 3);
            for dim = 1:3
                ratio = distances / targetLengths(dim);
                keep = ratio < 1 + ltol & ratio > 1 / (1 + ltol);
                candidates{dim} = cartesian(keep, :);
                candidateFractions{dim} = fractional(keep, :);
                candidateLengths{dim} = distances(keep);
            end

            mappings = cell(0, 3);
            for idxA = 1:size(candidates{1}, 1)
                for idxB = 1:size(candidates{2}, 1)
                    gammaValue = kssolv.analysis.matgenlab.core.Lattice. ...
                        vectorAngle(candidates{1}(idxA, :), ...
                        candidates{2}(idxB, :), ...
                        candidateLengths{1}(idxA), ...
                        candidateLengths{2}(idxB));
                    if abs(gammaValue - targetAngles(3)) > atol
                        continue
                    end
                    for idxC = 1:size(candidates{3}, 1)
                        alphaValue = kssolv.analysis.matgenlab.core.Lattice. ...
                            vectorAngle(candidates{2}(idxB, :), ...
                            candidates{3}(idxC, :), ...
                            candidateLengths{2}(idxB), ...
                            candidateLengths{3}(idxC));
                        betaValue = kssolv.analysis.matgenlab.core.Lattice. ...
                            vectorAngle(candidates{1}(idxA, :), ...
                            candidates{3}(idxC, :), ...
                            candidateLengths{1}(idxA), ...
                            candidateLengths{3}(idxC));
                        if abs(alphaValue - targetAngles(1)) > atol || ...
                                abs(betaValue - targetAngles(2)) > atol
                            continue
                        end
                        scaleMatrix = round([ ...
                            candidateFractions{1}(idxA, :); ...
                            candidateFractions{2}(idxB, :); ...
                            candidateFractions{3}(idxC, :)]);
                        if abs(det(scaleMatrix)) < 1e-8
                            continue
                        end
                        alignedMatrix = [candidates{1}(idxA, :); ...
                            candidates{2}(idxB, :); ...
                            candidates{3}(idxC, :)];
                        aligned = kssolv.analysis.matgenlab.core.Lattice( ...
                            alignedMatrix, obj.pbc);
                        if skipRotationMatrix
                            rotation = [];
                        else
                            rotation = alignedMatrix \ otherLattice.matrix;
                        end
                        mappings(end + 1, :) = ...
                            {aligned, rotation, scaleMatrix}; %#ok<AGROW>
                    end
                end
            end
        end

        function mappings = findAllMappings(obj, varargin)
            mappings = obj.find_all_mappings(varargin{:});
        end

        function [aligned, rotation, scaleMatrix] = find_mapping( ...
                obj, otherLattice, ltol, atol, skipRotationMatrix)
            if nargin < 3, ltol = 1e-5; end
            if nargin < 4, atol = 1; end
            if nargin < 5, skipRotationMatrix = false; end
            mappings = obj.find_all_mappings(otherLattice, ltol, atol, ...
                skipRotationMatrix);
            if isempty(mappings)
                aligned = [];
                rotation = [];
                scaleMatrix = [];
            else
                aligned = mappings{1, 1};
                rotation = mappings{1, 2};
                scaleMatrix = mappings{1, 3};
            end
        end

        function varargout = findMapping(obj, varargin)
            [varargout{1:nargout}] = obj.find_mapping(varargin{:});
        end

        function reduced = get_niggli_reduced_lattice(obj, tol)
            if nargin < 2, tol = 1e-5; end
            if tol <= 0
                error("KSSOLV:Matgenlab:Lattice:InvalidNiggliTolerance", ...
                    "Niggli tolerance must be positive.");
            end
            metric = obj.lll_matrix * obj.lll_matrix.';
            epsilon = tol * obj.volume^(1 / 3);
            converged = false;
            for iteration = 1:100
                [A, B, C, E, N, Y] = ...
                    kssolv.analysis.matgenlab.core.Lattice.metricScalars(metric);
                if B + epsilon < A || ...
                        (abs(A - B) < epsilon && abs(E) > abs(N) + epsilon)
                    transform = [0,-1,0;-1,0,0;0,0,-1];
                    metric = transform.' * metric * transform;
                    [~, B, C, E, N, Y] = ...
                        kssolv.analysis.matgenlab.core.Lattice. ...
                        metricScalars(metric);
                end
                if C + epsilon < B || ...
                        (abs(B - C) < epsilon && abs(N) > abs(Y) + epsilon)
                    transform = [-1,0,0;0,0,-1;0,-1,0];
                    metric = transform.' * metric * transform;
                    continue
                end

                signE = kssolv.analysis.matgenlab.core.Lattice. ...
                    signWithTolerance(E, epsilon);
                signN = kssolv.analysis.matgenlab.core.Lattice. ...
                    signWithTolerance(N, epsilon);
                signY = kssolv.analysis.matgenlab.core.Lattice. ...
                    signWithTolerance(Y, epsilon);
                signProduct = signE * signN * signY;
                if signProduct == 1
                    signs = [1, 1, 1];
                    if signE == -1, signs(1) = -1; end
                    if signN == -1, signs(2) = -1; end
                    if signY == -1, signs(3) = -1; end
                    metric = diag(signs) * metric * diag(signs);
                elseif signProduct == 0 || signProduct == -1
                    signs = [1, 1, 1];
                    if signE == 1, signs(1) = -1; end
                    if signN == 1, signs(2) = -1; end
                    if signY == 1, signs(3) = -1; end
                    if prod(signs) == -1
                        if signY == 0
                            signs(3) = -1;
                        elseif signN == 0
                            signs(2) = -1;
                        elseif signE == 0
                            signs(1) = -1;
                        end
                    end
                    metric = diag(signs) * metric * diag(signs);
                end

                [A, B, ~, E, N, Y] = ...
                    kssolv.analysis.matgenlab.core.Lattice.metricScalars(metric);
                if abs(E) > B + epsilon || ...
                        (abs(E - B) < epsilon && Y - epsilon > 2*N) || ...
                        (abs(E + B) < epsilon && -epsilon > Y)
                    transform = [1,0,0;0,1,-sign(E);0,0,1];
                    metric = transform.' * metric * transform;
                    continue
                end
                if abs(N) > A + epsilon || ...
                        (abs(A - N) < epsilon && Y - epsilon > 2*E) || ...
                        (abs(A + N) < epsilon && -epsilon > Y)
                    transform = [1,0,-sign(N);0,1,0;0,0,1];
                    metric = transform.' * metric * transform;
                    continue
                end
                if abs(Y) > A + epsilon || ...
                        (abs(A - Y) < epsilon && N - epsilon > 2*E) || ...
                        (abs(A + Y) < epsilon && -epsilon > N)
                    transform = [1,-sign(Y),0;0,1,0;0,0,1];
                    metric = transform.' * metric * transform;
                    continue
                end
                if -epsilon > E + N + Y + A + B || ...
                        (abs(E + N + Y + A + B) < epsilon && ...
                        epsilon < Y + 2*(A + N))
                    transform = [1,0,1;0,1,1;0,0,1];
                    metric = transform.' * metric * transform;
                    continue
                end
                converged = true;
                break
            end
            if ~converged
                error("KSSOLV:Matgenlab:Lattice:NiggliNotConverged", ...
                    "Niggli reduction did not converge within 100 iterations.");
            end
            [A, B, C, E, N, Y] = ...
                kssolv.analysis.matgenlab.core.Lattice.metricScalars(metric);
            aValue = sqrt(A);
            bValue = sqrt(B);
            cValue = sqrt(C);
            alphaValue = acosd(max(-1, min(1, E/(2*bValue*cValue))));
            betaValue = acosd(max(-1, min(1, N/(2*aValue*cValue))));
            gammaValue = acosd(max(-1, min(1, Y/(2*aValue*bValue))));
            canonical = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(aValue, bValue, cValue, alphaValue, ...
                betaValue, gammaValue, pbc = obj.pbc);
            [aligned, ~, ~] = obj.find_mapping(canonical, epsilon, 1, true);
            if isempty(aligned)
                error("KSSOLV:Matgenlab:Lattice:NiggliMappingFailed", ...
                    "Could not map the Niggli cell onto the original lattice.");
            end
            if det(aligned.matrix) < 0
                aligned = kssolv.analysis.matgenlab.core.Lattice( ...
                    -aligned.matrix, obj.pbc);
            end
            reduced = aligned;
        end

        function reduced = getNiggliReducedLattice(obj, tol)
            if nargin < 2, tol = 1e-5; end
            reduced = obj.get_niggli_reduced_lattice(tol);
        end

        function facets = get_wigner_seitz_cell(obj)
            latticePoints = zeros(27, 3);
            index = 0;
            centerIndex = 0;
            for i = -1:1
                for j = -1:1
                    for k = -1:1
                        index = index + 1;
                        latticePoints(index, :) = [i,j,k] * obj.matrix;
                        if i == 0 && j == 0 && k == 0
                            centerIndex = index;
                        end
                    end
                end
            end
            [vertices, cells] = voronoin(latticePoints);
            vertexIndices = cells{centerIndex};
            if any(vertexIndices == 1) || ...
                    any(~isfinite(vertices(vertexIndices, :)), "all")
                error("KSSOLV:Matgenlab:Lattice:UnboundedWignerSeitzCell", ...
                    "Unexpected unbounded central Voronoi region.");
            end
            polyVertices = vertices(vertexIndices, :);
            triangles = convhulln(polyVertices);
            planeGroups = zeros(size(triangles, 1), 1);
            normals = zeros(size(triangles, 1), 3);
            representativeNormals = zeros(size(triangles, 1), 3);
            representativeOffsets = zeros(size(triangles, 1), 1);
            groupCount = 0;
            coordinateScale = max(1, max(vecnorm(polyVertices, 2, 2)));
            % Numeric clustering avoids splitting a plane when nearly
            % identical coefficients straddle a decimal-rounding boundary.
            normalTolerance = 1e-8;
            offsetTolerance = 1e-8 * coordinateScale;
            for idx = 1:size(triangles, 1)
                triangle = polyVertices(triangles(idx, :), :);
                normalVector = cross(triangle(2,:) - triangle(1,:), ...
                    triangle(3,:) - triangle(1,:));
                normalVector = normalVector / norm(normalVector);
                offset = dot(normalVector, triangle(1,:));
                if offset < 0
                    normalVector = -normalVector;
                    offset = -offset;
                end
                normals(idx,:) = normalVector;
                matchingGroup = find( ...
                    max(abs(representativeNormals(1:groupCount, :) - ...
                    normalVector), [], 2) ...
                    <= normalTolerance & ...
                    abs(representativeOffsets(1:groupCount) - offset) ...
                    <= offsetTolerance, 1);
                if isempty(matchingGroup)
                    groupCount = groupCount + 1;
                    matchingGroup = groupCount;
                    representativeNormals(matchingGroup, :) = normalVector;
                    representativeOffsets(matchingGroup, 1) = offset;
                end
                planeGroups(idx) = matchingGroup;
            end
            facets = cell(groupCount, 1);
            for idx = 1:numel(facets)
                triangleRows = find(planeGroups == idx);
                vertexIds = unique(triangles(triangleRows, :), "stable");
                face = polyVertices(vertexIds, :);
                faceCenter = mean(face, 1);
                normalVector = normals(triangleRows(1), :);
                reference = face(1, :) - faceCenter;
                reference = reference / norm(reference);
                perpendicular = cross(normalVector, reference);
                polarAngles = atan2((face-faceCenter) * perpendicular.', ...
                    (face-faceCenter) * reference.');
                [~, order] = sort(polarAngles);
                facets{idx} = face(order, :);
            end
        end

        function facets = getWignerSeitzCell(obj)
            facets = obj.get_wigner_seitz_cell();
        end

        function facets = get_brillouin_zone(obj)
            facets = obj.reciprocal_lattice.get_wigner_seitz_cell();
        end

        function facets = getBrillouinZone(obj)
            facets = obj.get_brillouin_zone();
        end

        function operations = get_recp_symmetry_operation(obj, symprec)
            if nargin < 2, symprec = 0.01; end
            reciprocal = obj.reciprocal_lattice_crystallographic.scale(1);
            data = kssolv.analysis.spglib.Spglib.getDataset( ...
                reciprocal.matrix, [0,0,0], 1, uint16(1), symprec);
            count = double(data.n_operations);
            operations = cell(count, 1);
            for idx = 1:count
                rotation = squeeze(data.rotations(idx, :, :));
                translation = data.translations(idx, :);
                operations{idx} = kssolv.analysis.matgenlab.core.SymmOp. ...
                    from_rotation_and_translation(rotation, translation);
            end
        end

        function operations = getRecpSymmetryOperation(obj, symprec)
            if nargin < 2, symprec = 0.01; end
            operations = obj.get_recp_symmetry_operation(symprec);
        end

        function miller = get_miller_index_from_coords(obj, coords, ...
                coordsAreCartesian, roundDp, verbose)
            if nargin < 3, coordsAreCartesian = true; end
            if nargin < 4, roundDp = 4; end
            if nargin < 5, verbose = true; end
            coords = obj.validateCoords(coords, "coords");
            if size(coords, 1) < 3
                error("KSSOLV:Matgenlab:Lattice:InsufficientPlanePoints", ...
                    "At least three coordinates are required.");
            end
            if coordsAreCartesian
                coords = obj.get_fractional_coords(coords);
            end
            centered = coords - mean(coords, 1);
            [~, ~, rightVectors] = svd(centered, 0);
            normal = rightVectors(:, end).';
            miller = kssolv.analysis.matgenlab.core.Lattice. ...
                getIntegerIndex(normal, roundDp, verbose);
        end

        function miller = getMillerIndexFromCoords(obj, varargin)
            miller = obj.get_miller_index_from_coords(varargin{:});
        end

        function distance = selling_dist(obj, other)
            arguments
                obj
                other (1, 1) kssolv.analysis.matgenlab.core.Lattice
            end
            % Exhaust the 24 permutations of the four Selling superbase
            % vectors. This is equivalent to the reflection/VCP enumeration
            % used upstream and is less error-prone to maintain.
            first = obj.selling_vector;
            second = other.selling_vector;
            permutations = perms(1:4);
            candidates = zeros(size(permutations, 1), 6);
            vectors = obj.matrix;
            superbase = [vectors; -sum(vectors, 1)];
            for idx = 1:size(permutations, 1)
                permuted = superbase(permutations(idx, :), :);
                candidates(idx, :) = [ ...
                    dot(permuted(2, :), permuted(3, :)), ...
                    dot(permuted(1, :), permuted(3, :)), ...
                    dot(permuted(1, :), permuted(2, :)), ...
                    dot(permuted(1, :), permuted(4, :)), ...
                    dot(permuted(2, :), permuted(4, :)), ...
                    dot(permuted(3, :), permuted(4, :))];
            end
            distance = min(vecnorm(candidates - second, 2, 2));
            if norm(first - second) < distance
                distance = norm(first - second);
            end
        end

        function distance = sellingDist(obj, other)
            distance = obj.selling_dist(other);
        end

        function text = string(obj)
            rows = strings(3, 1);
            for idx = 1:3
                rows(idx) = sprintf("%.6f %.6f %.6f", obj.matrix(idx, :));
            end
            text = strjoin(rows, newline);
        end

        function disp(obj)
            fprintf("%s\n", obj.string());
        end
    end

    methods (Static)
        function obj = cubic(a, options)
            arguments
                a (1, 1) double {mustBePositive}
                options.pbc (1, 3) logical = [true, true, true]
            end
            obj = kssolv.analysis.matgenlab.core.Lattice( ...
                diag([a, a, a]), options.pbc);
        end

        function obj = tetragonal(a, c, options)
            arguments
                a (1, 1) double {mustBePositive}
                c (1, 1) double {mustBePositive}
                options.pbc (1, 3) logical = [true, true, true]
            end
            obj = kssolv.analysis.matgenlab.core.Lattice( ...
                diag([a, a, c]), options.pbc);
        end

        function obj = orthorhombic(a, b, c, options)
            arguments
                a (1, 1) double {mustBePositive}
                b (1, 1) double {mustBePositive}
                c (1, 1) double {mustBePositive}
                options.pbc (1, 3) logical = [true, true, true]
            end
            obj = kssolv.analysis.matgenlab.core.Lattice( ...
                diag([a, b, c]), options.pbc);
        end

        function obj = monoclinic(a, b, c, beta, options)
            arguments
                a (1, 1) double {mustBePositive}
                b (1, 1) double {mustBePositive}
                c (1, 1) double {mustBePositive}
                beta (1, 1) double
                options.pbc (1, 3) logical = [true, true, true]
            end
            obj = kssolv.analysis.matgenlab.core.Lattice.from_parameters( ...
                a, b, c, 90, beta, 90, pbc = options.pbc);
        end

        function obj = hexagonal(a, c, options)
            arguments
                a (1, 1) double {mustBePositive}
                c (1, 1) double {mustBePositive}
                options.pbc (1, 3) logical = [true, true, true]
            end
            obj = kssolv.analysis.matgenlab.core.Lattice.from_parameters( ...
                a, a, c, 90, 90, 120, pbc = options.pbc);
        end

        function obj = rhombohedral(a, alpha, options)
            arguments
                a (1, 1) double {mustBePositive}
                alpha (1, 1) double
                options.pbc (1, 3) logical = [true, true, true]
            end
            obj = kssolv.analysis.matgenlab.core.Lattice.from_parameters( ...
                a, a, a, alpha, alpha, alpha, pbc = options.pbc);
        end

        function obj = from_parameters(a, b, c, alpha, beta, gamma, ...
                options)
            arguments
                a (1, 1) double {mustBePositive}
                b (1, 1) double {mustBePositive}
                c (1, 1) double {mustBePositive}
                alpha (1, 1) double
                beta (1, 1) double
                gamma (1, 1) double
                options.vesta (1, 1) logical = false
                options.pbc (1, 3) logical = [true, true, true]
            end
            if any([alpha, beta, gamma] <= 0) || ...
                    any([alpha, beta, gamma] >= 180)
                error("KSSOLV:Matgenlab:Lattice:InvalidAngles", ...
                    "Lattice angles must lie strictly between 0 and 180 degrees.");
            end
            cosAlpha = cosd(alpha);
            cosBeta = cosd(beta);
            cosGamma = cosd(gamma);
            sinAlpha = sind(alpha);
            sinBeta = sind(beta);
            sinGamma = sind(gamma);
            if options.vesta
                c1 = c * cosBeta;
                c2 = c * (cosAlpha - cosBeta * cosGamma) / sinGamma;
                radicand = c^2 - c1^2 - c2^2;
                if radicand < -1e-10
                    error("KSSOLV:Matgenlab:Lattice:InvalidParameters", ...
                        "Lattice parameters do not define a real cell.");
                end
                matrix = [a, 0, 0; b * cosGamma, b * sinGamma, 0; ...
                    c1, c2, sqrt(max(0, radicand))];
            else
                value = (cosAlpha * cosBeta - cosGamma) / ...
                    (sinAlpha * sinBeta);
                gammaStar = acos(max(-1, min(1, value)));
                matrix = [a * sinBeta, 0, a * cosBeta; ...
                    -b * sinAlpha * cos(gammaStar), ...
                    b * sinAlpha * sin(gammaStar), b * cosAlpha; ...
                    0, 0, c];
            end
            obj = kssolv.analysis.matgenlab.core.Lattice(matrix, options.pbc);
        end

        function obj = fromParameters(varargin)
            obj = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(varargin{:});
        end

        function obj = from_dict(data)
            arguments
                data (1, 1) struct
            end
            if isfield(data, "pbc")
                pbc = logical(data.pbc);
            else
                pbc = [true, true, true];
            end
            if isfield(data, "matrix")
                obj = kssolv.analysis.matgenlab.core.Lattice(data.matrix, pbc);
            else
                obj = kssolv.analysis.matgenlab.core.Lattice.from_parameters( ...
                    data.a, data.b, data.c, data.alpha, data.beta, ...
                    data.gamma, pbc = pbc);
            end
        end

        function obj = fromDict(data)
            obj = kssolv.analysis.matgenlab.core.Lattice.from_dict(data);
        end
    end

    methods (Access = private)
        function coords = validateCoords(~, coords, name)
            if isempty(coords)
                coords = zeros(0, 3);
                return
            end
            if ~isreal(coords)
                error("KSSOLV:Matgenlab:Lattice:ComplexCoordinates", ...
                    "%s must be real.", name);
            end
            if isvector(coords) && numel(coords) == 3
                coords = reshape(coords, 1, 3);
            elseif ~ismatrix(coords) || size(coords, 2) ~= 3
                error("KSSOLV:Matgenlab:Lattice:InvalidCoordinates", ...
                    "%s must be a three-element vector or N-by-3 array.", name);
            end
            if any(~isfinite(coords), "all")
                error("KSSOLV:Matgenlab:Lattice:NonFiniteCoordinates", ...
                    "%s must contain finite values.", name);
            end
            coords = double(coords);
        end

        function [distance, bestImage] = shortestImage(obj, delta)
            % Use a rigorous reciprocal-space bound around an already known
            % candidate. Any better vector must have bounded fractional
            % projections, including for highly skewed cells.
            initialImage = zeros(1, 3);
            initialImage(obj.pbc) = -round(delta(obj.pbc));
            initialDistance = norm((delta + initialImage) * obj.matrix);
            reciprocalLengths = obj.reciprocal_lattice.lengths;
            fractionalBounds = initialDistance * reciprocalLengths / (2 * pi) ...
                + 1e-12;
            ranges = cell(1, 3);
            for dim = 1:3
                if obj.pbc(dim)
                    ranges{dim} = floor(-delta(dim) - fractionalBounds(dim)): ...
                        ceil(-delta(dim) + fractionalBounds(dim));
                else
                    ranges{dim} = 0;
                end
            end
            [i1, i2, i3] = ndgrid(ranges{1}, ranges{2}, ranges{3});
            candidates = [i1(:), i2(:), i3(:)];
            cartesian = (delta + candidates) * obj.matrix;
            normsSquared = sum(cartesian.^2, 2);
            [minimum, index] = min(normsSquared);
            distance = sqrt(minimum);
            bestImage = candidates(index, :);
        end

        function [reduced, mappingOut] = calculateLll(obj, delta)
            basis = obj.matrix.';
            orthogonal = zeros(3);
            coefficients = zeros(3);
            normsSquared = zeros(1, 3);
            orthogonal(:, 1) = basis(:, 1);
            normsSquared(1) = dot(orthogonal(:, 1), orthogonal(:, 1));
            for idx = 2:3
                coefficients(idx, 1:idx-1) = ...
                    (basis(:, idx).' * orthogonal(:, 1:idx-1)) ./ ...
                    normsSquared(1:idx-1);
                orthogonal(:, idx) = basis(:, idx) - ...
                    orthogonal(:, 1:idx-1) * ...
                    coefficients(idx, 1:idx-1).';
                normsSquared(idx) = dot(orthogonal(:, idx), ...
                    orthogonal(:, idx));
            end
            if any(normsSquared <= eps)
                error("KSSOLV:Matgenlab:Lattice:LllDegenerateBasis", ...
                    "Cannot LLL-reduce a degenerate lattice basis.");
            end

            columnMapping = eye(3);
            k = 2;
            iteration = 0;
            while k <= 3
                iteration = iteration + 1;
                if iteration > 10000
                    error("KSSOLV:Matgenlab:Lattice:LllFailed", ...
                        "LLL reduction failed to converge.");
                end
                for idx = k-1:-1:1
                    quotient = round(coefficients(k, idx));
                    if quotient ~= 0
                        basis(:, k) = basis(:, k) - ...
                            quotient * basis(:, idx);
                        columnMapping(:, k) = columnMapping(:, k) - ...
                            quotient * columnMapping(:, idx);
                        update = [coefficients(idx, 1:idx-1), 1];
                        coefficients(k, 1:idx) = ...
                            coefficients(k, 1:idx) - quotient * update;
                    end
                end
                if dot(orthogonal(:, k), orthogonal(:, k)) >= ...
                        (delta - abs(coefficients(k, k-1))^2) * ...
                        dot(orthogonal(:, k-1), orthogonal(:, k-1))
                    k = k + 1;
                else
                    basis(:, [k-1, k]) = basis(:, [k, k-1]);
                    columnMapping(:, [k-1, k]) = ...
                        columnMapping(:, [k, k-1]);
                    for idx = k-1:k
                        if idx == 1
                            orthogonal(:, idx) = basis(:, idx);
                        else
                            coefficients(idx, 1:idx-1) = ...
                                (basis(:, idx).' * ...
                                orthogonal(:, 1:idx-1)) ./ ...
                                normsSquared(1:idx-1);
                            orthogonal(:, idx) = basis(:, idx) - ...
                                orthogonal(:, 1:idx-1) * ...
                                coefficients(idx, 1:idx-1).';
                        end
                        normsSquared(idx) = dot(orthogonal(:, idx), ...
                            orthogonal(:, idx));
                    end
                    if k > 2
                        k = k - 1;
                    else
                        p = basis(:, k+1:3).' * orthogonal(:, k-1:k);
                        q = diag(normsSquared(k-1:k));
                        coefficients(k+1:3, k-1:k) = p / q;
                    end
                end
            end
            reduced = basis.';
            mappingOut = columnMapping.';
        end
    end

    methods (Static, Access = private)
        function angle = vectorAngle(first, second, firstLength, secondLength)
            cosine = dot(first, second) / (firstLength * secondLength);
            angle = acosd(max(-1, min(1, cosine)));
        end

        function [A, B, C, E, N, Y] = metricScalars(metric)
            A = metric(1,1);
            B = metric(2,2);
            C = metric(3,3);
            E = 2 * metric(2,3);
            N = 2 * metric(1,3);
            Y = 2 * metric(1,2);
        end

        function value = signWithTolerance(value, tolerance)
            if abs(value) < tolerance
                value = 0;
            else
                value = sign(value);
            end
        end

        function miller = getIntegerIndex(index, roundDp, verbose)
            index = double(index);
            nonzero = index(abs(index) > eps);
            if isempty(nonzero)
                miller = [0, 0, 0];
                return
            end
            index = index / min(nonzero);
            index = index / max(abs(index));
            denominators = ones(size(index));
            for idx = 1:numel(index)
                bestError = Inf;
                for denominator = 1:12
                    numerator = round(index(idx) * denominator);
                    errorValue = abs(index(idx) - numerator / denominator);
                    if errorValue < bestError
                        bestError = errorValue;
                        denominators(idx) = denominator;
                    end
                end
            end
            multiplier = prod(denominators);
            scaled = index * multiplier;
            rounded = round(scaled, 1);
            integerApprox = round(rounded);
            divisor = 0;
            for value = abs(integerApprox)
                divisor = gcd(divisor, value);
            end
            if divisor > 0
                scaled = scaled / divisor;
            end
            scaled = round(scaled, roundDp);
            integerApprox = round(scaled);
            if any(abs(scaled - integerApprox) > 1e-6)
                if verbose
                    warning("KSSOLV:Matgenlab:Lattice:NonIntegerMillerIndex", ...
                        "Non-integer encountered in Miller index.");
                end
                miller = scaled;
            else
                miller = integerApprox;
            end
            miller(miller == 0) = 0;
            if sum(miller < 0) > sum(-miller < 0)
                miller = -miller;
            end
            if nnz(miller) == 2 && nnz(miller < 0) == 1 && ...
                    abs(min(miller)) > max(miller)
                miller = -miller;
            end
        end

        function matrices = sellingReductionMatrices()
            matrices = zeros(6, 6, 6);
            matrices(:, :, 1) = [ ...
                -1,0,0,0,0,0; 1,1,0,0,0,0; 1,0,0,0,1,0; ...
                -1,0,0,1,0,0; 1,0,1,0,0,0; 1,0,0,0,0,1];
            matrices(:, :, 2) = [ ...
                1,1,0,0,0,0; 0,-1,0,0,0,0; 0,1,0,1,0,0; ...
                0,1,1,0,0,0; 0,-1,0,0,1,0; 0,1,0,0,0,1];
            matrices(:, :, 3) = [ ...
                1,0,1,0,0,0; 0,0,1,1,0,0; 0,0,-1,0,0,0; ...
                0,1,1,0,0,0; 0,0,1,0,1,0; 0,0,-1,0,0,1];
            matrices(:, :, 4) = [ ...
                1,0,0,-1,0,0; 0,0,1,1,0,0; 0,1,0,1,0,0; ...
                0,0,0,-1,0,0; 0,0,0,1,1,0; 0,0,0,1,0,1];
            matrices(:, :, 5) = [ ...
                0,0,1,0,1,0; 0,1,0,0,-1,0; 1,0,0,0,1,0; ...
                0,0,0,1,1,0; 0,0,0,0,-1,0; 0,0,0,0,1,1];
            matrices(:, :, 6) = [ ...
                0,1,0,0,0,1; 1,0,0,0,0,1; 0,0,1,0,0,-1; ...
                0,0,0,1,0,1; 0,0,0,0,1,1; 0,0,0,0,0,-1];
        end
    end
end
