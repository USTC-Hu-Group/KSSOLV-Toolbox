classdef BondDissociationEnergies < handle
    %BONDDISSOCIATIONENERGIES Bond-breaking analysis for molecular entries.
    %#ok<*AGROW>
    %
    % This is a native MATLAB implementation of
    % pymatgen.analysis.bond_dissociation.BondDissociationEnergies. Molecular
    % connectivity is perceived by OpenBabelNN's native MATLAB equivalent;
    % no Python or Open Babel process is used at run time.

    properties
        molecule_entry (1,1) struct = struct()
        fragment_entries cell = {}
        filtered_entries cell = {}
        bond_dissociation_energies cell = {}
        done_frag_pairs cell = {}
        done_RO_frags cell = {}
        ring_bonds double = zeros(0,2)
        expected_charges double = []
        mol_graph = []
        bond_pairs cell = {}
        allow_additional_charge_separation (1,1) logical = false
        multibreak (1,1) logical = false
    end

    methods
        function obj = BondDissociationEnergies( ...
                moleculeEntry, fragmentEntries, varargin)
            if nargin == 0, return; end
            options = struct( ...
                allow_additional_charge_separation = false, ...
                multibreak = false);
            options = parseOptions(options, varargin);
            obj.molecule_entry = moleculeEntry;
            obj.fragment_entries = normalizeEntries(fragmentEntries);
            obj.allow_additional_charge_separation = logical( ...
                options.allow_additional_charge_separation);
            obj.multibreak = logical(options.multibreak);
            obj.filter_fragment_entries(obj.fragment_entries);

            requiredKeys = ["formula_pretty", ...
                "initial_molecule", "final_molecule"];
            if isfield(obj.molecule_entry, "pcm_dielectric")
                requiredKeys(end + 1) = "pcm_dielectric";
            end
            for key = requiredKeys
                if ~isfield(obj.molecule_entry, key)
                    error("KSSOLV:Matgenlab:BondDissociation:MissingKey", ...
                        "key='%s' must be present in molecule entry.", key);
                end
                for index = 1:numel(obj.filtered_entries)
                    if ~isfield(obj.filtered_entries{index}, key)
                        error("KSSOLV:Matgenlab:BondDissociation:MissingKey", ...
                            "key='%s' must be present in all fragment entries.", ...
                            key);
                    end
                end
            end

            finalCharge = double(obj.molecule_entry.final_molecule.charge);
            if ~obj.allow_additional_charge_separation
                if finalCharge == 0
                    obj.expected_charges = [-1, 0, 1];
                elseif finalCharge < 0
                    obj.expected_charges = [finalCharge, finalCharge + 1];
                else
                    obj.expected_charges = [finalCharge - 1, finalCharge];
                end
            elseif finalCharge == 0
                obj.expected_charges = -2:2;
            elseif finalCharge < 0
                obj.expected_charges = finalCharge + (-1:2);
            else
                obj.expected_charges = finalCharge + (-2:1);
            end

            molecule = kssolv.analysis.matgenlab.core.Molecule. ...
                from_dict(obj.molecule_entry.final_molecule);
            strategy = kssolv.analysis.matgenlab.core.OpenBabelNN();
            obj.mol_graph = molecularGraph(molecule, strategy);
            edges = obj.mol_graph.graph.edges;
            for index = 1:numel(edges)
                obj.fragment_and_process( ...
                    [edges(index).from_index, edges(index).to_index]);
            end
            if obj.multibreak
                for first = 1:size(obj.ring_bonds, 1)
                    for second = first + 1:size(obj.ring_bonds, 1)
                        pair = {obj.ring_bonds(first, :), ...
                            obj.ring_bonds(second, :)};
                        obj.bond_pairs{end + 1} = pair;
                    end
                end
                for index = 1:numel(obj.bond_pairs)
                    obj.fragment_and_process(obj.bond_pairs{index});
                end
            end
        end

        function fragment_and_process(obj, bonds)
            %FRAGMENT_AND_PROCESS Fragment the parent graph at one/two bonds.
            bondRows = normalizeBonds(bonds);
            fragments = {};
            splitSucceeded = true;
            try
                fragments = obj.mol_graph.split_molecule_subgraphs( ...
                    bondRows, "allow_reverse", true);
            catch exception
                if ~strcmp(exception.identifier, ...
                        "KSSOLV:Matgenlab:MolGraphSplitError")
                    rethrow(exception);
                end
                splitSucceeded = false;
            end

            if ~splitSucceeded
                if size(bondRows, 1) == 1
                    obj.ring_bonds(end + 1, :) = bondRows;
                    opened = kssolv.analysis.matgenlab.core. ...
                        MoleculeGraph(obj.mol_graph);
                    opened.break_edge(bondRows(1), bondRows(2), ...
                        "allow_reverse", true);
                    alreadyDone = any(cellfun( ...
                        @(item) opened.isomorphic_to(item), ...
                        obj.done_RO_frags));
                    if ~alreadyDone
                        obj.done_RO_frags{end + 1} = opened;
                        matches = obj.search_fragment_entries(opened);
                        goodEntries = chargedRingEntries(matches{1}, ...
                            obj.molecule_entry.final_molecule.charge);
                        if isempty(goodEntries)
                            goodEntries = chargedRingEntries(matches{2}, ...
                                obj.molecule_entry.final_molecule.charge);
                        end
                        if isscalar(goodEntries)
                            obj.bond_dissociation_energies{end + 1} = ...
                                obj.build_new_entry(goodEntries, bondRows);
                        elseif numel(goodEntries) > 1
                            error( ...
                                "KSSOLV:Matgenlab:BondDissociation:RingEntry", ...
                                "There should only be one valid ring opening fragment.");
                        end
                    end
                elseif size(bondRows, 1) == 2
                    error("KSSOLV:Matgenlab:BondDissociation:MultiSplit", ...
                        "Two-bond splitting is only meaningful when it fragments a ring.");
                else
                    error("KSSOLV:Matgenlab:BondDissociation:BondCount", ...
                        "No reason to break more than two bonds at once.");
                end
                return
            end

            if numel(fragments) ~= 2
                error("KSSOLV:Matgenlab:BondDissociation:FragmentCount", ...
                    "Bond breaking must produce exactly two fragments.");
            end
            alreadyDone = false;
            for index = 1:numel(obj.done_frag_pairs)
                previous = obj.done_frag_pairs{index};
                direct = previous{1}.isomorphic_to(fragments{1}) && ...
                    previous{2}.isomorphic_to(fragments{2});
                reverse = previous{2}.isomorphic_to(fragments{1}) && ...
                    previous{1}.isomorphic_to(fragments{2});
                if direct || reverse
                    alreadyDone = true;
                    break
                end
            end
            if alreadyDone, return; end
            obj.done_frag_pairs{end + 1} = fragments;

            firstEntries = obj.search_fragment_entries(fragments{1});
            secondEntries = obj.search_fragment_entries(fragments{2});
            count = obj.addPairs(firstEntries{1}, ...
                secondEntries{1}, bondRows, 0);
            if count < numel(obj.expected_charges)
                count = obj.addPairs(firstEntries{1}, ...
                    secondEntries{2}, bondRows, count);
                obj.addPairs(firstEntries{2}, ...
                    secondEntries{1}, bondRows, count);
            end
        end

        function entries = search_fragment_entries(obj, fragment)
            %SEARCH_FRAGMENT_ENTRIES Find unchanged/initial/final matches.
            unchanged = {};
            initialOnly = {};
            finalOnly = {};
            for index = 1:numel(obj.filtered_entries)
                entry = obj.filtered_entries{index};
                initialMatch = fragment.isomorphic_to( ...
                    entry.initial_molgraph);
                finalMatch = fragment.isomorphic_to(entry.final_molgraph);
                if initialMatch && finalMatch
                    unchanged{end + 1} = entry;
                elseif initialMatch
                    initialOnly{end + 1} = entry;
                elseif finalMatch
                    finalOnly{end + 1} = entry;
                end
            end
            entries = {unchanged, initialOnly, finalOnly};
        end

        function filter_fragment_entries(obj, fragmentEntries)
            %FILTER_FRAGMENT_ENTRIES Validate, classify and deduplicate entries.
            obj.filtered_entries = {};
            entries = normalizeEntries(fragmentEntries);
            strategy = kssolv.analysis.matgenlab.core.OpenBabelNN();
            for index = 1:numel(entries)
                entry = entries{index};
                if isfield(obj.molecule_entry, "pcm_dielectric")
                    if ~isfield(entry, "pcm_dielectric")
                        error("KSSOLV:Matgenlab:BondDissociation:PCM", ...
                            "Principle molecule has a PCM dielectric of %g " + ...
                            "but a fragment entry has no PCM dielectric.", ...
                            obj.molecule_entry.pcm_dielectric);
                    end
                    if entry.pcm_dielectric ~= ...
                            obj.molecule_entry.pcm_dielectric
                        error("KSSOLV:Matgenlab:BondDissociation:PCM", ...
                            "Principle molecule has a PCM dielectric of %g " + ...
                            "but a fragment entry has a different PCM dielectric.", ...
                            obj.molecule_entry.pcm_dielectric);
                    end
                end
                requireEntryFields(entry);
                initial = kssolv.analysis.matgenlab.core.Molecule. ...
                    from_dict(entry.initial_molecule);
                final = kssolv.analysis.matgenlab.core.Molecule. ...
                    from_dict(entry.final_molecule);
                entry.initial_molgraph = molecularGraph(initial, strategy);
                entry.final_molgraph = molecularGraph(final, strategy);
                if entry.initial_molgraph.isomorphic_to( ...
                        entry.final_molgraph)
                    entry.structure_change = "no_change";
                elseif isConnected(entry.initial_molgraph) && ...
                        ~isConnected(entry.final_molgraph)
                    entry.structure_change = "unconnected_fragments";
                elseif entry.final_molgraph.graph.number_of_edges() < ...
                        entry.initial_molgraph.graph.number_of_edges()
                    entry.structure_change = "fewer_bonds";
                elseif entry.final_molgraph.graph.number_of_edges() > ...
                        entry.initial_molgraph.graph.number_of_edges()
                    entry.structure_change = "more_bonds";
                else
                    entry.structure_change = "bond_change";
                end

                duplicate = false;
                for previousIndex = 1:numel(obj.filtered_entries)
                    previous = obj.filtered_entries{previousIndex};
                    same = string(previous.formula_pretty) == ...
                        string(entry.formula_pretty) && ...
                        previous.initial_molgraph.isomorphic_to( ...
                        entry.initial_molgraph) && ...
                        previous.final_molgraph.isomorphic_to( ...
                        entry.final_molgraph) && ...
                        previous.initial_molecule.charge == ...
                        entry.initial_molecule.charge;
                    if same
                        duplicate = true;
                        if entry.final_energy < previous.final_energy
                            obj.filtered_entries{previousIndex} = entry;
                        end
                        break
                    end
                end
                if ~duplicate
                    obj.filtered_entries{end + 1} = entry;
                end
            end
        end

        function entry = build_new_entry(obj, fragments, bonds)
            %BUILD_NEW_ENTRY Format a pymatgen-compatible BDE record.
            fragments = normalizeEntries(fragments);
            bondRows = normalizeBonds(bonds);
            firstBond = bondRows(1, :);
            firstSymbol = string(obj.mol_graph.molecule( ...
                firstBond(1)).specie.symbol);
            secondSymbol = string(obj.mol_graph.molecule( ...
                firstBond(2)).specie.symbol);
            serializedBonds = bondRows - 1;
            if numel(fragments) == 2
                first = fragments{1};
                second = fragments{2};
                energy = obj.molecule_entry.final_energy - ...
                    (first.final_energy + second.final_energy);
                entry = {energy, serializedBonds, firstSymbol, ...
                    secondSymbol, string(first.smiles), ...
                    string(first.structure_change), ...
                    double(first.initial_molecule.charge), ...
                    double(first.initial_molecule.spin_multiplicity), ...
                    double(first.final_energy), string(second.smiles), ...
                    string(second.structure_change), ...
                    double(second.initial_molecule.charge), ...
                    double(second.initial_molecule.spin_multiplicity), ...
                    double(second.final_energy)};
            else
                first = fragments{1};
                energy = obj.molecule_entry.final_energy - ...
                    first.final_energy;
                entry = {energy, serializedBonds, firstSymbol, ...
                    secondSymbol, string(first.smiles), ...
                    string(first.structure_change), ...
                    double(first.initial_molecule.charge), ...
                    double(first.initial_molecule.spin_multiplicity), ...
                    double(first.final_energy)};
            end
        end

        function value = as_dict(obj)
            value = struct( ...
                x_module = "pymatgen.analysis.bond_dissociation", ...
                x_class = "BondDissociationEnergies", ...
                molecule_entry = obj.molecule_entry, ...
                fragment_entries = {obj.fragment_entries}, ...
                allow_additional_charge_separation = ...
                    obj.allow_additional_charge_separation, ...
                multibreak = obj.multibreak);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end

        function text = toJSON(obj, varargin)
            text = kssolv.analysis.matgenlab.util.encode( ...
                obj.as_dict(), varargin{:});
        end
    end

    methods (Access = private)
        function count = addPairs(obj, firstEntries, secondEntries, ...
                bonds, count)
            targetCharge = obj.molecule_entry.final_molecule.charge;
            for firstIndex = 1:numel(firstEntries)
                first = firstEntries{firstIndex};
                for secondIndex = 1:numel(secondEntries)
                    second = secondEntries{secondIndex};
                    charge = first.initial_molecule.charge + ...
                        second.initial_molecule.charge;
                    if charge == targetCharge
                        obj.bond_dissociation_energies{end + 1} = ...
                            obj.build_new_entry({first, second}, bonds);
                        count = count + 1;
                    end
                end
            end
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies(value.molecule_entry, ...
                value.fragment_entries, ...
                "allow_additional_charge_separation", ...
                fieldOr(value, ...
                "allow_additional_charge_separation", false), ...
                "multibreak", fieldOr(value, "multibreak", false));
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.analysis. ...
                BondDissociationEnergies.from_dict(value);
        end
    end
