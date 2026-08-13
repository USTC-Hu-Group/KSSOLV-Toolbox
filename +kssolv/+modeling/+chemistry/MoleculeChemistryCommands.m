classdef MoleculeChemistryCommands
    %MOLECULECHEMISTRYCOMMANDS Topology-aware molecular sketch commands.

    methods (Static)
        function ids = commandIds()
            ids = [
                "sketch_atom"
                "add_bond"
                "delete_bond"
                "set_bond_order"
                "sketch_ring"
                "set_atom_chemistry"
                "add_hydrogens"
                "remove_hydrogens"
                "diagnose_molecule"
                ];
        end

        function value = supports(commandId)
            value = any(kssolv.modeling.chemistry. ...
                MoleculeChemistryCommands.commandIds() == string(commandId));
        end

        function result = execute(model, commandId, parameters)
            import kssolv.modeling.ParameterUtils
            Chemistry = @kssolv.modeling.chemistry.MoleculeChemistryCommands;
            commandId = string(commandId);
            bonds = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
                topology(model);
            changed = true;
            analysis = struct();
            switch commandId
                case "sketch_atom"
                    species = string(ParameterUtils.get(parameters, ...
                        "species", "C"));
                    validateElementSymbol(species);
                    connectTo = double(ParameterUtils.get(parameters, ...
                        "connectTo", 0));
                    order = double(ParameterUtils.get(parameters, ...
                        "bondOrder", 1));
                    useIdealBondLength = ParameterUtils.logical( ...
                        parameters, "useIdealBondLength", false);
                    if useIdealBondLength
                        coordinates = idealSketchCoordinates( ...
                            model, bonds, species, connectTo, order);
                    else
                        coordinates = ParameterUtils.vector(parameters, ...
                            "coordinates", 3, [0, 0, 0]);
                    end
                    validateSketchPlacement( ...
                        model, species, coordinates, connectTo, order);
                    charge = double(ParameterUtils.get(parameters, ...
                        "formalCharge", 0));
                    hybridization = string(ParameterUtils.get(parameters, ...
                        "hybridization", "auto"));
                    aromatic = ParameterUtils.logical(parameters, ...
                        "aromatic", false);
                    siteProperties = struct("formal_charge", charge, ...
                        "hybridization", hybridization, ...
                        "is_aromatic", aromatic);
                    model = model.append(species, coordinates, ...
                        validate_proximity = false, ...
                        properties = siteProperties);
                    if connectTo > 0
                        bonds = addOrReplaceBond(bonds, connectTo, ...
                            model.num_sites, order, false);
                    end
                    model = Chemistry().withTopology(model, bonds);
                case "add_bond"
                    pair = bondPair(parameters, model.num_sites);
                    order = double(ParameterUtils.get(parameters, ...
                        "bondOrder", 1));
                    bonds = addOrReplaceBond(bonds, pair(1), pair(2), ...
                        order, false);
                    model = Chemistry().withTopology(model, bonds);
                case "delete_bond"
                    pair = bondPair(parameters, model.num_sites);
                    mask = bondMask(bonds, pair(1), pair(2));
                    if ~any(mask)
                        error("KSSOLV:Modeling:MissingBond", ...
                            "No bond exists between sites %d and %d.", pair);
                    end
                    bonds(mask, :) = [];
                    model = Chemistry().withTopology(model, bonds);
                case "set_bond_order"
                    pair = bondPair(parameters, model.num_sites);
                    order = double(ParameterUtils.get(parameters, ...
                        "bondOrder", 1));
                    mask = bondMask(bonds, pair(1), pair(2));
                    if ~any(mask)
                        error("KSSOLV:Modeling:MissingBond", ...
                            "No bond exists between sites %d and %d.", pair);
                    end
                    validateBondOrder(order);
                    bonds(mask, 3) = order;
                    model = Chemistry().withTopology(model, bonds);
                    if order == 1.5
                        model = setSiteProperty(model, pair, ...
                            "is_aromatic", true);
                    end
                case "sketch_ring"
                    ringSize = double(ParameterUtils.get(parameters, ...
                        "ringSize", 6));
                    if ~isscalar(ringSize) || ringSize < 3 || ...
                            ringSize > 8 || ringSize ~= fix(ringSize)
                        error("KSSOLV:Modeling:RingSize", ...
                            "Sketch rings must contain 3 to 8 atoms.");
                    end
                    center = ParameterUtils.vector(parameters, ...
                        "center", 3, [0, 0, 0]);
                    normal = ParameterUtils.vector(parameters, ...
                        "normal", 3, [0, 0, 1]);
                    species = string(ParameterUtils.get(parameters, ...
                        "species", "C"));
                    aromatic = ParameterUtils.logical(parameters, ...
                        "aromatic", ringSize == 6);
                    defaultOrder = 1;
                    if aromatic, defaultOrder = 1.5; end
                    order = double(ParameterUtils.get(parameters, ...
                        "bondOrder", defaultOrder));
                    sideLength = double(ParameterUtils.get(parameters, ...
                        "bondLength", 1.40));
                    coordinates = ringCoordinates( ...
                        ringSize, center, normal, sideLength);
                    firstNew = model.num_sites + 1;
                    for index = 1:ringSize
                        model = model.append(species, coordinates(index, :), ...
                            properties = struct("formal_charge", 0, ...
                            "hybridization", "sp2", ...
                            "is_aromatic", aromatic));
                    end
                    for index = 1:ringSize
                        first = firstNew + index - 1;
                        second = firstNew + mod(index, ringSize);
                        bonds = addOrReplaceBond(bonds, first, second, ...
                            order, false);
                    end
                    attachTo = double(ParameterUtils.get(parameters, ...
                        "attachTo", 0));
                    if attachTo > 0
                        bonds = addOrReplaceBond(bonds, attachTo, ...
                            firstNew, 1, false);
                    end
                    model = Chemistry().withTopology(model, bonds);
                case "set_atom_chemistry"
                    indices = ParameterUtils.indices(parameters, ...
                        model.num_sites, []);
                    if isfield(parameters, "species") && ...
                            strlength(string(parameters.species)) > 0 && ...
                            ~strcmpi(string(parameters.species), "unchanged")
                        for index = indices
                            model = model.replace(index, ...
                                string(parameters.species));
                        end
                    end
                    fields = ["formal_charge", "hybridization", ...
                        "is_aromatic"];
                    parameterFields = ["formalCharge", ...
                        "hybridization", "aromatic"];
                    for fieldIndex = 1:numel(fields)
                        parameterName = char(parameterFields(fieldIndex));
                        if isfield(parameters, parameterName)
                            model = setSiteProperty(model, indices, ...
                                fields(fieldIndex), ...
                                parameters.(parameterName));
                        end
                    end
                    charge = 0;
                    for index = 1:model.num_sites
                        charge = charge + double(kssolv.modeling.chemistry. ...
                            MoleculeDiagnostics.siteScalar( ...
                            model(index), "formal_charge", 0));
                    end
                    model = model.set_charge_and_spin(charge, []);
                    model = Chemistry().withTopology(model, bonds);
                case "add_hydrogens"
                    indices = ParameterUtils.indices(parameters, ...
                        model.num_sites, 1:model.num_sites);
                    [model, bonds] = addHydrogens(model, bonds, indices);
                    model = Chemistry().withTopology(model, bonds);
                case "remove_hydrogens"
                    indices = ParameterUtils.indices(parameters, ...
                        model.num_sites, 1:model.num_sites);
                    remove = hydrogenNeighbors(model, bonds, indices);
                    if isempty(remove), changed = false;
                    else, model = model.remove_sites(remove);
                    end
                case "diagnose_molecule"
                    analysis = kssolv.modeling.chemistry. ...
                        MoleculeDiagnostics.inspect(model);
                    changed = false;
                otherwise
                    error("KSSOLV:Modeling:MoleculeCommand", ...
                        "Unsupported molecule command '%s'.", commandId);
            end
            result = struct("model", model, "changed", changed, ...
                "message", "Molecule updated.");
            if commandId == "diagnose_molecule"
                result.analysis = analysis;
                result.message = "Molecule diagnostics completed.";
            end
        end

        function model = withTopology(model, bonds)
            bonds = normalizeBonds(bonds, model.num_sites);
            properties = model.properties;
            properties.topology = struct("bonds", bonds, ...
                "origin", "source", "schemaVersion", 1);
            model = kssolv.analysis.matgenlab.core.Molecule.from_sites( ...
                model.sites, charge = model.charge, ...
                spin_multiplicity = model.spin_multiplicity, ...
                charge_spin_check = false, properties = properties);
        end
    end
