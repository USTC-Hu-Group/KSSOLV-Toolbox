function pattern = powder_diffraction_pattern( ...
        mode, structure, wavelength, symprec, debyeWallerFactors, ...
        scaled, twoThetaRange)
%POWDER_DIFFRACTION_PATTERN Shared X-ray/neutron powder algorithm.

if ~isa(structure, "kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:Diffraction:Structure", ...
        "structure must be a matgenlab periodic structure.");
end
if symprec
    analyzer = ...
        kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(structure, symprec);
    structure = analyzer.get_refined_structure();
end

if isempty(twoThetaRange)
    minRadius = 0;
    maxRadius = 2 / wavelength;
elseif isnumeric(twoThetaRange) && numel(twoThetaRange) == 2 && ...
        all(isfinite(twoThetaRange))
    twoThetaRange = reshape(double(twoThetaRange), 1, 2);
    radii = 2 * sind(twoThetaRange / 2) / wavelength;
    minRadius = radii(1);
    maxRadius = radii(2);
else
    error("KSSOLV:Matgenlab:Diffraction:TwoThetaRange", ...
        "two_theta_range must be empty or a finite two-element vector.");
end

lattice = structure.lattice;
isHexagonal = lattice.is_hexagonal();
reciprocal = lattice.reciprocal_lattice_crystallographic;
points = reciprocal.get_points_in_sphere([0, 0, 0], [0, 0, 0], ...
    maxRadius);
if ~isempty(points)
    hklMatrix = vertcat(points{:, 1});
    distances = vertcat(points{:, 2});
    keep = distances >= minRadius;
    points = points(keep, :);
    hklMatrix = hklMatrix(keep, :);
    distances = distances(keep);
    [~, order] = sortrows([distances, -hklMatrix], 1:4);
    points = points(order, :);
end

table = kssolv.analysis.matgenlab.analysis.diffraction_data(mode);
siteCount = 0;
for siteIndex = 1:structure.num_sites
    siteCount = siteCount + length(structure(siteIndex).species);
end
fracCoords = zeros(siteCount, 3);
occupancies = zeros(siteCount, 1);
dwFactors = zeros(siteCount, 1);
if mode == "xray"
    atomicNumbers = zeros(siteCount, 1);
    coefficients = zeros(siteCount, 4, 2);
else
    scatteringLengths = zeros(siteCount, 1);
end

flatIndex = 0;
for siteIndex = 1:structure.num_sites
    site = structure(siteIndex);
    [species, amounts] = site.species.items();
    for speciesIndex = 1:numel(species)
        flatIndex = flatIndex + 1;
        specie = species{speciesIndex};
        symbol = char(specie.symbol);
        if ~isfield(table, symbol)
            error("KSSOLV:Matgenlab:Diffraction:MissingCoefficient", ...
                "No %s scattering coefficients are available for %s.", ...
                mode, symbol);
        end
        fracCoords(flatIndex, :) = site.frac_coords;
        occupancies(flatIndex) = amounts(speciesIndex);
        dwFactors(flatIndex) = factorValue(debyeWallerFactors, symbol);
        if mode == "xray"
            atomicNumbers(flatIndex) = specie.Z;
            coefficients(flatIndex, :, :) = table.(symbol);
        else
            scatteringLengths(flatIndex) = table.(symbol);
        end
    end
end

peakAngles = zeros(0, 1);
peakIntensities = zeros(0, 1);
peakHkls = cell(0, 1);
peakSpacings = zeros(0, 1);
for pointIndex = 1:size(points, 1)
    hkl = round(points{pointIndex, 1});
    gHkl = points{pointIndex, 2};
    if gHkl == 0
        continue
    end
    argument = wavelength * gHkl / 2;
    if argument > 1 && argument < 1 + 1e-12
        argument = 1;
    end
    theta = asin(argument);
    sSquared = (gHkl / 2)^2;
    phase = fracCoords * hkl.';
    dwCorrection = exp(-dwFactors * sSquared);
    if mode == "xray"
        a = coefficients(:, :, 1);
        b = coefficients(:, :, 2);
        scattering = atomicNumbers - 41.78214 * sSquared .* ...
            sum(a .* exp(-b * sSquared), 2);
        lorentz = (1 + cos(2 * theta)^2) / ...
            (sin(theta)^2 * cos(theta));
    else
        scattering = scatteringLengths;
        lorentz = 1 / (sin(theta)^2 * cos(theta));
    end
    structureFactor = sum(scattering .* occupancies .* ...
        exp(2i * pi * phase) .* dwCorrection);
    intensity = real(structureFactor * conj(structureFactor));
    twoTheta = rad2deg(2 * theta);
    if isHexagonal
        hkl = [hkl(1), hkl(2), -hkl(1) - hkl(2), hkl(3)];
    end
    existing = find(abs(peakAngles - twoTheta) < ...
        kssolv.analysis.matgenlab.analysis. ...
        AbstractDiffractionPatternCalculator.TWO_THETA_TOL, 1);
    if isempty(existing)
        peakAngles(end + 1, 1) = twoTheta; %#ok<AGROW>
        peakIntensities(end + 1, 1) = intensity * lorentz; %#ok<AGROW>
        peakHkls{end + 1, 1} = {hkl}; %#ok<AGROW>
        peakSpacings(end + 1, 1) = 1 / gHkl; %#ok<AGROW>
    else
        peakIntensities(existing) = ...
            peakIntensities(existing) + intensity * lorentz;
        peakHkls{existing}{end + 1} = hkl;
    end
end
if isempty(peakIntensities)
    error("KSSOLV:Matgenlab:Diffraction:NoPeaks", ...
        "No diffracted beams fall in the requested two-theta range.");
end

maximum = max(peakIntensities);
[peakAngles, order] = sort(peakAngles);
peakIntensities = peakIntensities(order);
peakHkls = peakHkls(order);
peakSpacings = peakSpacings(order);
keep = peakIntensities / maximum * 100 > ...
    kssolv.analysis.matgenlab.analysis. ...
    AbstractDiffractionPatternCalculator.SCALED_INTENSITY_TOL;
peakAngles = peakAngles(keep);
peakIntensities = peakIntensities(keep);
peakHkls = peakHkls(keep);
peakSpacings = peakSpacings(keep);
families = cell(numel(peakHkls), 1);
for index = 1:numel(peakHkls)
    families{index} = ...
        kssolv.analysis.matgenlab.analysis. ...
        get_unique_families(peakHkls{index});
end
pattern = kssolv.analysis.matgenlab.analysis.DiffractionPattern( ...
    peakAngles, peakIntensities, families, peakSpacings);
if scaled
    pattern.normalize("max", 100);
end
end

function value = factorValue(factors, symbol)
value = 0;
if isempty(factors), return; end
if isa(factors, "containers.Map")
    if isKey(factors, symbol)
        value = double(factors(symbol));
    elseif isKey(factors, string(symbol))
        value = double(factors(string(symbol)));
    end
elseif isstruct(factors) && isfield(factors, symbol)
    value = double(factors.(symbol));
elseif istable(factors) && ...
        any(string(factors.Properties.RowNames) == string(symbol))
    value = double(factors{symbol, 1});
end
end