end

function output = parseOptions(output, input)
if isempty(input), return; end
if isscalar(input) && isstruct(input{1})
    value = input{1};
    names = fieldnames(value);
    for index = 1:numel(names)
        output.(names{index}) = value.(names{index});
    end
    return
end
for index = 1:2:numel(input)
    key = char(string(input{index}));
    if ~isfield(output, key)
        error("KSSOLV:Matgenlab:BondDissociation:Option", ...
            "Unknown option '%s'.", key);
    end
    output.(key) = input{index + 1};
end
end

function entries = normalizeEntries(value)
if isempty(value)
    entries = {};
elseif iscell(value)
    entries = reshape(value, 1, []);
elseif isstruct(value)
    entries = num2cell(reshape(value, 1, []));
else
    error("KSSOLV:Matgenlab:BondDissociation:Entries", ...
        "Entries must be a struct array or cell array of structs.");
end
end

function bonds = normalizeBonds(value)
if iscell(value)
    if isempty(value), bonds = zeros(0, 2); return; end
    bonds = vertcat(value{:});
else
    bonds = value;
end
bonds = double(reshape(bonds, [], 2));
if any(bonds(:) < 1) || any(mod(bonds(:), 1) ~= 0)
    error("KSSOLV:Matgenlab:BondDissociation:Bonds", ...
        "MATLAB bond indices must be positive integers.");