end

function validateElementSymbol(species)
if ~isscalar(species) || ismissing(species) || strlength(species) == 0 || ...
        ~kssolv.analysis.matgenlab.core.Element.isValidSymbol(species)
    error("KSSOLV:Modeling:SketchElement", ...
        "Sketch Atom requires one valid element symbol; received '%s'.", ...
        species);
end
end

function validateSketchPlacement(model, species, coordinates, connectTo, order)
if ~isscalar(connectTo) || ~isfinite(connectTo) || ...
        connectTo ~= fix(connectTo) || connectTo < 0 || ...
        connectTo > model.num_sites
    error("KSSOLV:Modeling:SketchConnection", ...
        "Sketch connection site must be an integer from 0 to %d.", ...
        model.num_sites);
end
validateBondOrder(order);
if connectTo > 0
    hostSymbol = string(model(connectTo).specie.symbol);
    parameter = kssolv.modeling.forcefield. ...
        GeometryParameterProvider.bond(hostSymbol, species, order);
    actual = norm(coordinates - model(connectTo).coords);
    minimum = max(0.6, 0.65 * double(parameter.value));
    if actual < minimum
        error("KSSOLV:Modeling:SketchBondTooShort", ...
            "Cannot sketch a %s-%s bond of order %g at %.4g angstrom. " + ...
            "The minimum construction length is %.4g angstrom " + ...
            "(ideal %.4g angstrom; %s).", ...
            hostSymbol, species, order, actual, minimum, ...
            parameter.value, parameter.source);
    end
