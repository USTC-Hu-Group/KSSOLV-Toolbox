classdef StandardMoleculeOracleCatalog
    %STANDARDMOLECULEORACLECATALOG Independent P4 hydrogen/valence oracle.
    %
    % The expected formulae below come from closed-form homologous-series
    % identities. They deliberately do not call MoleculeDiagnostics or its
    % target-valence rules. The catalog covers twenty chemically distinct
    % families and four bond representations (single, double, triple and
    % aromatic), rather than repeating one alkane series.

    methods (Static)
        function entries = entries()
            families = [ ...
                "alkane", "terminal-alkene", "terminal-alkyne", ...
                "cycloalkane", "primary-alcohol", "ether", ...
                "aldehyde", "ketone", "carboxylic-acid", "ester", ...
                "primary-amine", "nitrile", "primary-amide", ...
                "fluoroalkane", "chloroalkane", "bromoalkane", ...
                "thiol", "thioether", "alkylbenzene", ...
                "alkylpyridine"];
            values = cell(1, numel(families) * 10);
            serial = 0;
            for family = families
                for variant = 1:10
                    serial = serial + 1;
                    values{serial} = createEntry(family, variant);
                end
            end
            entries = [values{:}];
        end

        function molecule = molecule(entry)
            siteProperties = struct( ...
                "formal_charge", zeros(1, numel(entry.species)), ...
                "hybridization", repmat("auto", 1, ...
                numel(entry.species)), ...
                "is_aromatic", reshape(logical(entry.aromatic), 1, []));
            properties = struct("topology", struct( ...
                "bonds", double(entry.bonds), "origin", "oracle", ...
                "schemaVersion", 1), "oracleId", entry.id);
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                entry.species, entry.coordinates, ...
                site_properties = siteProperties, ...
                charge_spin_check = false, properties = properties);
        end
    end
end

function entry = createEntry(family, variant)
aromatic = false(1, 0);
switch family
    case "alkane"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        expected = counts(carbonCount, 2 * carbonCount + 2);
    case "terminal-alkene"
        carbonCount = variant + 1;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        bonds(1, 3) = 2;
        expected = counts(carbonCount, 2 * carbonCount);
    case "terminal-alkyne"
        carbonCount = variant + 1;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        bonds(1, 3) = 3;
        expected = counts(carbonCount, 2 * carbonCount - 2);
    case "cycloalkane"
        carbonCount = variant + 2;
        [species, coordinates, bonds] = carbonRing(carbonCount, 1.54, 1);
        expected = counts(carbonCount, 2 * carbonCount);
    case "primary-alcohol"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "O", [-1.43, 0, 0], 1, 1);
        expected = counts(carbonCount, 2 * carbonCount + 2, O = 1);
    case "ether"
        carbonCount = variant + 1;
        species = [repmat("C", 1, carbonCount), "O"];
        coordinates = [(-1.43:1.54:(-1.43 + ...
            1.54 * (carbonCount - 1))).', zeros(carbonCount, 2); ...
            0, 1.43, 0];
        oxygen = carbonCount + 1;
        bonds = [oxygen, 1, 1; oxygen, 2, 1; ...
            (2:carbonCount - 1).', (3:carbonCount).', ...
            ones(max(carbonCount - 2, 0), 1)];
        expected = counts(carbonCount, 2 * carbonCount + 2, O = 1);
    case "aldehyde"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "O", [-1.23, 0, 0], 1, 2);
        expected = counts(carbonCount, 2 * carbonCount, O = 1);
    case "ketone"
        carbonCount = variant + 2;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "O", [1.54, 1.23, 0], 2, 2);
        expected = counts(carbonCount, 2 * carbonCount, O = 1);
    case "carboxylic-acid"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "O", [-1.23, 0, 0], 1, 2);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "O", [0, 1.43, 0], 1, 1);
        expected = counts(carbonCount, 2 * carbonCount, O = 2);
    case "ester"
        carbonCount = variant + 1;
        species = [repmat("C", 1, carbonCount), "O", "O"];
        coordinates = [(0:carbonCount - 1).' * 1.54, ...
            zeros(carbonCount, 2); -1.23, 0, 0; 0, 1.43, 0];
        carbonylOxygen = carbonCount + 1;
        etherOxygen = carbonCount + 2;
        bonds = [1, carbonylOxygen, 2; 1, etherOxygen, 1; ...
            etherOxygen, 2, 1; (2:carbonCount - 1).', ...
            (3:carbonCount).', ones(max(carbonCount - 2, 0), 1)];
        expected = counts(carbonCount, 2 * carbonCount, O = 2);
    case "primary-amine"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "N", [-1.47, 0, 0], 1, 1);
        expected = counts(carbonCount, 2 * carbonCount + 3, N = 1);
    case "nitrile"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "N", [-1.16, 0, 0], 1, 3);
        expected = counts(carbonCount, 2 * carbonCount - 1, N = 1);
    case "primary-amide"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "O", [-1.23, 0, 0], 1, 2);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "N", [0, 1.35, 0], 1, 1);
        expected = counts(carbonCount, 2 * carbonCount + 1, N = 1, O = 1);
    case {"fluoroalkane", "chloroalkane", "bromoalkane"}
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        symbol = struct("fluoroalkane", "F", ...
            "chloroalkane", "Cl", "bromoalkane", "Br").(family);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, symbol, [-1.78, 0, 0], 1, 1);
        switch symbol
            case "F"
                expected = counts(carbonCount, ...
                    2 * carbonCount + 1, F = 1);
            case "Cl"
                expected = counts(carbonCount, ...
                    2 * carbonCount + 1, Cl = 1);
            case "Br"
                expected = counts(carbonCount, ...
                    2 * carbonCount + 1, Br = 1);
        end
    case "thiol"
        carbonCount = variant;
        [species, coordinates, bonds] = carbonChain(carbonCount);
        [species, coordinates, bonds] = appendAtom( ...
            species, coordinates, bonds, "S", [-1.82, 0, 0], 1, 1);
        expected = counts(carbonCount, 2 * carbonCount + 2, S = 1);
    case "thioether"
        carbonCount = variant + 1;
        species = [repmat("C", 1, carbonCount), "S"];
        coordinates = [(-1.82:1.54:(-1.82 + ...
            1.54 * (carbonCount - 1))).', zeros(carbonCount, 2); ...
            0, 1.82, 0];
        sulfur = carbonCount + 1;
        bonds = [sulfur, 1, 1; sulfur, 2, 1; ...
            (2:carbonCount - 1).', (3:carbonCount).', ...
            ones(max(carbonCount - 2, 0), 1)];
        expected = counts(carbonCount, 2 * carbonCount + 2, S = 1);
    case "alkylbenzene"
        [species, coordinates, bonds] = carbonRing(6, 1.397, 1.5);
        aromatic = true(1, 6);
        substituent = variant - 1;
        [species, coordinates, bonds] = appendRadialChain( ...
            species, coordinates, bonds, 1, substituent);
        carbonCount = 6 + substituent;
        expected = counts(carbonCount, 2 * carbonCount - 6);
    case "alkylpyridine"
        [species, coordinates, bonds] = carbonRing(6, 1.397, 1.5);
        species(1) = "N";
        aromatic = true(1, 6);
        substituent = variant - 1;
        [species, coordinates, bonds] = appendRadialChain( ...
            species, coordinates, bonds, 2, substituent);
        carbonCount = 5 + substituent;
        expected = counts(carbonCount, 2 * carbonCount - 5, N = 1);
    otherwise
        error("KSSOLV:Modeling:StandardMoleculeFamily", ...
            "Unknown oracle family '%s'.", family);
