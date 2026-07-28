classdef BztInterpolator < handle
    %BZTINTERPOLATOR Periodic Fourier interpolation of electronic bands.
    %
    % This implementation is self-contained.  It fits a symmetry-agnostic
    % periodic Fourier basis to each input band and evaluates energy, velocity,
    % and curvature analytically on a uniform reciprocal-space mesh.

    properties
        data
        lpfac (1,1) double = 10
        energy_range (1,1) double = 1.5
        curvature (1,1) logical = true
        efermi (1,1) double = 0
        accepted logical = false(0, 1)
        equivalences cell = cell(1, 0)
        coeffs double = zeros(0)
        eband double = zeros(0)
        vvband double = zeros(0)
        cband double = zeros(0)
        grid_kpoints double = zeros(0, 3)
    end

    methods
        function obj = BztInterpolator(data, varargin)
            obj.data = data;
            options = parseOptions(varargin{:});
            obj.lpfac = options.lpfac;
            obj.energy_range = options.energy_range;
            obj.curvature = options.curvature;
            obj.efermi = data.fermi;
            middle = (data.cbm + data.vbm) / 2;
            obj.accepted = data.bandana( ...
                (middle - obj.energy_range) * hartreePerEv(), ...
                (middle + obj.energy_range) * hartreePerEv());
            loadedBands = false;
            if options.load_bztInterp
                loadedBands = obj.load(options.fname);
            else
                obj.fitFourier();
            end
            if ~loadedBands
                obj.evaluateUniformGrid();
            end
            if options.save_bztInterp
                obj.save(options.fname, options.save_bands);
            end
        end

        function bandsLoaded = load(obj, filename)
            if nargin < 2, filename = "bztInterp.json.gz"; end
            value = readJson(filename);
            if ~iscell(value), value = num2cell(value); end
            if numel(value) < 2
                error("KSSOLV:Matgenlab:Boltztrap2:BadInterpolation", ...
                    "Interpolation file requires equivalences and coefficients.");
            end
            obj.equivalences = equivalenceCells(value{1});
            complexParts = value{2};
            if isstruct(complexParts) && numel(complexParts) >= 2
                realPart = numpySequence(complexParts(1), false);
                imagPart = numpySequence(complexParts(2), false);
            elseif iscell(complexParts)
                realPart = numpySequence(complexParts{1}, false);
                imagPart = numpySequence(complexParts{2}, false);
            else
                realPart = toNumeric(complexParts(1));
                imagPart = toNumeric(complexParts(2));
            end
            obj.coeffs = realPart + 1i * imagPart;
            bandsLoaded = numel(value) >= 5;
            if bandsLoaded
                obj.eband = toNumeric(value{3});
                obj.vvband = toNumeric(value{4});
                obj.cband = toNumeric(value{5});
            end
        end

        function save(obj, filename, bands)
            if nargin < 2, filename = "bztInterp.json.gz"; end
            if nargin < 3, bands = false; end
            value = {obj.equivalences, {real(obj.coeffs), ...
                imag(obj.coeffs)}};
            if bands
                value = [value, {obj.eband, obj.vvband, obj.cband}];
            end
            writeJson(filename, value);
        end

        function result = get_band_structure(obj, kpaths, labels, density)
            if nargin < 4 || isempty(density), density = 20; end
            if nargin < 2 || isempty(kpaths)
                path = kssolv.analysis.matgenlab.symmetry.HighSymmKpath( ...
                    obj.data.structure);
                [kpoints, pointLabels] = path.get_kpoints(density, false);
                labels = containers.Map("KeyType", "char", "ValueType", "any");
                for index = 1:numel(pointLabels)
                    if strlength(pointLabels(index)) > 0
                        labels(char(pointLabels(index))) = kpoints(index, :);
                    end
                end
            else
                kpoints = zeros(0, 3);
                for pathIndex = 1:numel(kpaths)
                    branch = kpaths{pathIndex};
                    for index = 1:numel(branch)-1
                        first = mapValue(labels, branch{index});
                        last = mapValue(labels, branch{index + 1});
                        kpoints = [kpoints; linspaceRows(first, last, density)]; %#ok<AGROW>
                    end
                end
            end
            energies = obj.evaluate(kpoints);
            if obj.data.is_spin_polarized
                half = sum(obj.accepted(1:numel(obj.accepted)/2));
                bands = struct("up", energies(1:half, :) / hartreePerEv(), ...
                    "down", energies(half+1:end, :) / hartreePerEv());
            else
                bands = struct("up", energies / hartreePerEv());
            end
            result = kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructureSymmLine(kpoints, bands, ...
                obj.data.structure.lattice.reciprocal_lattice, ...
                obj.efermi / hartreePerEv(), labels, false, obj.data.structure);
        end

        function dos = get_dos(obj, varargin)
            options = parseDosOptions(varargin{:});
            minimum = min(obj.eband, [], "all");
            maximum = max(obj.eband, [], "all");
            edges = linspace(minimum, maximum, options.npts_mu + 1);
            energies = (edges(1:end-1) + edges(2:end)) / 2;
            factor = size(obj.eband, 2) * mean(diff(edges));
            if obj.data.is_spin_polarized
                half = sum(obj.accepted(1:numel(obj.accepted)/2));
                up = histcounts(obj.eband(1:half, :), edges) / factor;
                down = histcounts(obj.eband(half+1:end, :), edges) / factor;
                densities = struct("up", up, "down", down);
            else
                densities = struct("up", ...
                    obj.data.dosweight * histcounts(obj.eband, edges) / factor);
            end
            if ~isempty(options.T) && options.T > 0
                sigma = 8.617333262145e-5 * options.T;
                names = fieldnames(densities);
                for index = 1:numel(names)
                    densities.(names{index}) = gaussianSmooth( ...
                        densities.(names{index}), sigma / mean(diff(energies)));
                end
            end
            dos = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                obj.efermi / hartreePerEv(), ...
                energies / hartreePerEv(), densities);
            if options.partial_dos
                dos = obj.get_partial_doses(dos, options);
            end
        end

        function result = get_partial_doses(obj, totalDos, varargin)
            if nargin == 3 && isstruct(varargin{1})
                options = varargin{1};
            else
                options = parseDosOptions(varargin{:});
            end
            if isempty(fieldnames(obj.data.proj))
                error("KSSOLV:Matgenlab:Boltztrap2:MissingProjections", ...
                    "No projections were loaded.");
            end
            energies = totalDos.energies;
            edges = centersToEdges(energies);
            pdos = cell(1, obj.data.structure.num_sites);
            spinNames = fieldnames(obj.data.proj);
            for siteIndex = 1:numel(pdos)
                orbitalMap = struct();
                for orbitalIndex = 1:9
                    spinMap = struct();
                    for spinIndex = 1:numel(spinNames)
                        name = spinNames{spinIndex};
                        source = squeeze(obj.data.proj.(name)(:, :, ...
                            siteIndex, orbitalIndex)).';
                        weights = obj.interpolateWeights(source);
                        if obj.data.is_spin_polarized
                            offset = 0;
                            if name == "down"
                                offset = sum(obj.accepted(1:numel(obj.accepted)/2));
                            end
                            bandCount = size(weights, 1);
                            bandEnergy = obj.eband(offset+(1:bandCount), :);
                        else
                            bandEnergy = obj.eband;
                            weights = weights * obj.data.dosweight;
                        end
                        spinMap.(name) = weightedHistogram( ...
                            bandEnergy, weights, edges);
                        if ~isempty(options.T) && options.T > 0
                            width = 8.617333262145e-5 * options.T / ...
                                mean(diff(energies));
                            spinMap.(name) = gaussianSmooth( ...
                                spinMap.(name), width);
                        end
                    end
                    orbitalMap.(orbitalField(orbitalIndex)) = spinMap;
                end
                pdos{siteIndex} = orbitalMap;
            end
            result = kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos(obj.data.structure, totalDos, pdos);
        end
    end

    methods (Access = private)
        function fitFourier(obj)
            target = max(7, round(size(obj.data.kpoints, 1) * obj.lpfac));
            obj.equivalences = reciprocalStars(obj.data.structure, target);
            phase = starBasis(obj.data.kpoints, obj.equivalences, 0, 0);
            lambda = 1e-10 * norm(phase, "fro")^2 / size(phase, 2);
            obj.coeffs = (phase' * phase + lambda * ...
                eye(size(phase, 2))) \ (phase' * obj.data.ebands.');
            obj.coeffs = obj.coeffs.';
        end

        function evaluateUniformGrid(obj)
            vectors = vertcat(obj.equivalences{:});
            extents = max(abs(vectors), [], 1);
            dimensions = max(2 * extents + 1, 3);
            xValues = (0:dimensions(1)-1) / dimensions(1);
            yValues = (0:dimensions(2)-1) / dimensions(2);
            zValues = (0:dimensions(3)-1) / dimensions(3);
            [x, y, z] = ndgrid(xValues, yValues, zValues);
            obj.grid_kpoints = [x(:), y(:), z(:)];
            [obj.eband, velocity, curvatureValues] = ...
                obj.evaluate(obj.grid_kpoints);
            obj.vvband = zeros(size(obj.eband, 1), 3, 3, ...
                size(obj.eband, 2));
            for first = 1:3
                for second = 1:3
                    obj.vvband(:, first, second, :) = ...
                        reshape(squeeze(velocity(:, first, :)) .* ...
                        squeeze(velocity(:, second, :)), ...
                        size(obj.eband, 1), 1, 1, size(obj.eband, 2));
                end
            end
            if obj.curvature
                obj.cband = zeros(size(obj.eband, 1), 3, 3, 3, ...
                    size(obj.eband, 2));
                for first = 1:3
                    for second = 1:3
                        for third = 1:3
                            obj.cband(:, first, second, third, :) = ...
                                reshape(squeeze(curvatureValues(:, first, ...
                                second, :)) .* squeeze(velocity(:, third, :)), ...
                                size(obj.eband, 1), 1, 1, 1, ...
                                size(obj.eband, 2));
                        end
                    end
                end
            end
        end

        function [energies, velocity, curvatureValues] = evaluate(obj, points)
            phase = starBasis(points, obj.equivalences, 0, 0);
            energies = real(obj.coeffs * phase.');
            if nargout < 2, return; end
            bands = size(obj.coeffs, 1);
            samples = size(points, 1);
            velocity = zeros(bands, 3, samples);
            curvatureValues = zeros(bands, 3, 3, samples);
            for first = 1:3
                for second = 1:3
                    derivative2 = starBasis(points, obj.equivalences, ...
                        first, second);
                    curvatureValues(:, first, second, :) = ...
                        real(obj.coeffs * derivative2.');
                end
                derivative = starBasis(points, obj.equivalences, first, 0);
                velocity(:, first, :) = real(obj.coeffs * derivative.');
            end
        end

        function values = interpolateWeights(obj, source)
            originalBands = obj.data.ebands;
            obj.data.ebands = source;
            cleanup = onCleanup(@() restoreBands(obj.data, originalBands));
            count = numel(obj.equivalences);
            phase = starBasis(obj.data.kpoints, obj.equivalences, 0, 0);
            lambda = 1e-10 * norm(phase, "fro")^2 / count;
            coeff = (phase' * phase + lambda * eye(count)) \ ...
                (phase' * source.');
            gridBasis = starBasis(obj.grid_kpoints, ...
                obj.equivalences, 0, 0);
            values = max(real(coeff.' * gridBasis.'), 0);
            clear cleanup
        end
    end
end

function options = parseOptions(varargin)
options = struct("lpfac", 10, "energy_range", 1.5, "curvature", true, ...
    "save_bztInterp", false, "load_bztInterp", false, ...
    "save_bands", false, "fname", "bztInterp.json.gz");
if ~isempty(varargin) && isnumeric(varargin{1})
    options.lpfac = varargin{1};
    varargin(1) = [];
end
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function options = parseDosOptions(varargin)
options = struct("partial_dos", false, "npts_mu", 10000, ...
    "T", [], "progress", false);
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function rows = linspaceRows(first, last, count)
t = linspace(0, 1, count).';
rows = first + t .* (last - first);
end

function value = mapValue(map, key)
if isa(map, "containers.Map"), value = map(char(string(key)));
else, value = map.(matlab.lang.makeValidName(char(string(key)))); end
value = reshape(double(value), 1, 3);
end

function output = gaussianSmooth(input, sigma)
if sigma <= 0, output = input; return; end
radius = max(1, ceil(4 * sigma));
x = -radius:radius;
kernel = exp(-0.5 * (x / sigma).^2);
kernel = kernel / sum(kernel);
output = conv(input, kernel, "same");
end

function edges = centersToEdges(centers)
middle = (centers(1:end-1) + centers(2:end)) / 2;
edges = [centers(1) - (middle(1) - centers(1)), middle, ...
    centers(end) + (centers(end) - middle(end))];
end

function output = weightedHistogram(energies, weights, edges)
output = zeros(1, numel(edges) - 1);
spacing = mean(diff(edges));
for band = 1:size(energies, 1)
    bins = discretize(energies(band, :), edges);
    valid = ~isnan(bins);
    output = output + accumarray(bins(valid).', ...
        weights(band, valid).', [numel(output), 1]).';
end
output = output / (size(energies, 2) * spacing);
end

function field = orbitalField(index)
names = ["s","py","pz","px","dxy","dyz","dz2","dxz","dx2"];
field = char(names(index));
end

function restoreBands(data, values)
data.ebands = values;
end

function value = readJson(filename)
filename = char(filename);
if endsWith(filename, ".gz")
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, "s"));
    files = gunzip(filename, folder);
    value = jsondecode(fileread(files{1}));
    clear cleanup
else
    value = jsondecode(fileread(filename));
end
end

function writeJson(filename, value)
text = jsonencode(value);
filename = char(filename);
if endsWith(filename, ".gz")
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@() rmdir(folder, "s"));
    plain = fullfile(folder, "payload.json");
    file = fopen(plain, "w");
    guard = onCleanup(@() fclose(file));
    fwrite(file, text, "char");
    clear guard
    files = gzip(plain, folder);
    movefile(files{1}, filename, "f");
    clear cleanup
else
    file = fopen(filename, "w");
    guard = onCleanup(@() fclose(file));
    fwrite(file, text, "char");
end
end

function value = decodeMonty(value)
if isstruct(value) && ~isscalar(value)
    decoded = arrayfun(@decodeMonty, value, "UniformOutput", false);
    if all(cellfun(@(item) isnumeric(item) && isrow(item), decoded))
        value = vertcat(decoded{:});
    else
        value = decoded;
    end
elseif isstruct(value) && isfield(value, "x_class") && ...
        string(value.x_class) == "array" && isfield(value, "data")
    value = toNumeric(value.data);
elseif isstruct(value)
    names = fieldnames(value);
    for index = 1:numel(names)
        value.(names{index}) = decodeMonty(value.(names{index}));
    end
elseif iscell(value)
    value = cellfun(@decodeMonty, value, "UniformOutput", false);
end
end

function value = toNumeric(value)
if isstruct(value) && isfield(value, "data"), value = value.data; end
if isnumeric(value), value = double(value); return; end
if iscell(value)
    converted = cellfun(@toNumeric, value, "UniformOutput", false);
    try
        value = cat(ndims(converted{1}) + 1, converted{:});
        order = [ndims(value), 1:ndims(value)-1];
        value = permute(value, order);
    catch
        value = converted;
    end
end
end

function value = hartreePerEv()
value = 1 / 27.211386245988;
end

function value = numpySequence(input, stackRows)
if nargin < 2, stackRows = false; end
if isstruct(input) && numel(input) > 1
    values = arrayfun(@(item) numpySequence(item, false), input, ...
        "UniformOutput", false);
    if stackRows
        value = cell2mat(cellfun(@(item) reshape(item(1, :), 1, []), ...
            values, "UniformOutput", false));
    else
        value = values;
    end
elseif isstruct(input) && isfield(input, "data")
    value = double(input.data);
elseif iscell(input)
    values = cellfun(@(item) numpySequence(item, false), input, ...
        "UniformOutput", false);
    if stackRows
        value = cell2mat(cellfun(@(item) reshape(item(1, :), 1, []), ...
            values, "UniformOutput", false));
    else
        value = values;
    end
else
    value = double(input);
end
end

function cells = equivalenceCells(input)
if isstruct(input)
    cells = arrayfun(@(item) double(item.data), input, ...
        "UniformOutput", false);
elseif iscell(input)
    cells = cellfun(@(item) equivalenceValue(item), input, ...
        "UniformOutput", false);
elseif isnumeric(input)
    cells = mat2cell(double(input), ones(1, size(input, 1)), 3);
else
    error("KSSOLV:Matgenlab:Boltztrap2:Equivalences", ...
        "Unsupported equivalence representation.");
end
cells = reshape(cells, 1, []);
end

function value = equivalenceValue(input)
if isstruct(input) && isfield(input, "data")
    value = double(input.data);
else
    value = double(input);
end
end

function stars = reciprocalStars(structure, target)
analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure, 1e-3);
dataset = analyzer.get_symmetry_dataset();
rotations = double(dataset.rotations);
if size(rotations, 1) ~= 3 || size(rotations, 2) ~= 3
    rotations = permute(rotations, [2, 3, 1]);
end
radius = max(2, ceil(target^(1/3)));
stars = cell(1, 0);
while numel(stars) < target
    [x, y, z] = ndgrid(-radius:radius);
    candidates = [x(:), y(:), z(:)];
    cartesian = candidates * structure.lattice.matrix;
    [~, order] = sort(sum(cartesian.^2, 2));
    candidates = candidates(order, :);
    visited = containers.Map("KeyType", "char", "ValueType", "logical");
    stars = cell(1, 0);
    for index = 1:size(candidates, 1)
        candidate = candidates(index, :);
        key = vectorKey(candidate);
        if isKey(visited, key), continue; end
        orbit = zeros(size(rotations, 3), 3);
        for operation = 1:size(rotations, 3)
            orbit(operation, :) = round( ...
                (rotations(:, :, operation) * candidate.').');
        end
        orbit = unique(orbit, "rows");
        for operation = 1:size(orbit, 1)
            visited(vectorKey(orbit(operation, :))) = true;
        end
        stars{end + 1} = orbit; %#ok<AGROW>
        if numel(stars) == target, break; end
    end
    radius = radius + 1;
    if radius > 64
        error("KSSOLV:Matgenlab:Boltztrap2:EquivalenceSearch", ...
            "Could not generate the requested reciprocal stars.");
    end
end
end

function key = vectorKey(vector)
key = sprintf("%d,%d,%d", vector);
end

function basis = starBasis(points, stars, firstDerivative, secondDerivative)
basis = zeros(size(points, 1), numel(stars));
for index = 1:numel(stars)
    vectors = stars{index};
    phase = exp(2i * pi * (points * vectors.'));
    if firstDerivative == 0
        factor = ones(1, size(vectors, 1));
    elseif secondDerivative == 0
        factor = (2i * pi * vectors(:, firstDerivative)).';
    else
        factor = (-(2*pi)^2 * vectors(:, firstDerivative) .* ...
            vectors(:, secondDerivative)).';
    end
    basis(:, index) = mean(phase .* factor, 2);
end
end
