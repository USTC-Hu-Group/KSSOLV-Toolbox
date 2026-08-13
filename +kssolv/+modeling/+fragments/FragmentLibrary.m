classdef FragmentLibrary
    %FRAGMENTLIBRARY Built-in and versioned user molecular fragments.

    properties (Constant)
        SchemaVersion = 2
    end

    methods (Static)
        function entries = list(query, options)
            arguments
                query {mustBeTextScalar} = ""
                options.includeUser (1,1) logical = true
                options.storePath {mustBeTextScalar} = ""
            end
            entries = builtInEntries();
            if options.includeUser
                user = kssolv.modeling.fragments.FragmentLibrary. ...
                    loadStore(options.storePath);
                entries = [entries; reshape(user.fragments, [], 1)];
            end
            query = lower(string(query));
            if query ~= ""
                keep = arrayfun(@(entry) contains(lower(entry.name), query) || ...
                    contains(lower(entry.description), query) || ...
                    any(contains(lower(string(entry.tags)), query)), entries);
                entries = entries(keep);
            end
        end

        function entry = get(name, options)
            arguments
                name {mustBeTextScalar}
                options.storePath {mustBeTextScalar} = ""
            end
            entries = kssolv.modeling.fragments.FragmentLibrary.list( ...
                "", storePath = options.storePath);
            which = find(strcmpi(string({entries.name}), string(name)), 1);
            if isempty(which)
                error("KSSOLV:Modeling:UnknownFragment", ...
                    "Unknown molecular fragment '%s'.", name);
            end
            entry = entries(which);
        end

        function ports = ports(name, options)
            arguments
                name {mustBeTextScalar}
                options.storePath {mustBeTextScalar} = ""
            end
            entry = kssolv.modeling.fragments.FragmentLibrary.get( ...
                name, storePath = options.storePath);
            ports = entry.ports;
        end

        function [model, metadata] = attach(model, name, hostIndex, options)
            arguments
                model kssolv.analysis.matgenlab.core.IMolecule
                name {mustBeTextScalar}
                hostIndex (1,:) double {mustBeInteger, mustBePositive}
                options.fragmentIndex (1,1) double {mustBeInteger, mustBePositive} = 1
                options.bondOrder (1,1) double = NaN
                options.bondLength (1,1) double = NaN
                options.portId {mustBeTextScalar} = ""
                options.storePath {mustBeTextScalar} = ""
            end
            hostIndex = reshape(double(hostIndex), 1, []);
            if any(hostIndex > model.num_sites)
                error("KSSOLV:Modeling:FragmentHost", ...
                    "Fragment host atom is outside the molecule.");
            end
            entry = kssolv.modeling.fragments.FragmentLibrary.get( ...
                name, storePath = options.storePath);
            port = selectPort(entry, options.portId, ...
                options.fragmentIndex);
            if isempty(port.headIndices)
                error("KSSOLV:Modeling:FragmentNoncovalentPort", ...
                    ["The '%s' port is noncovalent. Use the adsorbate " ...
                    "placement workflow instead of creating a bond."], ...
                    port.id);
            end
            if numel(hostIndex) ~= numel(port.headIndices)
                error("KSSOLV:Modeling:FragmentPortArity", ...
                    "Port '%s' requires %d host atoms.", ...
                    port.id, numel(port.headIndices));
            end
            connectionBondOrders = reshape( ...
                double(port.defaultBondOrders), 1, []);
            if ~isnan(options.bondOrder)
                connectionBondOrders = repmat( ...
                    options.bondOrder, 1, numel(hostIndex));
            end
            validateHostValence(model, hostIndex, connectionBondOrders);
            if any(port.headIndices > numel(entry.species))
                error("KSSOLV:Modeling:FragmentHead", ...
                    "Fragment connection head is outside the fragment.");
            end
            retained = setdiff(1:numel(entry.species), ...
                port.leavingAtomIndices, "stable");
            if ~all(ismember(port.headIndices, retained))
                error("KSSOLV:Modeling:FragmentLeavingHead", ...
                    "A fragment connection head cannot also be a leaving atom.");
            end
            oldToNew = zeros(1, numel(entry.species));
            oldToNew(retained) = 1:numel(retained);
            headIndices = oldToNew(port.headIndices);
            directions = zeros(numel(hostIndex), 3);
            for host = 1:numel(hostIndex)
                directions(host, :) = attachmentDirection( ...
                    model, hostIndex(host));
            end
            lengthValue = options.bondLength;
            geometryParameter = repmat(struct.empty, 1, 0);
            if isnan(lengthValue)
                geometryParameter = kssolv.modeling.chemistry. ...
                    MoleculeDiagnostics.idealBondParameter( ...
                        model(hostIndex(1)).specie.symbol, ...
                        entry.species(port.headIndices(1)), ...
                    connectionBondOrders(1));
                geometryParameter = repmat( ...
                    geometryParameter, 1, numel(hostIndex));
                for host = 2:numel(hostIndex)
                    geometryParameter(host) = kssolv.modeling.chemistry. ...
                        MoleculeDiagnostics.idealBondParameter( ...
                            model(hostIndex(host)).specie.symbol, ...
                            entry.species(port.headIndices(host)), ...
                        connectionBondOrders(host));
                end
                lengthValue = mean([geometryParameter.value]);
            end
            targets = model.cart_coords(hostIndex, :) + ...
                lengthValue .* directions;
            coordinates = placeAtPort(double(entry.coordinates), ...
                port.headIndices, targets, directions(1, :));
            coordinates = coordinates(retained, :);
            firstNew = model.num_sites + 1;
            for retainedIndex = 1:numel(retained)
                index = retained(retainedIndex);
                properties = struct("formal_charge", ...
                    entry.formalCharges(index), ...
                    "hybridization", entry.hybridization(index), ...
                    "is_aromatic", entry.aromatic(index));
                model = model.append(entry.species(index), ...
                    coordinates(retainedIndex, :), properties = properties);
            end
            % Use the original explicit host table and add only declared bonds.
            hostCount = firstNew - 1;
            hostProperties = model.properties;
            if isfield(hostProperties, "topology") && ...
                    isfield(hostProperties.topology, "bonds")
                bonds = double(hostProperties.topology.bonds);
                bonds = bonds(all(bonds(:, 1:2) <= hostCount, 2), :);
            else
                bonds = zeros(0, 3);
            end
            internal = double(entry.bonds);
            for override = 1:size(port.bondOverrides, 1)
                pair = sort(port.bondOverrides(override, 1:2));
                row = find(all(sort(internal(:, 1:2), 2) == pair, 2), 1);
                if isempty(row)
                    error("KSSOLV:Modeling:FragmentPortBond", ...
                        "Port '%s' overrides an undeclared fragment bond.", ...
                        port.id);
                end
                internal(row, 3) = port.bondOverrides(override, 3);
            end
            keepBonds = all(ismember(internal(:, 1:2), retained), 2);
            internal = internal(keepBonds, :);
            internal(:, 1) = oldToNew(internal(:, 1));
            internal(:, 2) = oldToNew(internal(:, 2));
            internal(:, 1:2) = internal(:, 1:2) + firstNew - 1;
            connections = [hostIndex(:), ...
                firstNew + headIndices(:) - 1, ...
                connectionBondOrders(:)];
            bonds = [bonds; internal; connections];
            model = kssolv.modeling.chemistry. ...
                MoleculeChemistryCommands.withTopology(model, bonds);
            validateAttachedGeometry(model, hostIndex, firstNew);
            metadata = struct("name", string(entry.name), ...
                "hostIndex", hostIndex, ...
                "fragmentIndices", firstNew:model.num_sites, ...
                "connectionHead", firstNew + headIndices - 1, ...
                "portId", string(port.id), ...
                "portMode", string(port.mode), ...
                "leavingAtomIndices", port.leavingAtomIndices, ...
                "schemaVersion", entry.schemaVersion, ...
                "geometryParameter", geometryParameter);
        end

        function saveUser(name, molecule, options)
            arguments
                name {mustBeTextScalar}
                molecule kssolv.analysis.matgenlab.core.IMolecule
                options.description {mustBeTextScalar} = "User fragment"
                options.tags = strings(1, 0)
                options.ports = struct.empty
                options.storePath {mustBeTextScalar} = ""
                options.overwrite (1,1) logical = false
            end
            store = kssolv.modeling.fragments.FragmentLibrary. ...
                loadStore(options.storePath);
            names = string({store.fragments.name});
            existing = find(strcmpi(names, string(name)), 1);
            if ~isempty(existing) && ~options.overwrite
                error("KSSOLV:Modeling:FragmentExists", ...
                    "User fragment '%s' already exists.", name);
            end
            entry = entryFromMolecule(name, molecule, ...
                options.description, options.tags, "user");
            if ~isempty(options.ports)
                entry.ports = normalizePorts(options.ports, ...
                    molecule.num_sites);
            end
            if isempty(existing), store.fragments(end + 1) = entry;
            else, store.fragments(existing) = entry;
            end
            kssolv.modeling.fragments.FragmentLibrary. ...
                writeStore(store, options.storePath);
        end

        function store = loadStore(path)
            path = resolveStorePath(path);
            store = emptyStore();
            if ~isfile(path), return, end
            try
                decoded = jsondecode(fileread(path));
            catch exception
                error("KSSOLV:Modeling:FragmentStoreRead", ...
                    "Cannot read fragment store '%s': %s", path, ...
                    exception.message);
            end
            if ~isfield(decoded, "schemaVersion") || ...
                    decoded.schemaVersion > ...
                    kssolv.modeling.fragments.FragmentLibrary.SchemaVersion
                error("KSSOLV:Modeling:FragmentSchema", ...
                    "Fragment store schema is newer than this KSSOLV build.");
            end
            if isfield(decoded, "fragments") && ~isempty(decoded.fragments)
                fragments = decoded.fragments;
                if iscell(fragments), fragments = [fragments{:}]; end
                store.fragments = arrayfun(@normalizeEntry, fragments);
            end
        end

        function writeStore(store, path)
            path = resolveStorePath(path);
            store.schemaVersion = ...
                kssolv.modeling.fragments.FragmentLibrary.SchemaVersion;
            store.updatedAt = string(datetime("now", ...
                "TimeZone", "UTC", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'"));
            kssolv.modeling.internal.AtomicJsonFile.write(path,store, ...
                "KSSOLV:Modeling:FragmentStoreWrite");
        end

        function exportStore(destination, options)
            arguments
                destination {mustBeTextScalar}
                options.storePath {mustBeTextScalar} = ""
            end
            store = kssolv.modeling.fragments.FragmentLibrary. ...
                loadStore(options.storePath);
            kssolv.modeling.fragments.FragmentLibrary. ...
                writeStore(store, destination);
        end

        function importStore(source, options)
            arguments
                source {mustBeTextScalar}
                options.storePath {mustBeTextScalar} = ""
                options.overwrite (1,1) logical = false
            end
            incoming = kssolv.modeling.fragments.FragmentLibrary. ...
                loadStore(source);
            current = kssolv.modeling.fragments.FragmentLibrary. ...
                loadStore(options.storePath);
            for entry = reshape(incoming.fragments, 1, [])
                names = string({current.fragments.name});
                which = find(strcmpi(names, string(entry.name)), 1);
                if isempty(which), current.fragments(end + 1) = entry;
                elseif options.overwrite, current.fragments(which) = entry;
                end
            end
            kssolv.modeling.fragments.FragmentLibrary. ...
                writeStore(current, options.storePath);
        end
    end
end

function entries = builtInEntries()
entries = [
    makeEntry("Methyl", "CH3 methyl group", ["CH3", "alkyl", "carbon"], ...
        ["C", "H", "H", "H"], ...
        [0,0,0; 0.63,0.63,0.63; 0.63,-0.63,-0.63; -0.63,0.63,-0.63], ...
        [1,2,1; 1,3,1; 1,4,1], [0,0,0,0], ...
        ["sp3","s","s","s"], false(1,4))
    makeEntry("O-H fragment", "O-H bonded fragment", ["OH", "oxygen", "polar"], ...
        ["O", "H"], [0,0,0; 0.96,0,0], [1,2,1], [0,0], ...
        ["sp3","s"], false(1,2))
    makeEntry("Amino", "NH2 primary amino group", ["NH2", "nitrogen", "amine"], ...
        ["N", "H", "H"], [0,0,0; 0.47,0.81,0; 0.47,-0.81,0], ...
        [1,2,1; 1,3,1], [0,0,0], ["sp3","s","s"], false(1,3))
    makeEntry("Carbonyl", "Carbonyl group", ["carbon", "oxygen"], ...
        ["C", "O"], [0,0,0; 1.23,0,0], [1,2,2], [0,0], ...
        ["sp2","sp2"], false(1,2))
    makeEntry("Carboxyl", "COOH carboxyl group", ["COOH", "acid", "oxygen"], ...
        ["C", "O", "O", "H"], ...
        [0,0,0; 1.23,0,0; -0.65,1.12,0; -1.60,1.12,0], ...
        [1,2,2; 1,3,1; 3,4,1], [0,0,0,0], ...
        ["sp2","sp2","sp2","s"], false(1,4))
    makeEntry("Phenyl", "Phenyl ring", ["aromatic", "ring"], ...
        ["C","C","C","C","C","C","H","H","H","H","H"], ...
        phenylCoordinates(), ...
        [1,2,1.5;2,3,1.5;3,4,1.5;4,5,1.5;5,6,1.5;6,1,1.5; ...
         2,7,1;3,8,1;4,9,1;5,10,1;6,11,1], zeros(1,11), ...
        [repmat("sp2",1,6),repmat("s",1,5)], ...
        [true(1,6),false(1,5)])
    ];
entries(end + 1) = makeEntry("Oxygen", "Atomic O fragment", ...
    ["O", "atom", "oxygen"], "O", [0,0,0], zeros(0,3), 0, ...
    "sp3", false);
entries(end + 1) = makeEntry("Hydrogen", "Atomic H fragment", ...
    ["H", "atom", "hydrogen"], "H", [0,0,0], zeros(0,3), 0, ...
    "s", false);
entries(end + 1) = makeEntry("Imino", "NH imino group", ...
    ["NH", "nitrogen"], ["N","H"], [0,0,0;.96,0,0], ...
    [1,2,1], [0,0], ["sp2","s"], false(1,2));
entries(end + 1) = makeEntry("Cyano", "CN cyano group", ...
    ["CN", "nitrile"], ["C","N"], [0,0,0;1.16,0,0], ...
    [1,2,3], [0,0], ["sp","sp"], false(1,2));
entries(end + 1) = makeEntry("Nitro", "NO2 nitro group", ...
    ["NO2", "nitrogen", "oxygen"], ["N","O","O"], ...
    [0,0,0;1.22,0,0;-0.61,1.06,0], [1,2,1.5;1,3,1.5], ...
    [1,-.5,-.5], ["sp2","sp2","sp2"], false(1,3));
entries(end + 1) = makeEntry("Thiol", "SH thiol group", ...
    ["SH", "sulfur"], ["S","H"], [0,0,0;1.34,0,0], ...
    [1,2,1], [0,0], ["sp3","s"], false(1,2));
entries(end + 1) = makeEntry("Carboxylate", "COO carboxylate group", ...
    ["COO", "carboxylate", "bidentate"], ["C","O","O"], ...
    [0,0,0;1.25,0,0;-.625,1.083,0], ...
    [1,2,1.5;1,3,1.5], [1,-1,-1], ...
    ["sp2","sp2","sp2"], false(1,3));

entries(2).ports = makePort("oxygen", "O connection", 1, [], 1, ...
    [-1,0,0], "covalent");
entries(5).ports = [
    makePort("carbon", "Surface-C", 1, [], 1, [-1,0,0], "covalent")
    makePort("oxygen-single", "Monodentate O", 3, 4, 1, ...
        [0,-1,0], "monodentate")
    makePort("oxygen-bidentate", "Bidentate O,O", [2,3], 4, [.5,.5], ...
        [0,0,-1], "bidentate")
    makePort("noncovalent", "Noncovalent molecule", [], [], [], ...
        [0,0,1], "noncovalent")
    ];
entries(5).ports(3).bondOverrides = [1,2,1.5;1,3,1.5];
entries(end).ports = [
    makePort("carbon", "Surface-C", 1, [], 1, [-1,0,0], "covalent")
    makePort("oxygen-single", "Monodentate O", 2, [], 1, ...
        [1,0,0], "monodentate")
    makePort("oxygen-bidentate", "Bidentate O,O", [2,3], [], [.5,.5], ...
        [0,0,-1], "bidentate")
    makePort("noncovalent", "Noncovalent molecule", [], [], [], ...
        [0,0,1], "noncovalent")
    ];
end

function entry = makeEntry(name, description, tags, species, coordinates, ...
        bonds, charges, hybridization, aromatic)
ports = makePort("head", "Primary connection", 1, [], 1, ...
    [-1,0,0], "covalent");
if isempty(species)
    ports = repmat(ports, 0, 1);
end
entry = struct("name", string(name), "description", string(description), ...
    "tags", reshape(string(tags), 1, []), "species", ...
    reshape(string(species), 1, []), "coordinates", ...
    reshape(double(coordinates), [], 3), ...
    "bonds", reshape(double(bonds), [], 3), ...
    "formalCharges", reshape(double(charges), 1, []), ...
    "hybridization", reshape(string(hybridization), 1, []), ...
    "aromatic", reshape(logical(aromatic), 1, []), ...
    "ports", ports, "schemaVersion", 2, "source", "builtin");
end

function port = makePort(id, label, headIndices, leavingAtomIndices, ...
        defaultBondOrders, orientation, mode)
port = struct("id", string(id), "label", string(label), ...
    "headIndices", reshape(double(headIndices), 1, []), ...
    "leavingAtomIndices", reshape(double(leavingAtomIndices), 1, []), ...
    "defaultBondOrders", reshape(double(defaultBondOrders), 1, []), ...
    "orientation", reshape(double(orientation), 1, 3), ...
    "maxConnections", numel(headIndices), "mode", string(mode), ...
    "bondOverrides", zeros(0, 3));
end

function port = selectPort(entry, portId, fragmentIndex)
portId = string(portId);
if portId ~= ""
    which = find(strcmpi(string({entry.ports.id}), portId), 1);
    if isempty(which)
        error("KSSOLV:Modeling:UnknownFragmentPort", ...
            "Fragment '%s' has no port named '%s'.", entry.name, portId);
    end
    port = entry.ports(which);
    return
end
which = find(arrayfun(@(candidate) ...
    isequal(candidate.headIndices, fragmentIndex), entry.ports), 1);
if isempty(which)
    port = makePort("legacy-head-" + string(fragmentIndex), ...
        "Legacy connection head", fragmentIndex, [], 1, ...
        [-1,0,0], "covalent");
else
    port = entry.ports(which);
end
end

function coordinates = phenylCoordinates()
angles = (0:5).' * pi / 3; ring = 1.40 * [cos(angles), sin(angles), zeros(6,1)];
hydrogen = 2.48 * [cos(angles(2:end)), sin(angles(2:end)), zeros(5,1)];
coordinates = [ring; hydrogen];
end

function entry = entryFromMolecule(name, molecule, description, tags, source)
bonds = kssolv.modeling.chemistry.MoleculeDiagnostics.topology(molecule);
charges = zeros(1, molecule.num_sites); aromatic = false(1, molecule.num_sites);
hybridization = repmat("auto", 1, molecule.num_sites);
species = strings(1, molecule.num_sites);
for index = 1:molecule.num_sites
    species(index) = molecule(index).specie.symbol;
    charges(index) = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        siteScalar(molecule(index), "formal_charge", 0);
    aromatic(index) = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        siteScalar(molecule(index), "is_aromatic", false);
    hybridization(index) = string(kssolv.modeling.chemistry. ...
        MoleculeDiagnostics.siteScalar( ...
        molecule(index), "hybridization", "auto"));
end
entry = makeEntry(name, description, tags, species, ...
    molecule.cart_coords, bonds, charges, hybridization, aromatic);
entry.source = string(source);
end

function entry = normalizeEntry(entry)
original = entry;
entry = makeEntry(original.name, original.description, original.tags, ...
    original.species, original.coordinates, original.bonds, ...
    original.formalCharges, original.hybridization, original.aromatic);
if isfield(original, "ports") && ~isempty(original.ports)
    entry.ports = normalizePorts(original.ports, numel(entry.species));
end
entry.source = "user";
end

function normalized = normalizePorts(ports, atomCount)
if iscell(ports), ports = [ports{:}]; end
prototype = makePort("", "", 1, [], 1, [0,0,1], "covalent");
normalized = repmat(prototype, numel(ports), 1);
ids = strings(1, numel(ports));
for index = 1:numel(ports)
    candidate = ports(index);
    required = ["id","label","headIndices","leavingAtomIndices", ...
        "defaultBondOrders","orientation","mode"];
    if ~all(isfield(candidate, required))
        error("KSSOLV:Modeling:FragmentPortSchema", ...
            "Fragment ports must define %s.", join(required, ", "));
    end
    normalized(index) = makePort(candidate.id, candidate.label, ...
        candidate.headIndices, candidate.leavingAtomIndices, ...
        candidate.defaultBondOrders, candidate.orientation, ...
        candidate.mode);
    if isfield(candidate, "bondOverrides")
        normalized(index).bondOverrides = reshape( ...
            double(candidate.bondOverrides), [], 3);
    end
    indices = [normalized(index).headIndices, ...
        normalized(index).leavingAtomIndices, ...
        reshape(normalized(index).bondOverrides(:,1:2), 1, [])];
    if any(indices < 1) || any(indices > atomCount) || ...
            any(mod(indices, 1) ~= 0)
        error("KSSOLV:Modeling:FragmentPortIndex", ...
            "Fragment port '%s' contains an invalid atom index.", ...
            normalized(index).id);
    end
    if numel(normalized(index).defaultBondOrders) ~= ...
            numel(normalized(index).headIndices)
        error("KSSOLV:Modeling:FragmentPortBondOrder", ...
            "Fragment port '%s' must define one bond order per head.", ...
            normalized(index).id);
    end
    ids(index) = lower(normalized(index).id);
end
if any(ids == "") || numel(unique(ids)) ~= numel(ids)
    error("KSSOLV:Modeling:FragmentPortId", ...
        "Fragment port identifiers must be nonempty and unique.");
end
end

function validateHostValence(model, hostIndices, bondOrders)
bonds = kssolv.modeling.chemistry.MoleculeDiagnostics.topology(model);
bondSums = zeros(model.num_sites, 1);
for row = 1:size(bonds, 1)
    bondSums(bonds(row, 1)) = bondSums(bonds(row, 1)) + bonds(row, 3);
    bondSums(bonds(row, 2)) = bondSums(bonds(row, 2)) + bonds(row, 3);
end
for hostPosition = 1:numel(hostIndices)
    hostIndex = hostIndices(hostPosition);
    bondOrder = bondOrders(hostPosition);
    symbol = string(model(hostIndex).specie.symbol);
    charge = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        siteScalar(model(hostIndex), "formal_charge", 0);
    aromatic = logical(kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        siteScalar(model(hostIndex), "is_aromatic", false));
    target = kssolv.modeling.chemistry.MoleculeDiagnostics. ...
        targetValence(symbol, charge, aromatic, bondSums(hostIndex));
    if target > 0 && bondSums(hostIndex) + bondOrder > target + 1e-8
        error("KSSOLV:Modeling:FragmentHostValence", ...
            "Cannot attach a bond of order %.3g to %s%d: its current " + ...
            "bond-order sum is %.3g and its target valence is %.3g.", ...
            bondOrder, symbol, hostIndex, bondSums(hostIndex), target);
    end
end
end

function validateAttachedGeometry(model, hostIndices, firstNewIndex)
report = kssolv.modeling.chemistry.MoleculeDiagnostics.inspect(model);
newIndices = firstNewIndex:model.num_sites;
affectedIndices = unique([reshape(hostIndices, 1, []), newIndices]);
issues = report.atomIssues;
if ~isempty(issues)
    severities = string({issues.severity});
    sites = double([issues.siteIndex]);
    illegal = find(severities == "error" & ...
        ismember(sites, affectedIndices), 1);
    if ~isempty(illegal)
        error("KSSOLV:Modeling:FragmentValence", ...
            "Fragment attachment would create illegal valence: %s", ...
            issues(illegal).message);
    end
end
collisions = report.collisions;
if ~isempty(collisions)
    collision = find(any(collisions(:, 1:2) >= firstNewIndex, 2), 1);
    if ~isempty(collision)
        pair = collisions(collision, :);
        error("KSSOLV:Modeling:FragmentCollision", ...
            "Fragment attachment would place atoms %d and %d only " + ...
            "%.3g angstrom apart.", pair(1), pair(2), pair(3));
    end
end
end

function direction = attachmentDirection(model, index)
bonds = kssolv.modeling.chemistry.MoleculeDiagnostics.topology(model);
neighbors = zeros(1, 0);
for row = 1:size(bonds, 1)
    if bonds(row, 1) == index, neighbors(end + 1) = bonds(row, 2); %#ok<AGROW>
    elseif bonds(row, 2) == index, neighbors(end + 1) = bonds(row, 1); %#ok<AGROW>
    end
end
if isempty(neighbors), direction = [1, 0, 0]; return, end
vectors = model.cart_coords(neighbors, :) - model(index).coords;
vectors = vectors ./ max(vecnorm(vectors, 2, 2), eps);
direction = -sum(vectors, 1);
if norm(direction) <= 1e-8, direction = nullDirection(vectors); end
direction = direction / norm(direction);
end

function direction = nullDirection(vectors)
if size(vectors, 1) == 1
    direction = cross(vectors(1, :), [0, 0, 1]);
    if norm(direction) <= eps, direction = [0, 1, 0]; end
else
    direction = cross(vectors(1, :), vectors(2, :));
    if norm(direction) <= eps, direction = [0, 0, 1]; end
end
end

function coordinates = orientFragment(coordinates, head, direction)
coordinates = coordinates - coordinates(head, :);
other = find(vecnorm(coordinates, 2, 2) > 1e-8, 1);
if isempty(other), return, end
source = coordinates(other, :); source = source / norm(source);
target = direction / norm(direction); axis = cross(source, target);
if norm(axis) <= 1e-12
    if dot(source, target) > 0, return, end
    axis = cross(source, [1,0,0]);
    if norm(axis) <= eps, axis = cross(source, [0,1,0]); end
    angle = pi;
else
    axis = axis / norm(axis); angle = acos(max(-1,min(1,dot(source,target))));
end
skew = [0,-axis(3),axis(2);axis(3),0,-axis(1);-axis(2),axis(1),0];
rotation = eye(3) + sin(angle)*skew + (1-cos(angle))*(skew*skew);
coordinates = coordinates * rotation.';
end

function coordinates = placeAtPort(coordinates, heads, targets, direction)
if isscalar(heads)
    coordinates = orientFragment(coordinates, heads, direction);
    coordinates = coordinates - coordinates(heads, :) + targets;
    return
end
source = coordinates(heads(2), :) - coordinates(heads(1), :);
target = targets(2, :) - targets(1, :);
rotation = rotationBetween(source, target);
sourceCenter = mean(coordinates(heads, :), 1);
targetCenter = mean(targets, 1);
coordinates = (coordinates - sourceCenter) * rotation.' + targetCenter;
end

function rotation = rotationBetween(source, target)
source = source / norm(source);
target = target / norm(target);
axis = cross(source, target);
sine = norm(axis);
cosine = max(-1, min(1, dot(source, target)));
if sine <= 1e-12
    if cosine > 0
        rotation = eye(3);
        return
    end
    axis = null(source).';
    axis = axis(1, :);
    sine = 0;
else
    axis = axis / sine;
end
skew = [0,-axis(3),axis(2);axis(3),0,-axis(1); ...
    -axis(2),axis(1),0];
rotation = eye(3) + skew * sine + skew^2 * (1 - cosine);
end

function store = emptyStore()
prototype = makeEntry("", "", strings(1,0), strings(1,0), zeros(0,3), ...
    zeros(0,3), zeros(1,0), strings(1,0), false(1,0));
store = struct("schemaVersion", ...
    kssolv.modeling.fragments.FragmentLibrary.SchemaVersion, ...
    "updatedAt", "", ...
    "fragments", repmat(prototype, 0, 1));
end

function path = resolveStorePath(path)
path = string(path);
if path == ""
    path = fullfile(prefdir, "KSSOLV", "modeling", ...
        "molecular-fragments-v1.json");
end
path = char(path);
end
