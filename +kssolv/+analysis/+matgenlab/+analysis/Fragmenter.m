classdef Fragmenter < kssolv.analysis.matgenlab.util.MSONable
    %FRAGMENTER Generate unique molecular fragments by bond cleavage.
    properties (SetAccess = private)
        assume_previous_thoroughness (1,1) logical = true
        open_rings (1,1) logical = false
        opt_steps (1,1) double = 10000
        mol_graph
        prev_unique_frag_dict
        new_unique_frag_dict
        all_unique_frag_dict
        unique_frag_dict
        fragments_by_level
        new_unique_fragments (1,1) double = 0
        total_unique_fragments (1,1) double = 0
    end
    properties (Access = private)
        open_ring_backend = []
    end
    methods
        function obj = Fragmenter(molecule, edges, depth, open_rings, ...
                use_metal_edge_extender, opt_steps, ...
                prev_unique_frag_dict, assume_previous_thoroughness, ...
                open_ring_backend)
            if nargin < 2, edges = []; end
            if nargin < 3 || isempty(depth), depth = 1; end
            if nargin < 4 || isempty(open_rings), open_rings = false; end
            if nargin < 5 || isempty(use_metal_edge_extender)
                use_metal_edge_extender = false;
            end
            if nargin < 6 || isempty(opt_steps), opt_steps = 10000; end
            if nargin < 7, prev_unique_frag_dict = []; end
            if nargin < 8 || isempty(assume_previous_thoroughness)
                assume_previous_thoroughness = true;
            end
            if nargin < 9, open_ring_backend = []; end
            validateattributes(depth, {'numeric'}, ...
                {'scalar', 'integer', 'nonnegative'});
            obj.assume_previous_thoroughness = ...
                logical(assume_previous_thoroughness);
            obj.open_rings = logical(open_rings);
            obj.opt_steps = opt_steps;
            obj.open_ring_backend = open_ring_backend;
            if isempty(edges)
                obj.mol_graph = ...
                    kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                    from_local_env_strategy(molecule, ...
                    kssolv.analysis.matgenlab.core.OpenBabelNN());
            else
                obj.mol_graph = ...
                    kssolv.analysis.matgenlab.core.MoleculeGraph. ...
                    from_edges(molecule, edges);
            end
            symbols = molecule.symbol_set;
            if use_metal_edge_extender && ...
                    any(ismember(symbols, ["Li", "Mg"]))
                obj.mol_graph = ...
                    kssolv.analysis.matgenlab.core.metal_edge_extender( ...
                    obj.mol_graph);
            end
            obj.prev_unique_frag_dict = normalizeMap(prev_unique_frag_dict);
            obj.new_unique_frag_dict = emptyMap();
            obj.all_unique_frag_dict = emptyMap();
            obj.unique_frag_dict = emptyMap();
            obj.fragments_by_level = emptyMap();
            if depth == 0
                obj.all_unique_frag_dict = normalizeMap( ...
                    obj.mol_graph.build_unique_fragments());
                if obj.open_rings, obj.openAllRings(); end
            else
                initial = emptyMap();
                initial(obj.fragmentKey(obj.mol_graph)) = {obj.mol_graph};
                for level = 0:(depth - 1)
                    if level == 0
                        current = obj.fragmentOneLevel(initial);
                    else
                        previous = obj.fragments_by_level(char(string(level - 1)));
                        if mapCount(previous) == 0, break; end
                        current = obj.fragmentOneLevel(previous);
                    end
                    obj.fragments_by_level(char(string(level))) = current;
                end
            end
            obj.new_unique_frag_dict = obj.differenceFromPrevious();
            obj.new_unique_fragments = mapCount(obj.new_unique_frag_dict);
            obj.unique_frag_dict = cloneMap(obj.prev_unique_frag_dict);
            names = obj.new_unique_frag_dict.keys;
            for index = 1:numel(names)
                name = names{index};
                additions = cloneGraphs(obj.new_unique_frag_dict(name));
                if isKey(obj.unique_frag_dict, name)
                    obj.unique_frag_dict(name) = ...
                        [obj.unique_frag_dict(name), additions];
                else
                    obj.unique_frag_dict(name) = additions;
                end
            end
            obj.total_unique_fragments = mapCount(obj.unique_frag_dict);
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.analysis.fragmenter", ...
                "x_class", "Fragmenter", "open_rings", obj.open_rings, ...
                "opt_steps", obj.opt_steps, ...
                "assume_previous_thoroughness", ...
                obj.assume_previous_thoroughness, ...
                "mol_graph", obj.mol_graph.as_dict(), ...
                "new_unique_fragments", obj.new_unique_fragments, ...
                "total_unique_fragments", obj.total_unique_fragments, ...
                "unique_frag_dict", mapAsStruct(obj.unique_frag_dict));
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end
    methods (Access = private)
        function output = fragmentOneLevel(obj, input)
            output = emptyMap();
            names = input.keys;
            for nameIndex = 1:numel(names)
                oldFragments = input(names{nameIndex});
                for oldIndex = 1:numel(oldFragments)
                    old = oldFragments{oldIndex};
                    edges = old.graph.edges;
                    for edgeIndex = 1:numel(edges)
                        edge = edges(edgeIndex);
                        bond = [edge.from_index, edge.to_index];
                        try
                            fragments = old.split_molecule_subgraphs( ...
                                bond, "allow_reverse", true);
                        catch exception
                            if exception.identifier ~= ...
                                    "KSSOLV:Matgenlab:MolGraphSplitError"
                                rethrow(exception)
                            end
                            fragments = {};
                            if obj.open_rings
                                fragments = { ...
                                    kssolv.analysis.matgenlab.analysis. ...
                                    open_ring(old, bond, obj.opt_steps, ...
                                    obj.open_ring_backend)};
                            end
                        end
                        for fragmentIndex = 1:numel(fragments)
                            fragment = fragments{fragmentIndex};
                            key = obj.fragmentKey(fragment);
                            proceed = true;
                            if obj.assume_previous_thoroughness && ...
                                    isKey(obj.prev_unique_frag_dict, key)
                                proceed = ~containsIsomorph( ...
                                    obj.prev_unique_frag_dict(key), fragment);
                            end
                            if ~proceed, continue; end
                            if ~isKey(obj.all_unique_frag_dict, key)
                                obj.all_unique_frag_dict(key) = {fragment};
                                output(key) = {fragment};
                            elseif ~containsIsomorph( ...
                                    obj.all_unique_frag_dict(key), fragment)
                                obj.all_unique_frag_dict(key) = ...
                                    [obj.all_unique_frag_dict(key), {fragment}];
                                if isKey(output, key)
                                    output(key) = [output(key), {fragment}];
                                else
                                    output(key) = {fragment};
                                end
                            end
                        end
                    end
                end
            end
        end

        function openAllRings(obj)
            moleculeKey = obj.fragmentKey(obj.mol_graph);
            obj.all_unique_frag_dict(moleculeKey) = {obj.mol_graph};
            pending = {moleculeKey};
            while ~isempty(pending)
                next = {};
                for keyIndex = 1:numel(pending)
                    fragments = obj.all_unique_frag_dict(pending{keyIndex});
                    for fragmentIndex = 1:numel(fragments)
                        fragment = fragments{fragmentIndex};
                        rings = fragment.find_rings();
                        if isempty(rings), continue; end
                        ring = rings{1};
                        for bondIndex = 1:size(ring, 1)
                            opened = ...
                                kssolv.analysis.matgenlab.analysis. ...
                                open_ring(fragment, ...
                                ring(bondIndex, :), obj.opt_steps, ...
                                obj.open_ring_backend);
                            key = obj.fragmentKey(opened);
                            if ~isKey(obj.all_unique_frag_dict, key)
                                obj.all_unique_frag_dict(key) = {opened};
                                next{end + 1} = key; %#ok<AGROW>
                            elseif ~containsIsomorph( ...
                                    obj.all_unique_frag_dict(key), opened)
                                obj.all_unique_frag_dict(key) = ...
                                    [obj.all_unique_frag_dict(key), {opened}];
                            end
                        end
                    end
                end
                pending = unique(next, "stable");
            end
            if isKey(obj.all_unique_frag_dict, moleculeKey)
                remove(obj.all_unique_frag_dict, moleculeKey);
            end
        end

        function output = differenceFromPrevious(obj)
            output = emptyMap();
            names = obj.all_unique_frag_dict.keys;
            for index = 1:numel(names)
                key = names{index};
                fragments = obj.all_unique_frag_dict(key);
                for fragmentIndex = 1:numel(fragments)
                    fragment = fragments{fragmentIndex};
                    if ~isKey(obj.prev_unique_frag_dict, key) || ...
                            ~containsIsomorph( ...
                            obj.prev_unique_frag_dict(key), fragment)
                        if isKey(output, key)
                            output(key) = [output(key), ...
                                {cloneGraph(fragment)}];
                        else
                            output(key) = {cloneGraph(fragment)};
                        end
                    end
                end
            end
        end

        function key = fragmentKey(~, graph)
            key = char(graph.molecule.composition.alphabetical_formula + ...
                " E" + graph.graph.number_of_edges());
        end
    end