end
end

function result = chargedRingEntries(entries, charge)
result = {};
for index = 1:numel(entries)
    if entries{index}.initial_molecule.charge == charge
        result{end + 1} = entries{index};
    end
end
end

function requireEntryFields(entry)
required = ["formula_pretty", "initial_molecule", ...
    "final_molecule", "final_energy", "smiles"];
for key = required
    if ~isfield(entry, key)
        error("KSSOLV:Matgenlab:BondDissociation:MissingKey", ...
            "key='%s' must be present in all fragment entries.", key);
    end
end
end

function connected = isConnected(graph)
adjacency = graph.graph.adjacency();
if isempty(adjacency), connected = true; return; end
visited = false(1, size(adjacency, 1));
queue = 1;
visited(1) = true;
while ~isempty(queue)
    node = queue(1);
    queue(1) = [];
    neighbors = find(adjacency(node, :) > 0 & ~visited);
    visited(neighbors) = true;
    queue = [queue, neighbors];
end
connected = all(visited);
end

function value = fieldOr(data, name, fallback)
if isfield(data, name), value = data.(name); else, value = fallback; end
end

function graph = molecularGraph(molecule, strategy)
graph = kssolv.analysis.matgenlab.core.MoleculeGraph. ...
    from_local_env_strategy(molecule, strategy);
% Open Babel does not perceive H-H bonds inside hydrocarbon fragments.
% Covalent-radius perception can otherwise introduce one when a highly
% distorted optimization places two hydrogens unusually close together.
remove = [];
for index = 1:numel(graph.graph.edges)
    edge = graph.graph.edges(index);
    first = string(molecule(edge.from_index).specie.symbol);
    second = string(molecule(edge.to_index).specie.symbol);
    if first == "H" && second == "H"
        remove(end + 1) = index;
    end
end
for index = fliplr(remove)
    graph.graph.remove_edge(index);
end
end
