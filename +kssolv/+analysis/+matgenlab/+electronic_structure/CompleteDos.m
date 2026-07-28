classdef CompleteDos < kssolv.analysis.matgenlab.electronic_structure.Dos
    %COMPLETEDOS Total and site/orbital-projected density of states.
    %
    % ``pdos`` is stored as a cell array in structure-site order.  Each
    % cell is a struct whose orbital-name fields (s, py, dxy, ...) contain
    % spin-density structs with fields ``up`` and optional ``down``.

    properties (SetAccess = immutable)
        structure
        pdos cell
    end

    properties (Dependent, SetAccess = private)
        spin_polarization
    end

    methods
        function obj = CompleteDos(structure, totalDos, pdoss, normalize)
            if nargin < 4, normalize = false; end
            volume = [];
            if normalize, volume = structure.volume; end
            obj@kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                totalDos.efermi, totalDos.energies, ...
                totalDos.densities, volume);
            obj.structure = structure;
            obj.pdos = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos.normalizePdos(pdoss, structure.num_sites);
        end

        function value = get.spin_polarization(obj)
            atFermi = obj.get_interpolated_value(obj.efermi);
            if ~isfield(atFermi, "down")
                value = [];
            elseif atFermi.up + atFermi.down == 0
                value = NaN;
            else
                value = abs((atFermi.up - atFermi.down) / ...
                    (atFermi.up + atFermi.down));
            end
        end

        function value = get_normalized(obj)
            if ~isempty(obj.norm_vol)
                value = obj;
            else
                value = kssolv.analysis.matgenlab.electronic_structure. ...
                    CompleteDos(obj.structure, obj, obj.pdos, true);
            end
        end

        function value = get_site_orbital_dos(obj, site, orbital)
            siteIndex = obj.resolveSite(site);
            name = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos.orbitalName(orbital);
            value = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                obj.efermi, obj.energies, obj.pdos{siteIndex}.(name));
        end

        function value = get_site_dos(obj, site)
            siteIndex = obj.resolveSite(site);
            projected = obj.pdos{siteIndex};
            names = fieldnames(projected);
            if isempty(names)
                error("KSSOLV:Matgenlab:CompleteDos:EmptyProjection", ...
                    "No projected DOS exists for this site.");
            end
            densities = projected.(names{1});
            for index = 2:numel(names)
                densities = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    add_densities(densities, projected.(names{index}));
            end
            value = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                obj.efermi, obj.energies, densities);
        end

        function value = get_site_spd_dos(obj, site)
            siteIndex = obj.resolveSite(site);
            value = obj.aggregateOrbitals(obj.pdos(siteIndex));
        end

        function value = get_site_t2g_eg_resolved_dos(obj, site)
            siteIndex = obj.resolveSite(site);
            projected = obj.pdos{siteIndex};
            t2g = obj.sumNamedOrbitals(projected, {"dxy", "dxz", "dyz"});
            eg = obj.sumNamedOrbitals(projected, {"dx2", "dz2"});
            value = struct( ...
                "t2g", kssolv.analysis.matgenlab.electronic_structure. ...
                    Dos(obj.efermi, obj.energies, t2g), ...
                "e_g", kssolv.analysis.matgenlab.electronic_structure. ...
                    Dos(obj.efermi, obj.energies, eg));
        end

        function value = get_spd_dos(obj)
            value = obj.aggregateOrbitals(obj.pdos);
        end

        function value = get_element_dos(obj)
            value = containers.Map("KeyType", "char", "ValueType", "any");
            for index = 1:obj.structure.num_sites
                key = char(string(obj.structure.sites{index}.specie));
                current = obj.get_site_dos(index);
                if isKey(value, key)
                    current = value(key) + current;
                end
                value(key) = current;
            end
        end

        function value = get_element_spd_dos(obj, element)
            target = string(kssolv.analysis.matgenlab.core.getElSp(element));
            selected = cell(1, 0);
            for index = 1:obj.structure.num_sites
                if string(obj.structure.sites{index}.specie) == target
                    selected{end + 1} = obj.pdos{index}; %#ok<AGROW>
                end
            end
            value = obj.aggregateOrbitals(selected);
        end

        function value = get_band_filling(obj, band, elements, sites, spin)
            if nargin < 2 || isempty(band), band = "d"; end
            if nargin < 3, elements = {}; end
            if nargin < 4, sites = {}; end
            if nargin < 5, spin = []; end
            dos = obj.projectedDos(band, elements, sites);
            energies = dos.energies - dos.efermi;
            densities = dos.get_densities(spin);
            occupied = energies < 0;
            value = trapz(energies(occupied), densities(occupied)) / ...
                trapz(energies, densities);
        end

        function value = get_band_center(obj, band, elements, ...
                sites, spin, erange)
            if nargin < 2, band = []; end
            if nargin < 3, elements = {}; end
            if nargin < 4, sites = {}; end
            if nargin < 5, spin = []; end
            if nargin < 6, erange = []; end
            value = obj.get_n_moment(1, band, elements, sites, ...
                spin, erange, false);
        end

        function value = get_band_width(obj, band, elements, ...
                sites, spin, erange)
            if nargin < 2, band = []; end
            if nargin < 3, elements = {}; end
            if nargin < 4, sites = {}; end
            if nargin < 5, spin = []; end
            if nargin < 6, erange = []; end
            value = sqrt(obj.get_n_moment( ...
                2, band, elements, sites, spin, erange, true));
        end

        function value = get_band_skewness(obj, band, elements, ...
                sites, spin, erange)
            if nargin < 2, band = []; end
            if nargin < 3, elements = {}; end
            if nargin < 4, sites = {}; end
            if nargin < 5, spin = []; end
            if nargin < 6, erange = []; end
            second = obj.get_n_moment( ...
                2, band, elements, sites, spin, erange, true);
            third = obj.get_n_moment( ...
                3, band, elements, sites, spin, erange, true);
            value = third / second^(3/2);
        end

        function value = get_band_kurtosis(obj, band, elements, ...
                sites, spin, erange)
            if nargin < 2, band = []; end
            if nargin < 3, elements = {}; end
            if nargin < 4, sites = {}; end
            if nargin < 5, spin = []; end
            if nargin < 6, erange = []; end
            second = obj.get_n_moment( ...
                2, band, elements, sites, spin, erange, true);
            fourth = obj.get_n_moment( ...
                4, band, elements, sites, spin, erange, true);
            value = fourth / second^2;
        end

        function value = get_n_moment(obj, n, band, elements, ...
                sites, spin, erange, center)
            if nargin < 3 || isempty(band), band = "d"; end
            if nargin < 4, elements = {}; end
            if nargin < 5, sites = {}; end
            if nargin < 6, spin = []; end
            if nargin < 7, erange = []; end
            if nargin < 8 || isempty(center), center = true; end
            dos = obj.projectedDos(band, elements, sites);
            energies = dos.energies - dos.efermi;
            densities = dos.get_densities(spin);
            if ~isempty(erange)
                selected = energies >= erange(1) & energies <= erange(2);
                energies = energies(selected);
                densities = densities(selected);
            end
            if center
                location = obj.get_band_center( ...
                    band, elements, sites, spin, erange);
                polynomial = energies - location;
            else
                polynomial = energies;
            end
            value = trapz(energies, polynomial.^n .* densities) / ...
                trapz(energies, densities);
        end

        function value = get_hilbert_transform(obj, band, elements, sites)
            if nargin < 2 || isempty(band), band = "d"; end
            if nargin < 3, elements = {}; end
            if nargin < 4, sites = {}; end
            dos = obj.projectedDos(band, elements, sites);
            transformed = struct();
            names = fieldnames(dos.densities);
            for index = 1:numel(names)
                name = names{index};
                transformed.(name) = imag( ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    CompleteDos.analyticSignal(dos.densities.(name)));
            end
            value = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                obj.efermi, obj.energies, transformed);
        end

        function value = get_upper_band_edge(obj, band, elements, ...
                sites, spin, erange)
            if nargin < 2, band = []; end
            if nargin < 3, elements = {}; end
            if nargin < 4, sites = {}; end
            if nargin < 5, spin = []; end
            if nargin < 6, erange = []; end
            transformed = obj.get_hilbert_transform(band, elements, sites);
            energies = transformed.energies - transformed.efermi;
            densities = transformed.get_densities(spin);
            if ~isempty(erange)
                selected = energies >= erange(1) & energies <= erange(2);
                energies = energies(selected);
                densities = densities(selected);
            end
            [~, index] = max(densities);
            value = energies(index);
        end

        function value = get_dos_fp(obj, fpType, binning, minEnergy, ...
                maxEnergy, nBins, normalize)
            if nargin < 2 || isempty(fpType), fpType = "summed_pdos"; end
            if nargin < 3 || isempty(binning), binning = true; end
            if nargin < 4, minEnergy = []; end
            if nargin < 5, maxEnergy = []; end
            if nargin < 6 || isempty(nBins), nBins = 256; end
            if nargin < 7 || isempty(normalize), normalize = true; end
            fpType = string(fpType);
            energies = obj.energies - obj.efermi;
            if isempty(minEnergy), minEnergy = min(energies); end
            if isempty(maxEnergy), maxEnergy = max(energies); end
            spd = obj.get_spd_dos();
            values = containers.Map("KeyType", "char", "ValueType", "any");
            keys = spd.keys;
            summed = zeros(size(energies));
            for index = 1:numel(keys)
                density = spd(keys{index}).get_densities();
                values(keys{index}) = density;
                summed = summed + density;
            end
            values("summed_pdos") = summed;
            values("tdos") = obj.get_densities();
            key = char(fpType);
            if ~isKey(values, key)
                error("KSSOLV:Matgenlab:CompleteDos:InvalidFingerprint", ...
                    "Requested fingerprint projection is unavailable.");
            end
            density = values(key);
            if numel(energies) < nBins
                selected = energies >= minEnergy & energies <= maxEnergy;
                value = kssolv.analysis.matgenlab.electronic_structure. ...
                    DosFingerprint(energies(selected), density(selected), ...
                    fpType, numel(energies), energies(2)-energies(1));
                return
            end
            if binning
                bounds = linspace(minEnergy, maxEnergy, nBins + 1);
                centers = bounds(1:end-1) + ...
                    (bounds(2) - bounds(1)) / 2;
                binWidth = centers(2) - centers(1);
            else
                bounds = energies;
                centers = [energies, energies(end) + abs(energies(end))/10];
                nBins = numel(energies);
                binWidth = energies(2) - energies(1);
            end
            rebinned = zeros(size(centers));
            for index = 1:min(numel(centers), numel(bounds) - 1)
                selected = energies >= bounds(index) & ...
                    energies < bounds(index + 1);
                rebinned(index) = sum(density(selected));
            end
            if normalize
                rebinned = rebinned / sum(rebinned * binWidth);
            end
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                DosFingerprint(centers, rebinned, fpType, nBins, binWidth);
        end

        function value = as_dict(obj)
            value = as_dict@kssolv.analysis.matgenlab. ...
                electronic_structure.Dos(obj);
            value.x_class = classShortNameComplete(obj);
            value.structure = obj.structure.as_dict();
            value.pdos = cell(1, numel(obj.pdos));
            for siteIndex = 1:numel(obj.pdos)
                projected = obj.pdos{siteIndex};
                names = fieldnames(projected);
                row = struct();
                for orbitalIndex = 1:numel(names)
                    name = names{orbitalIndex};
                    channels = projected.(name);
                    keys = {'1'};
                    values = {channels.up};
                    if isfield(channels, "down")
                        keys{end+1} = '-1'; %#ok<AGROW>
                        values{end+1} = channels.down; %#ok<AGROW>
                    end
                    row.(name) = struct("densities", ...
                        containers.Map(keys, values, ...
                        "UniformValues", false));
                end
                value.pdos{siteIndex} = row;
            end
        end
    end

    methods (Static)
        function value = fp_to_dict(fingerprint)
            value = struct();
            value.(matlab.lang.makeValidName( ...
                fingerprint.fp_type)) = ...
                [fingerprint.energies(:), fingerprint.densities(:)];
        end

        function value = get_dos_fp_similarity(first, second, ...
                column, point, normalize, metric)
            if nargin < 3 || isempty(column), column = 1; end
            if nargin < 4 || isempty(point), point = "All"; end
            if nargin < 5 || isempty(normalize), normalize = false; end
            if nargin < 6 || isempty(metric), metric = "tanimoto"; end
            metric = string(metric);
            if ~any(metric == ["tanimoto","wasserstein","cosine-sim"])
                error("KSSOLV:Matgenlab:CompleteDos:InvalidSimilarity", ...
                    "Invalid metric='%s'.", metric);
            end
            if ~isscalar(column) || ~ismember(column,[0,1])
                error("KSSOLV:Matgenlab:CompleteDos:Column", ...
                    "column must be 0 (energies) or 1 (densities).");
            end
            firstVector = fingerprintVector(first,column,point);
            secondVector = fingerprintVector(second,column,point);
            if numel(firstVector) ~= numel(secondVector)
                error("KSSOLV:Matgenlab:CompleteDos:FingerprintSize", ...
                    "Fingerprint vectors must have equal lengths.");
            end
            if metric == "tanimoto" && ~normalize
                dotProduct = dot(firstVector, secondVector);
                value = dotProduct / ...
                    (norm(firstVector)^2 + norm(secondVector)^2 - ...
                    dotProduct);
            elseif metric == "cosine-sim" && normalize
                value = dot(firstVector, secondVector) / ...
                    (norm(firstVector) * norm(secondVector));
            elseif metric == "cosine-sim" && ~normalize
                value = dot(firstVector, secondVector);
            elseif metric == "wasserstein" && ~normalize
                if ~isa(first, ...
                        "kssolv.analysis.matgenlab.electronic_structure.DosFingerprint") || ...
                        ~isa(second, ...
                        "kssolv.analysis.matgenlab.electronic_structure.DosFingerprint")
                    error("KSSOLV:Matgenlab:CompleteDos:BinWidth", ...
                        "Wasserstein similarity requires DosFingerprint inputs.");
                end
                value = kssolv.analysis.matgenlab.electronic_structure. ...
                    CompleteDos.wasserstein( ...
                    cumsum(firstVector * first.bin_width), ...
                    cumsum(secondVector * second.bin_width));
            else
                error("KSSOLV:Matgenlab:CompleteDos:InvalidSimilarity", ...
                    "Unsupported similarity metric/normalization combination.");
            end
        end

        function obj = from_dict(value)
            total = kssolv.analysis.matgenlab.electronic_structure.Dos. ...
                from_dict(value);
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(value.structure);
            pdos = cell(1, numel(value.pdos));
            for siteIndex = 1:numel(pdos)
                if iscell(value.pdos)
                    row = value.pdos{siteIndex};
                else
                    row = value.pdos(siteIndex);
                end
                names = fieldnames(row);
                projected = struct();
                for orbitalIndex = 1:numel(names)
                    name = names{orbitalIndex};
                    channels = row.(name).densities;
                    projected.(name) = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        CompleteDos.normalizeSpin(channels);
                end
                pdos{siteIndex} = projected;
            end
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos(structure, total, pdos);
        end
    end

    methods (Access = private)
        function index = resolveSite(obj, site)
            if isnumeric(site) && isscalar(site)
                index = double(site);
                if index < 1 || index > obj.structure.num_sites || ...
                        index ~= fix(index)
                    error("KSSOLV:Matgenlab:CompleteDos:InvalidSite", ...
                        "Site index is outside the structure.");
                end
                return
            end
            index = find(cellfun(@(candidate) candidate == site, ...
                obj.structure.sites), 1);
            if isempty(index)
                error("KSSOLV:Matgenlab:CompleteDos:UnknownSite", ...
                    "Site does not belong to this structure.");
            end
        end

        function value = aggregateOrbitals(obj, projections)
            accumulated = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            for siteIndex = 1:numel(projections)
                names = fieldnames(projections{siteIndex});
                for orbitalIndex = 1:numel(names)
                    name = names{orbitalIndex};
                    key = char(extractBefore(string(name), 2));
                    channels = projections{siteIndex}.(name);
                    if isKey(accumulated, key)
                        channels = ...
                            kssolv.analysis.matgenlab.electronic_structure. ...
                            add_densities(accumulated(key), channels);
                    end
                    accumulated(key) = channels;
                end
            end
            value = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            keys = accumulated.keys;
            for index = 1:numel(keys)
                value(keys{index}) = ...
                    kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                    obj.efermi, obj.energies, accumulated(keys{index}));
            end
        end

        function value = sumNamedOrbitals(~, projected, names)
            selected = names(cellfun(@(name) ...
                isfield(projected, name), names));
            if isempty(selected)
                error("KSSOLV:Matgenlab:CompleteDos:MissingOrbital", ...
                    "The requested orbital projection is absent.");
            end
            value = projected.(selected{1});
            for index = 2:numel(selected)
                value = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    add_densities(value, projected.(selected{index}));
            end
        end

        function dos = projectedDos(obj, band, elements, sites)
            if ~isempty(elements) && ~isempty(sites)
                error("KSSOLV:Matgenlab:CompleteDos:AmbiguousSelection", ...
                    "Both element and site cannot be specified.");
            end
            key = char( ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos.orbitalTypeName(band));
            if ~isempty(elements)
                if ~iscell(elements), elements = num2cell(elements); end
                densities = [];
                for index = 1:numel(elements)
                    mapping = obj.get_element_spd_dos(elements{index});
                    current = mapping(key).densities;
                    if isempty(densities)
                        densities = current;
                    else
                        densities = ...
                            kssolv.analysis.matgenlab.electronic_structure. ...
                            add_densities(densities, current);
                    end
                end
                dos = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                    obj.efermi, obj.energies, densities);
            elseif ~isempty(sites)
                if ~iscell(sites), sites = num2cell(sites); end
                densities = [];
                for index = 1:numel(sites)
                    mapping = obj.get_site_spd_dos(sites{index});
                    current = mapping(key).densities;
                    if isempty(densities)
                        densities = current;
                    else
                        densities = ...
                            kssolv.analysis.matgenlab.electronic_structure. ...
                            add_densities(densities, current);
                    end
                end
                dos = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                    obj.efermi, obj.energies, densities);
            else
                mapping = obj.get_spd_dos();
                if ~isKey(mapping, key)
                    error("KSSOLV:Matgenlab:CompleteDos:MissingBand", ...
                        "The requested orbital band is absent.");
                end
                dos = mapping(key);
            end
        end
    end

    methods (Static, Access = protected)
        function value = normalizePdos(input, count)
            if ~iscell(input)
                error("KSSOLV:Matgenlab:CompleteDos:PdosMustBeCell", ...
                    "pdoss must be a cell array in structure-site order.");
            end
            if isempty(input)
                value = repmat({struct()}, 1, count);
                return
            end
            if numel(input) ~= count
                error("KSSOLV:Matgenlab:CompleteDos:PdosSizeMismatch", ...
                    "pdoss must contain one mapping per structure site.");
            end
            value = reshape(input, 1, []);
            for siteIndex = 1:numel(value)
                projected = value{siteIndex};
                if ~isstruct(projected)
                    error("KSSOLV:Matgenlab:CompleteDos:InvalidProjection", ...
                        "Each site projection must be a struct.");
                end
                names = fieldnames(projected);
                for orbitalIndex = 1:numel(names)
                    name = names{orbitalIndex};
                    projected.(name) = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        CompleteDos.normalizeSpin(projected.(name));
                end
                value{siteIndex} = projected;
            end
        end

        function value = normalizeSpin(input)
            if isa(input, "containers.Map")
                value = struct("up", input("1"));
                if isKey(input, "-1"), value.down = input("-1"); end
            elseif isstruct(input)
                value = struct();
                if isfield(input, "up"), value.up = input.up;
                elseif isfield(input, "x1"), value.up = input.x1;
                else
                    error("KSSOLV:Matgenlab:CompleteDos:MissingSpinUp", ...
                        "Projected DOS requires spin-up density.");
                end
                if isfield(input, "down"), value.down = input.down;
                elseif isfield(input, "x_1"), value.down = input.x_1;
                end
            else
                value = struct("up", input);
            end
        end

        function value = orbitalName(orbital)
            value = char(string(orbital));
        end

        function value = orbitalTypeName(band)
            if isa(band, ...
                    "kssolv.analysis.matgenlab.electronic_structure.OrbitalType")
                value = string(band);
            elseif isa(band, ...
                    "kssolv.analysis.matgenlab.electronic_structure.Orbital")
                value = string(band.orbital_type);
            else
                value = lower(string(band));
                value = extractBefore(value, 2);
            end
        end

        function signal = analyticSignal(values)
            values = reshape(double(values), 1, []);
            count = numel(values);
            multiplier = zeros(1, count);
            if mod(count, 2) == 0
                multiplier([1, count/2 + 1]) = 1;
                multiplier(2:count/2) = 2;
            else
                multiplier(1) = 1;
                multiplier(2:(count + 1)/2) = 2;
            end
            signal = ifft(fft(values) .* multiplier);
        end

        function value = wasserstein(first, second)
            first = sort(first(:));
            second = sort(second(:));
            probabilities = unique([first; second]);
            if numel(probabilities) < 2
                value = 0;
                return
            end
            deltas = diff(probabilities);
            firstCdf = arrayfun(@(x) mean(first <= x), ...
                probabilities(1:end-1));
            secondCdf = arrayfun(@(x) mean(second <= x), ...
                probabilities(1:end-1));
            value = sum(abs(firstCdf - secondCdf) .* deltas);
        end
    end
