function [species, coordinates, properties, labels] = ...
        prepare_functional_group(collection, index, functionalGroup, bondOrder)
%PREPARE_FUNCTIONAL_GROUP Align a substituent to a selected atom.
if nargin < 4, bondOrder = 1; end
if ~isscalar(index) || index ~= fix(index) || ...
        index < 1 || index > collection.num_sites
    error("KSSOLV:Matgenlab:Structure:Index", ...
        "Substitution index must identify an existing site.");
end
if ischar(functionalGroup) || isstring(functionalGroup)
    databasePath = fullfile(fileparts(mfilename("fullpath")), ...
        "+data", "func_groups.json");
    database = jsondecode(fileread(databasePath));
    name = char(lower(string(functionalGroup)));
    if ~isfield(database, name)
        error("KSSOLV:Matgenlab:Structure:UnknownFunctionalGroup", ...
            "Cannot find functional group '%s'; provide an explicit " + ...
            "Molecule instead.", name);
    end
    record = database.(name);
    functionalGroup = kssolv.analysis.matgenlab.core.Molecule( ...
        cellstr(string(record.species)), double(record.coords));
end
if ~isa(functionalGroup, ...
        "kssolv.analysis.matgenlab.core.IMolecule") || ...
        functionalGroup.num_sites < 2
    error("KSSOLV:Matgenlab:Structure:FunctionalGroup", ...
        "A functional group must be an IMolecule with X followed by an atom.");
end
if functionalGroup.sites{1}.specie.symbol ~= "X"
    error("KSSOLV:Matgenlab:Structure:FunctionalGroupAnchor", ...
        "The first functional-group site must be the dummy species X.");
end

target = collection.sites{index};
neighbors = collection.get_neighbors(target, 3);
candidates = cell(1, 0);
for neighborIndex = 1:numel(neighbors)
    neighbor = neighbors{neighborIndex};
    innerNeighbors = collection.get_neighbors(neighbor, 3);
    nonTerminal = false;
    for innerIndex = 1:numel(innerNeighbors)
        inner = innerNeighbors{innerIndex};
        if inner.index == index, continue; end
        try
            maximumDistance = 1.2 * ...
                kssolv.analysis.matgenlab.core.get_bond_length( ...
                neighbor.specie, inner.specie);
            nonTerminal = inner.nn_distance < maximumDistance;
        catch exception
            if startsWith(exception.identifier, ...
                    "KSSOLV:Matgenlab:Bonds:")
                nonTerminal = false;
            else
                rethrow(exception)
            end
        end
        if nonTerminal, break; end
    end
    if nonTerminal
        candidates{end + 1} = neighbor; %#ok<AGROW>
    end
end
if isempty(candidates)
    error("KSSOLV:Matgenlab:Structure:TerminalSubstitution", ...
        "Cannot find a non-terminal neighbor for functional-group attachment.");
end
distances = cellfun(@(neighbor) neighbor.nn_distance, candidates);
[~, closest] = min(distances);
origin = candidates{closest}.coords;
bondLength = kssolv.analysis.matgenlab.core.get_bond_length( ...
    candidates{closest}.specie, functionalGroup.sites{2}.specie, bondOrder);

groupCoordinates = functionalGroup.cart_coords;
anchorVector = groupCoordinates(1, :) - groupCoordinates(2, :);
if norm(anchorVector) <= eps
    error("KSSOLV:Matgenlab:Structure:FunctionalGroupAnchor", ...
        "The X-to-attached-atom vector must be nonzero.");
end
groupCoordinates(1, :) = groupCoordinates(2, :) + ...
    bondLength * anchorVector / norm(anchorVector);
groupCoordinates = groupCoordinates + origin - groupCoordinates(1, :);
sourceVector = groupCoordinates(2, :) - origin;
targetVector = target.coords - origin;
rotation = rotationBetween(sourceVector, targetVector);
groupCoordinates = (groupCoordinates - origin) * rotation.' + origin;

species = functionalGroup.species_and_occu(2:end);
coordinates = groupCoordinates(2:end, :);
properties = cell(1, functionalGroup.num_sites - 1);
labels = cell(1, functionalGroup.num_sites - 1);
for siteIndex = 2:functionalGroup.num_sites
    properties{siteIndex - 1} = ...
        functionalGroup.sites{siteIndex}.site_properties;
    labels{siteIndex - 1} = functionalGroup.sites{siteIndex}.label;
end
end

function rotation = rotationBetween(source, target)
source = reshape(double(source), 1, 3);
target = reshape(double(target), 1, 3);
if norm(source) <= eps || norm(target) <= eps
    error("KSSOLV:Matgenlab:Structure:FunctionalGroupDirection", ...
        "Attachment vectors must be nonzero.");
end
source = source / norm(source);
target = target / norm(target);
crossVector = cross(source, target);
sine = norm(crossVector);
cosine = max(-1, min(1, dot(source, target)));
if sine <= 1e-12
    if cosine > 0
        rotation = eye(3);
        return
    end
    [~, smallest] = min(abs(source));
    basis = zeros(1, 3);
    basis(smallest) = 1;
    axis = cross(source, basis);
    axis = axis / norm(axis);
    rotation = 2 * (axis.' * axis) - eye(3);
    return
end
axis = crossVector / sine;
skew = [0, -axis(3), axis(2); ...
    axis(3), 0, -axis(1); ...
    -axis(2), axis(1), 0];
angle = atan2(sine, cosine);
rotation = eye(3) + sin(angle) * skew + ...
    (1 - cos(angle)) * (skew * skew);
end