end

for index = 1:model.num_sites
    if index == connectTo, continue, end
    otherSymbol = string(model(index).specie.symbol);
    parameter = kssolv.modeling.forcefield. ...
        GeometryParameterProvider.nonbonded(otherSymbol, species);
    actual = norm(coordinates - model(index).coords);
    if actual < double(parameter.cutoff)
        error("KSSOLV:Modeling:SketchCollision", ...
            "Cannot place %s within %.4g angstrom of %s%d. " + ...
            "The nonbonded construction cutoff is %.4g angstrom (%s).", ...
            species, actual, otherSymbol, index, ...
            parameter.cutoff, parameter.source);
    end
end
end

function coordinates = idealSketchCoordinates( ...
        model, bonds, species, connectTo, order)
if ~isscalar(connectTo) || ~isfinite(connectTo) || ...
        connectTo ~= fix(connectTo) || connectTo < 1 || ...
        connectTo > model.num_sites
    error("KSSOLV:Modeling:IdealSketchConnection", ...
        "Force-field bond placement requires one existing connection atom.");
end
validateBondOrder(order);
hostSymbol = string(model(connectTo).specie.symbol);
parameter = kssolv.modeling.forcefield. ...
    GeometryParameterProvider.bond(hostSymbol, species, order);
directions = placementDirections(model, bonds, connectTo, 1);
coordinates = model(connectTo).coords + ...
    double(parameter.value) * directions(1, :);
end

function pair = bondPair(parameters, siteCount)
import kssolv.modeling.ParameterUtils
pair = ParameterUtils.indices(parameters, siteCount, []);
if numel(pair) ~= 2
    error("KSSOLV:Modeling:BondSelection", ...
        "A bond operation requires exactly two atom indices.");
end
pair = reshape(pair, 1, 2);
if pair(1) == pair(2)
    error("KSSOLV:Modeling:SelfBond", "An atom cannot bond to itself.");
end
end

function mask = bondMask(bonds, first, second)
mask = (bonds(:, 1) == first & bonds(:, 2) == second) | ...
    (bonds(:, 1) == second & bonds(:, 2) == first);
end

function bonds = addOrReplaceBond(bonds, first, second, order, replace)
validateBondOrder(order);
if first < 1 || second < 1 || first ~= fix(first) || second ~= fix(second)
    error("KSSOLV:Modeling:BondIndex", "Bond indices must be positive integers.");
end
mask = bondMask(bonds, first, second);
if any(mask)
    if replace, bonds(mask, 3) = order;
    else
        error("KSSOLV:Modeling:DuplicateBond", ...
            "A bond already exists between sites %d and %d.", first, second);
    end
else
    bonds(end + 1, :) = [min(first, second), max(first, second), order];
end
end

function validateBondOrder(order)
if ~isscalar(order) || ~any(abs(order - [.5, 1, 1.5, 2, 3]) < 1e-12)
    error("KSSOLV:Modeling:BondOrder", ...
        "Bond order must be coordination (0.5), single, aromatic, " + ...
        "double, or triple.");
end
end

function bonds = normalizeBonds(bonds, siteCount)
if isempty(bonds), bonds = zeros(0, 3); return, end
bonds = double(bonds);
if size(bonds, 2) ~= 3 || any(bonds(:, 1:2) < 1, "all") || ...
        any(bonds(:, 1:2) > siteCount, "all")
    error("KSSOLV:Modeling:MoleculeTopology", ...
        "Topology contains invalid atom indices.");
end
for row = 1:size(bonds, 1), validateBondOrder(bonds(row, 3)); end
bonds(:, 1:2) = sort(bonds(:, 1:2), 2);
[~, order] = sortrows(bonds(:, 1:2), [1, 2]); bonds = bonds(order, :);
if size(unique(bonds(:, 1:2), "rows"), 1) ~= size(bonds, 1)
    error("KSSOLV:Modeling:DuplicateBond", ...
        "Topology contains duplicate atom pairs.");