end

function vector = fingerprintVector(fingerprint,column,point)
if isa(fingerprint, ...
        "kssolv.analysis.matgenlab.electronic_structure.DosFingerprint")
    if ~(ischar(point) || isstring(point)) && ...
            (~isscalar(point) || ~ismember(double(point),[0,1]))
        error("KSSOLV:Matgenlab:CompleteDos:PointSelection", ...
            "A DosFingerprint contains one fingerprint; point must be All, 0, or 1.");
    end
    if column == 0
        vector = fingerprint.energies(:);
    else
        vector = fingerprint.densities(:);
    end
    return
end
if ~isstruct(fingerprint)
    error("KSSOLV:Matgenlab:CompleteDos:Fingerprint", ...
        "A fingerprint must be DosFingerprint or a fingerprint struct.");
end
names = fieldnames(fingerprint);
if ischar(point) || isstring(point)
    if string(point) ~= "All"
        error("KSSOLV:Matgenlab:CompleteDos:PointSelection", ...
            "String point selection must be 'All'.");
    end
    selected = 1:numel(names);
else
    selected = double(point);
    if selected == 0, selected = 1; end
    if ~isscalar(selected) || selected < 1 || ...
            selected > numel(names) || selected ~= fix(selected)
        error("KSSOLV:Matgenlab:CompleteDos:PointSelection", ...
            "point is outside the fingerprint mapping.");
    end
end
parts = cell(1,numel(selected));
for index = 1:numel(selected)
    array = fingerprint.(names{selected(index)});
    if size(array,2) < column+1
        error("KSSOLV:Matgenlab:CompleteDos:Column", ...
            "Fingerprint mapping entries must have energy and density columns.");
    end
    parts{index} = array(:,column+1);
end
vector = vertcat(parts{:});
end

function value = classShortNameComplete(obj)
name = split(string(class(obj)), ".");
value = name(end);
end
