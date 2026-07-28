classdef IcetSQS
    %ICETSQS Interface to an explicitly supplied ICET-compatible backend.
    %
    % The production package does not load Python.  Call set_backend or pass
    % backend=... to supply a MATLAB adapter for ICET's cluster operations.
    properties (SetAccess = private)
        structure
        scaling (1,1) double
        instances (1,1) double
        cluster_cutoffs (1,1) struct
        sqs_method (1,1) string
        sqs_kwargs (1,1) struct
        composition (1,1) struct
        cutoffs_list double
        ordered_atoms
        target_concentrations
        sqs_vector
    end
    properties (Access = private)
        backend (1,1) struct
        sqs_objective_kwargs (1,1) struct = struct()
    end
    methods
        function obj = IcetSQS(structure, scaling, instances, ...
                cluster_cutoffs, sqs_method, sqs_kwargs, options)
            arguments
                structure
                scaling (1,1) double {mustBeInteger,mustBePositive}
                instances
                cluster_cutoffs (1,1) struct
                sqs_method = ""
                sqs_kwargs (1,1) struct = struct()
                options.backend = []
            end
            backend = options.backend;
            if isempty(backend), backend = obj.backendStore("get"); end
            obj.validateBackend(backend);
            obj.backend = backend;
            obj.structure = structure;
            obj.scaling = scaling;
            if isempty(instances)
                instances = feature("numcores");
            end
            validateattributes(instances, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            obj.instances = instances;
            obj.cluster_cutoffs = cluster_cutoffs;
            obj.composition = obj.getSiteComposition();
            [obj.cutoffs_list, obj.ordered_atoms] = ...
                obj.prepareHost(cluster_cutoffs);
            if strlength(string(sqs_method)) == 0
                if scaling * structure.num_sites < 24
                    sqs_method = "enumeration";
                else
                    sqs_method = "monte_carlo";
                end
            end
            obj.sqs_method = string(sqs_method);
            allowed = obj.allowedKwargs(obj.sqs_method);
            defaults = struct("optimality_weight", [], "tol", 1e-5, ...
                "include_smaller_cells", false, ...
                "pbc", [true, true, true]);
            merged = defaults;
            names = fieldnames(sqs_kwargs);
            for index = 1:numel(names)
                merged.(names{index}) = sqs_kwargs.(names{index});
            end
            ignored = setdiff(string(fieldnames(merged)), allowed);
            if ~isempty(ignored)
                warning("KSSOLV:Matgenlab:IcetSQS:IgnoredKwargs", ...
                    "Ignoring unrecognized icet %s kwargs: %s", ...
                    obj.sqs_method, strjoin(ignored, ", "));
                merged = rmfield(merged, cellstr(ignored));
            end
            if obj.sqs_method == "monte_carlo"
                if ~isfield(merged, "random_seed") || ...
                        isempty(merged.random_seed)
                    merged.random_seed = floor(posixtime(datetime("now")) * 1e6);
                end
            elseif obj.sqs_method ~= "enumeration"
                error("KSSOLV:Matgenlab:IcetSQS:UnknownMethod", ...
                    "Unknown sqs_method='%s'! Must be enumeration or " + ...
                    "monte_carlo.", obj.sqs_method);
            end
            obj.sqs_kwargs = merged;
            for name = ["optimality_weight", "tol"]
                field = char(name);
                if isfield(merged, field) && ~isempty(merged.(field)) && ...
                        merged.(field) ~= 0
                    obj.sqs_objective_kwargs.(field) = merged.(field);
                end
            end
            clusterSpace = obj.getClusterSpace();
            obj.target_concentrations = backend.validate_concentrations( ...
                obj.composition, clusterSpace);
            obj.sqs_vector = backend.get_sqs_cluster_vector( ...
                clusterSpace, obj.target_concentrations);
        end

        function result = run(obj)
            if obj.sqs_method == "enumeration"
                entries = obj.enumerate_sqs_structures();
            else
                entries = obj.monte_carlo_sqs_structures();
            end
            if isempty(entries)
                error("KSSOLV:Matgenlab:IcetSQS:NoStructures", ...
                    "The ICET backend returned no candidate structures.");
            end
            if isstruct(entries), entries = num2cell(entries); end
            scores = cellfun(@(entry) entry.objective_function, entries);
            [~, order] = sort(scores);
            entries = entries(order);
            for index = 1:numel(entries)
                if ~isa(entries{index}.structure, ...
                        "kssolv.analysis.matgenlab.core.IStructure")
                    entries{index}.structure = ...
                        kssolv.analysis.matgenlab.io.ase. ...
                        AseAtomsAdaptor.get_structure( ...
                        entries{index}.structure);
                end
            end
            clusterSpace = obj.getClusterSpace();
            if isfield(obj.backend, "describe_cluster_space")
                description = obj.backend.describe_cluster_space(clusterSpace);
            else
                description = string(jsonencode(clusterSpace));
            end
            result = kssolv.analysis.matgenlab.command_line. ...
                mcsqs_caller.Sqs(entries{1}.structure, ...
                entries{1}.objective_function, entries, ...
                description, "./");
        end

        function objective = get_icet_sqs_obj(obj, material, cluster_space)
            if nargin < 3 || isempty(cluster_space)
                cluster_space = obj.getClusterSpace();
            end
            if isa(material, "kssolv.analysis.matgenlab.core.IStructure")
                material = kssolv.analysis.matgenlab.io.ase. ...
                    AseAtomsAdaptor.get_atoms(material, false);
            end
            vector = obj.backend.get_cluster_vector(cluster_space, material);
            objective = obj.backend.compare_cluster_vectors( ...
                vector, obj.sqs_vector, cluster_space, ...
                obj.sqs_objective_kwargs);
        end

        function entries = enumerate_sqs_structures(obj, cluster_space)
            if nargin < 2 || isempty(cluster_space)
                cluster_space = obj.getClusterSpace();
            end
            restrictions = obj.concentrationRestrictions(cluster_space);
            if obj.sqs_kwargs.include_smaller_cells
                sizes = 1:obj.scaling;
            else
                sizes = obj.scaling;
            end
            candidates = obj.backend.enumerate_structures( ...
                cluster_space, sizes, restrictions, obj.sqs_kwargs);
            if isstruct(candidates), candidates = num2cell(candidates); end
            best = cell(1, obj.instances);
            for instance = 1:obj.instances
                score = inf;
                selected = [];
                for index = instance:obj.instances:numel(candidates)
                    candidateScore = obj.get_icet_sqs_obj( ...
                        candidates{index}, cluster_space);
                    if candidateScore < score
                        score = candidateScore;
                        selected = candidates{index};
                    end
                end
                if ~isempty(selected)
                    best{instance} = struct("structure", selected, ...
                        "objective_function", score);
                end
            end
            entries = best(~cellfun(@isempty, best));
        end

        function entries = monte_carlo_sqs_structures(obj)
            entries = cell(1, obj.instances);
            for instance = 1:obj.instances
                kwargs = obj.sqs_kwargs;
                if isfield(kwargs, "random_seed")
                    kwargs.random_seed = kwargs.random_seed + instance - 1;
                end
                clusterSpace = obj.getClusterSpace();
                candidateStructure = obj.backend.generate_sqs(clusterSpace, ...
                    obj.scaling, obj.target_concentrations, kwargs);
                entries{instance} = struct("structure", candidateStructure, ...
                    "objective_function", obj.get_icet_sqs_obj( ...
                    candidateStructure, clusterSpace));
            end
        end
    end
    methods (Static)
        function set_backend(backend)
            %SET_BACKEND Explicitly install or clear the ICET adapter.
            if nargin == 0, backend = []; end
            if ~isempty(backend)
                kssolv.analysis.matgenlab.io.icet.IcetSQS. ...
                    validateBackend(backend);
            end
            kssolv.analysis.matgenlab.io.icet.IcetSQS. ...
                backendStore("set", backend);
        end
    end
    methods (Access = private)
        function composition = getSiteComposition(obj)
            composition = struct();
            canonical = strings(1, 0);
            letters = char('A':'Z');
            for index = 1:obj.structure.num_sites
                mapping = obj.structure.sites{index}.species.as_dict();
                names = sort(string(keys(mapping)));
                fractions = zeros(1, numel(names));
                for species = 1:numel(names)
                    fractions(species) = mapping(char(names(species)));
                end
                key = strjoin(names + "=" + compose("%.16g", fractions), ";");
                match = find(canonical == key, 1);
                if isempty(match)
                    if numel(canonical) == numel(letters)
                        error("KSSOLV:Matgenlab:IcetSQS:Sublattices", ...
                            "ICET supports at most 26 distinct sublattices.");
                    end
                    canonical(end + 1) = key; %#ok<AGROW>
                    composition.(letters(numel(canonical))) = mapping;
                end
            end
        end

        function [cutoffs, atoms] = prepareHost(obj, clusterCutoffs)
            names = string(fieldnames(clusterCutoffs));
            orders = double(str2double(names));
            if any(isnan(orders))
                orders = zeros(size(names));
                for index = 1:numel(names)
                    token = regexp(names(index), "\d+", "match", "once");
                    orders(index) = str2double(token);
                end
            end
            if isempty(orders) || any(isnan(orders)) || max(orders) < 2
                error("KSSOLV:Matgenlab:IcetSQS:ClusterCutoffs", ...
                    "cluster_cutoffs must define integer orders from 2.");
            end
            cutoffs = zeros(1, max(orders) - 1);
            for index = 1:numel(orders)
                cutoffs(orders(index) - 1) = ...
                    clusterCutoffs.(char(names(index)));
            end
            ordered = obj.structure.copy();
            allSpecies = ordered.composition.as_dict();
            speciesNames = string(keys(allSpecies));
            dummy = speciesNames(1);
            replacements = struct();
            for index = 1:numel(speciesNames)
                replacements.(char(speciesNames(index))) = dummy;
            end
            ordered = ordered.replace_species(replacements, true);
            atoms = kssolv.analysis.matgenlab.io.ase. ...
                AseAtomsAdaptor.get_atoms(ordered, false);
        end

        function clusterSpace = getClusterSpace(obj)
            symbols = cell(1, obj.structure.num_sites);
            for index = 1:obj.structure.num_sites
                mapping = obj.structure.sites{index}.species.as_dict();
                symbols{index} = cellstr(string(keys(mapping)));
            end
            clusterSpace = obj.backend.create_cluster_space( ...
                obj.ordered_atoms, obj.cutoffs_list, symbols);
        end

        function restrictions = concentrationRestrictions(obj, clusterSpace)
            if isfield(obj.backend, "concentration_restrictions")
                restrictions = obj.backend.concentration_restrictions( ...
                    clusterSpace, obj.target_concentrations, ...
                    obj.sqs_kwargs.tol);
                return
            end
            restrictions = obj.target_concentrations;
        end
    end
    methods (Static, Access = private)
        function allowed = allowedKwargs(method)
            if method == "monte_carlo"
                allowed = ["include_smaller_cells", "pbc", "T_start", ...
                    "T_stop", "n_steps", "optimality_weight", ...
                    "random_seed", "tol"];
            elseif method == "enumeration"
                allowed = ["include_smaller_cells", "pbc", ...
                    "optimality_weight", "tol"];
            else
                allowed = strings(1, 0);
            end
        end

        function validateBackend(backend)
            required = ["create_cluster_space", ...
                "validate_concentrations", "get_sqs_cluster_vector", ...
                "get_cluster_vector", "compare_cluster_vectors", ...
                "enumerate_structures", "generate_sqs"];
            if isempty(backend)
                error("KSSOLV:Matgenlab:IcetSQS:BackendRequired", ...
                    "IcetSQS requires an explicit ICET adapter; Python " + ...
                    "packages are not loaded by the MATLAB runtime.");
            end
            if ~isstruct(backend)
                error("KSSOLV:Matgenlab:IcetSQS:BackendType", ...
                    "The ICET adapter must be a struct of function handles.");
            end
            for name = required
                if ~isfield(backend, char(name)) || ...
                        ~isa(backend.(char(name)), "function_handle")
                    error("KSSOLV:Matgenlab:IcetSQS:BackendContract", ...
                        "The ICET adapter is missing function '%s'.", name);
                end
            end
        end

        function value = backendStore(action, replacement)
            persistent current
            if nargin > 1, current = replacement; end
            if action == "set" && nargin < 2, current = []; end
            value = current;
        end
    end
end