end

function value = emptyMap()
value = containers.Map("KeyType", "char", "ValueType", "any");
end

function output = normalizeMap(input)
output = emptyMap();
if isempty(input), return; end
if isa(input, "containers.Map")
    names = input.keys;
    for index = 1:numel(names)
        output(names{index}) = cloneGraphs(input(names{index}));
    end
elseif isstruct(input)
    names = fieldnames(input);
    for index = 1:numel(names)
        output(names{index}) = cloneGraphs(input.(names{index}));
    end
else
    error("KSSOLV:Matgenlab:Fragmenter:FragmentDictionary", ...
        "Fragment dictionaries must be structs or containers.Map values.");
end
end

function output = cloneMap(input)
output = normalizeMap(input);
end

function output = cloneGraphs(input)
if ~iscell(input), input = num2cell(input); end
output = cellfun(@cloneGraph, input, "UniformOutput", false);
end

function output = cloneGraph(input)
output = kssolv.analysis.matgenlab.core.MoleculeGraph(input);
end

function tf = containsIsomorph(fragments, target)
if ~iscell(fragments), fragments = num2cell(fragments); end
tf = any(cellfun(@(fragment) fragment.isomorphic_to(target), fragments));
end

function count = mapCount(input)
count = 0;
names = input.keys;
for index = 1:numel(names), count = count + numel(input(names{index})); end
end

function value = mapAsStruct(input)
value = struct();
names = input.keys;
for index = 1:numel(names)
    field = matlab.lang.makeValidName(names{index});
    graphs = input(names{index});
    value.(field) = cellfun(@(graph) graph.as_dict(), graphs, ...
        "UniformOutput", false);
end
end