end
if isempty(aromatic), aromatic = false(1, numel(species));
else, aromatic(end + 1:numel(species)) = false;
end
bonds(:, 1:2) = sort(bonds(:, 1:2), 2);
bonds = sortrows(bonds, [1, 2]);
entry = struct("id", family + "-" + compose("%02d", variant), ...
    "name", family + " member " + variant, "family", family, ...
    "variant", variant, "carbonCount", carbonCount, ...
    "species", reshape(species, 1, []), ...
    "coordinates", double(coordinates), "bonds", double(bonds), ...
    "aromatic", aromatic, "expectedCounts", expected, ...
    "expectedHydrogens", expected.H, ...
    "expectedFormula", formulaText(expected));
end

function [species, coordinates, bonds] = carbonChain(count)
species = repmat("C", 1, count);
coordinates = [(0:count - 1).' * 1.54, zeros(count, 2)];
bonds = [(1:count - 1).', (2:count).', ones(max(count - 1, 0), 1)];
end

function [species, coordinates, bonds] = carbonRing(count, lengthValue, order)
radius = lengthValue / (2 * sin(pi / count));
angles = (0:count - 1).' * 2 * pi / count;
coordinates = [radius * cos(angles), radius * sin(angles), zeros(count, 1)];
species = repmat("C", 1, count);
bonds = [(1:count).', [2:count, 1].', repmat(order, count, 1)];
end

function [species, coordinates, bonds] = appendAtom( ...
        species, coordinates, bonds, symbol, coordinate, anchor, order)
species(end + 1) = symbol;
coordinates(end + 1, :) = coordinate;
bonds(end + 1, :) = [anchor, numel(species), order];
end

function [species, coordinates, bonds] = appendRadialChain( ...
        species, coordinates, bonds, anchor, count)
if count == 0, return, end
direction = coordinates(anchor, :) / norm(coordinates(anchor, :));
for index = 1:count
    coordinate = coordinates(anchor, :) + 1.50 * index * direction;
    previous = anchor;
    if index > 1, previous = numel(species); end
    [species, coordinates, bonds] = appendAtom( ...
        species, coordinates, bonds, "C", coordinate, previous, 1);
end
end

function value = counts(carbon, hydrogen, options)
arguments
    carbon (1,1) double
    hydrogen (1,1) double
    options.N (1,1) double = 0
    options.O (1,1) double = 0
    options.S (1,1) double = 0
    options.F (1,1) double = 0
    options.Cl (1,1) double = 0
    options.Br (1,1) double = 0
end
value = struct("C", carbon, "H", hydrogen, "N", options.N, ...
    "O", options.O, "S", options.S, "F", options.F, ...
    "Cl", options.Cl, "Br", options.Br);
end

function value = formulaText(countValues)
order = ["C", "H", "Br", "Cl", "F", "N", "O", "S"];
value = "";
for symbol = order
    count = countValues.(symbol);
    if count == 0, continue, end
    value = value + symbol;
    if count ~= 1, value = value + string(count); end
end
end