end
end

function model = setSiteProperty(model, indices, name, value)
for index = reshape(indices, 1, [])
    site = model(index); properties = site.site_properties;
    if string(name) == "formal_charge", value = double(value); end
    if string(name) == "is_aromatic", value = logical(value); end
    properties.(char(name)) = value;
    model = model.replace(index, [], [], properties = properties);
end
end

function coordinates = ringCoordinates(count, center, normal, sideLength)
normal = reshape(double(normal), 1, 3);
if norm(normal) <= eps
    error("KSSOLV:Modeling:RingNormal", "Ring normal cannot be zero.");
end
normal = normal / norm(normal);
reference = [1, 0, 0];
if abs(dot(reference, normal)) > 0.9, reference = [0, 1, 0]; end
firstAxis = cross(normal, reference); firstAxis = firstAxis / norm(firstAxis);
secondAxis = cross(normal, firstAxis);
radius = sideLength / (2 * sin(pi / count));
angles = (0:count - 1).' * 2 * pi / count;
coordinates = center + radius * (cos(angles) * firstAxis + ...
    sin(angles) * secondAxis);
end

function [model, bonds] = addHydrogens(model, bonds, indices)
originalCount = model.num_sites;
bondSums = zeros(originalCount, 1);
for row = 1:size(bonds, 1)
    bondSums(bonds(row, 1)) = bondSums(bonds(row, 1)) + bonds(row, 3);
    bondSums(bonds(row, 2)) = bondSums(bonds(row, 2)) + bonds(row, 3);
end
for index = reshape(indices, 1, [])
    symbol = string(model(index).specie.symbol);
    if symbol == "H", continue, end
    charge = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        siteScalar(model(index), "formal_charge", 0);
    aromatic = logical(kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        siteScalar(model(index), "is_aromatic", false));
    target = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        targetValence(symbol, charge, aromatic, bondSums(index));
    count = max(round(target - bondSums(index)), 0);
    directions = placementDirections(model, bonds, index, count);
    lengthValue = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        idealBondLength(symbol, "H", 1);
    for hydrogenIndex = 1:count
        coordinate = model(index).coords + ...
            lengthValue * directions(hydrogenIndex, :);
        model = model.append("H", coordinate, properties = struct( ...
            "formal_charge", 0, "hybridization", "s", ...
            "is_aromatic", false));
        bonds(end + 1, :) = [index, model.num_sites, 1]; %#ok<AGROW>
    end
end
end

function directions = placementDirections(model, bonds, index, count)
if count == 0, directions = zeros(0, 3); return, end
tetra = [1, 1, 1; 1, -1, -1; -1, 1, -1; -1, -1, 1];
tetra = tetra ./ vecnorm(tetra, 2, 2);
neighbors = zeros(1, 0);
for row = 1:size(bonds, 1)
    if bonds(row, 1) == index, neighbors(end + 1) = bonds(row, 2); %#ok<AGROW>
    elseif bonds(row, 2) == index, neighbors(end + 1) = bonds(row, 1); %#ok<AGROW>
    end
end
if isempty(neighbors), directions = tetra(1:count, :); return, end
occupied = model.cart_coords(neighbors, :) - model(index).coords;
occupied = occupied ./ max(vecnorm(occupied, 2, 2), eps);
directions = zeros(count, 3); candidates = tetra;
for slot = 1:count
    allOccupied = [occupied; directions(1:slot - 1, :)];
    scores = zeros(size(candidates, 1), 1);
    for candidate = 1:size(candidates, 1)
        scores(candidate) = min(vecnorm( ...
            allOccupied - candidates(candidate, :), 2, 2));
    end
    [~, best] = max(scores); directions(slot, :) = candidates(best, :);
    candidates(best, :) = [];
end
end

function remove = hydrogenNeighbors(model, bonds, indices)
selected = false(1, model.num_sites); selected(indices) = true;
remove = zeros(1, 0);
for row = 1:size(bonds, 1)
    first = bonds(row, 1); second = bonds(row, 2);
    if selected(first) && string(model(second).specie.symbol) == "H"
        remove(end + 1) = second; %#ok<AGROW>
    elseif selected(second) && string(model(first).specie.symbol) == "H"
        remove(end + 1) = first; %#ok<AGROW>
    end
end
if all(arrayfun(@(index) string(model(index).specie.symbol) == "H", indices))
    remove = [remove, indices];
end
remove = unique(remove);
end
