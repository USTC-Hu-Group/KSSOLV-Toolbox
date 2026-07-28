function modified = add_atoms(molecule, organized, options)
%ADD_ATOMS Link bond/ring/cage critical points to nearby lower-rank CPs.
arguments
    molecule
    organized (1,1) struct
    options.bond_atom_criterion string = "combined"
    options.dist_threshold_bond (1,1) double = 1.0
    options.dist_threshold_ring_cage (1,1) double = 3.0
    options.distance_margin (1,1) double = 0.5
end
criterion = lower(options.bond_atom_criterion);
if ~any(criterion == ["qtaim", "distance", "combined"])
    error("KSSOLV:Matgenlab:Multiwfn:Criterion", ...
        "bond_atom_criterion must be qtaim, distance, or combined.");
end
modified = cloneOrganized(organized);
atomInfo = containers.Map( ...
    "KeyType", "double", "ValueType", "any");
for index = 1:molecule.num_sites
    atomInfo(index) = struct("pos_ang", molecule(index).coords);
end
if criterion == "qtaim"
    filtered = containers.Map( ...
        "KeyType", "char", "ValueType", "any");
    keys = modified.bond.keys;
    for index = 1:numel(keys)
        value = modified.bond(keys{index});
        if isfield(value, "connected_bond_paths")
            filtered(keys{index}) = value;
        end
    end
    modified.bond = filtered;
end
if modified.bond.Count > 0 && atomInfo.Count < 2
    error("KSSOLV:Matgenlab:Multiwfn:BondAtoms", ...
        "Cannot have a bond CP with less than two atom CPs.");
end
if modified.ring.Count > 0 && modified.bond.Count < 3
    error("KSSOLV:Matgenlab:Multiwfn:RingBonds", ...
        "Cannot have a ring CP with less than three bond CPs.");
end
if modified.cage.Count > 0 && modified.ring.Count < 3
    error("KSSOLV:Matgenlab:Multiwfn:CageRings", ...
        "Cannot have a cage CP with less than three ring CPs.");
end

bondKeys = modified.bond.keys;
for index = 1:numel(bondKeys)
    key = bondKeys{index};
    descriptor = modified.bond(key);
    useQtaim = criterion == "qtaim" || ...
        (criterion == "combined" && ...
        isfield(descriptor, "connected_bond_paths"));
    if useQtaim
        atomIndices = indicesFromPaths( ...
            descriptor.connected_bond_paths, modified.atom);
        if criterion == "combined" && numel(atomIndices) ~= 2
            error("KSSOLV:Matgenlab:Multiwfn:ConnectedPaths", ...
                "Could not match all atoms for bond CP %s.", key);
        end
    else
        [distances, names] = sortedByDistance( ...
            descriptor.pos_ang, atomInfo);
        if distances(2) > options.dist_threshold_bond
            warning("KSSOLV:Matgenlab:Multiwfn:DistantBond", ...
                "Bond CP is far from bonding atoms.");
        end
        atomIndices = sort(cell2mat(names(1:2)));
    end
    descriptor.atom_inds = sort(atomIndices);
    modified.bond(key) = descriptor;
end

ringKeys = modified.ring.keys;
for index = 1:numel(ringKeys)
    key = ringKeys{index};
    descriptor = modified.ring(key);
    [distances, names] = sortedByDistance( ...
        descriptor.pos_ang, modified.bond);
    cutoff = distances(3);
    if cutoff > options.dist_threshold_ring_cage
        warning("KSSOLV:Matgenlab:Multiwfn:DistantRing", ...
            "Ring CP is far from closest bond CPs.");
    end
    selected = names(1:3);
    for extra = 4:numel(names)
        if distances(extra) < cutoff + options.distance_margin
            selected{end + 1} = names{extra}; %#ok<AGROW>
        else
            break
        end
    end
    atomIndices = zeros(1, 0);
    for bondIndex = 1:numel(selected)
        bond = modified.bond(selected{bondIndex});
        atomIndices = union(atomIndices, bond.atom_inds);
    end
    descriptor.bond_names = string(selected);
    descriptor.atom_inds = atomIndices;
    modified.ring(key) = descriptor;
end

cageKeys = modified.cage.keys;
for index = 1:numel(cageKeys)
    key = cageKeys{index};
    descriptor = modified.cage(key);
    [distances, names] = sortedByDistance( ...
        descriptor.pos_ang, modified.ring);
    cutoff = distances(3);
    if cutoff > options.dist_threshold_ring_cage
        warning("KSSOLV:Matgenlab:Multiwfn:DistantCage", ...
            "Cage CP is far from closest ring CPs.");
    end
    selected = names(1:3);
    for extra = 4:numel(names)
        if distances(extra) < cutoff + options.distance_margin
            selected{end + 1} = names{extra}; %#ok<AGROW>
        else
            break
        end
    end
    bondNames = strings(1, 0);
    atomIndices = zeros(1, 0);
    for ringIndex = 1:numel(selected)
        ring = modified.ring(selected{ringIndex});
        bondNames = union(bondNames, string(ring.bond_names));
        atomIndices = union(atomIndices, ring.atom_inds);
    end
    descriptor.ring_names = string(selected);
    descriptor.bond_names = bondNames;
    descriptor.atom_inds = atomIndices;
    modified.cage(key) = descriptor;
end
end

function value = cloneOrganized(source)
names = ["atom", "bond", "ring", "cage"];
value = struct();
for name = names
    sourceMap = source.(name);
    if strcmp(sourceMap.KeyType, "double")
        target = containers.Map( ...
            "KeyType", "double", "ValueType", "any");
    else
        target = containers.Map( ...
            "KeyType", "char", "ValueType", "any");
    end
    keys = sourceMap.keys;
    for index = 1:numel(keys)
        target(keys{index}) = sourceMap(keys{index});
    end
    value.(name) = target;
end
end

function [distances, names] = sortedByDistance(position, options)
keys = options.keys;
distances = zeros(1, numel(keys));
for index = 1:numel(keys)
    descriptor = options(keys{index});
    distances(index) = norm( ...
        double(position) - double(descriptor.pos_ang));
end
[distances, order] = sort(distances);
names = keys(order);
end

function indices = indicesFromPaths(paths, atomMap)
indices = zeros(1, 0);
keys = atomMap.keys;
for path = reshape(paths, 1, [])
    for index = 1:numel(keys)
        descriptor = atomMap(keys{index});
        if ~isfield(descriptor, "name"), continue; end
        number = str2double(extractBefore( ...
            string(descriptor.name), "_"));
        if number == path
            indices(end + 1) = keys{index}; %#ok<AGROW>
            break
        end
    end
end
end
