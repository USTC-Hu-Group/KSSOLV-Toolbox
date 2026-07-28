classdef LobsterNeighbors < kssolv.analysis.matgenlab.core.NearNeighbors
    %#ok<*AGROW>
    %LOBSTERNEIGHBORS Local bonding environments from ICOHP/ICOOP/ICOBI.
    properties
        structure
        ICOHP
        Icohpcollection cell = {}
        charge_obj = []
        valences = []
        limits = []
        only_bonds_to = []
        adapt_extremum_to_add_cond (1,1) logical = false
        add_additional_data_sg (1,1) logical = false
        bonding_list_1 = []
        bonding_list_2 = []
        id_blist_sg1 (1,1) string = "icoop"
        id_blist_sg2 (1,1) string = "icobi"
        noise_cutoff = 0.1
        additional_condition (1,1) double = 0
        are_coops (1,1) logical = false
        are_cobis (1,1) logical = false
        backward_compatibility (1,1) logical = false
        lowerlimit = []
        upperlimit = []
        list_icohps cell = {}
        list_lengths cell = {}
        list_keys cell = {}
        list_neighsite cell = {}
        list_neighisite cell = {}
        list_coords cell = {}
        sg_list cell = {}
        completecohp = []
    end
    properties (Dependent, SetAccess = private)
        anion_types
    end

    methods
        function obj = LobsterNeighbors(structure, icoxxlistObj, varargin)
            if nargin == 0, return; end
            options = struct( ...
                "are_coops", false, "are_cobis", false, ...
                "charge_obj", [], "valences", [], "limits", [], ...
                "additional_condition", 0, "only_bonds_to", [], ...
                "perc_strength_icohp", 0.15, "noise_cutoff", 0.1, ...
                "valences_from_charges", false, ...
                "which_charge", "Mulliken", ...
                "adapt_extremum_to_add_cond", false, ...
                "add_additional_data_sg", false, ...
                "bonding_list_1", [], "bonding_list_2", [], ...
                "id_blist_sg1", "icoop", "id_blist_sg2", "icobi", ...
                "backward_compatibility", false);
            options = parseOptions(options, varargin);
            obj.structures_allowed = true;
            obj.molecules_allowed = false;
            obj.structure = structure;
            obj.ICOHP = icoxxlistObj;
            obj.Icohpcollection = mainInteractions(icoxxlistObj);
            obj.charge_obj = options.charge_obj;
            obj.valences = options.valences;
            obj.limits = options.limits;
            obj.only_bonds_to = options.only_bonds_to;
            obj.adapt_extremum_to_add_cond = ...
                logical(options.adapt_extremum_to_add_cond);
            obj.add_additional_data_sg = ...
                logical(options.add_additional_data_sg);
            obj.bonding_list_1 = options.bonding_list_1;
            obj.bonding_list_2 = options.bonding_list_2;
            obj.id_blist_sg1 = lower(string(options.id_blist_sg1));
            obj.id_blist_sg2 = lower(string(options.id_blist_sg2));
            obj.noise_cutoff = options.noise_cutoff;
            obj.additional_condition = double(options.additional_condition);
            obj.are_coops = logical(options.are_coops);
            obj.are_cobis = logical(options.are_cobis);
            obj.backward_compatibility = ...
                logical(options.backward_compatibility);
            if ~any(obj.id_blist_sg1 == ["icoop", "icobi"]) || ...
                    ~any(obj.id_blist_sg2 == ["icoop", "icobi"])
                error("KSSOLV:Matgenlab:LobsterNeighbors:PopulationType", ...
                    "Algorithm can only work with ICOOPs, ICOBIs");
            end
            if ~ismember(obj.additional_condition, 0:6)
                error("KSSOLV:Matgenlab:LobsterNeighbors:Condition", ...
                    ['Unexpected additional_condition=%g, must be one of ' ...
                    '[0, 1, 2, 3, 4, 5, 6]'], ...
                    obj.additional_condition);
            end
            if isempty(obj.valences)
                if options.valences_from_charges
                    if isempty(obj.charge_obj)
                        error("KSSOLV:Matgenlab:LobsterNeighbors:Charge", ...
                            "A Charge object is required.");
                    end
                    if strcmpi(options.which_charge, "Loewdin")
                        obj.valences = obj.charge_obj.loewdin;
                    else
                        obj.valences = obj.charge_obj.mulliken;
                    end
                else
                    analyzer = kssolv.analysis.matgenlab.core.BVAnalyzer();
                    try
                        obj.valences = analyzer.get_valences(obj.structure);
                    catch exception
                        obj.valences = [];
                        if ismember(obj.additional_condition, [1, 3, 5, 6])
                            error("KSSOLV:Matgenlab:LobsterNeighbors:Valences", ...
                                ['Valences cannot be assigned, ' ...
                                'additional_conditions 1, 3, 5 and 6 ' ...
                                'will not work']);
                        end
                        if ~isempty(exception.identifier)
                            % Conditions independent of charge remain valid.
                        end
                    end
                end
            end
            if ~isempty(obj.valences) && all(abs(obj.valences) < 1e-12) && ...
                    ismember(obj.additional_condition, [1, 3, 5, 6])
                error("KSSOLV:Matgenlab:LobsterNeighbors:ZeroValences", ...
                    ['All valences are equal to 0, additional_conditions ' ...
                    '1, 3, 5 and 6 will not work']);
            end
            if isempty(obj.limits)
                [obj.lowerlimit, obj.upperlimit] = ...
                    obj.limitFromExtremum(options.perc_strength_icohp);
            elseif numel(obj.limits) ~= 2
                error("KSSOLV:Matgenlab:LobsterNeighbors:Limits", ...
                    "Please give two limits or leave them both empty");
            else
                obj.lowerlimit = double(obj.limits(1));
                obj.upperlimit = double(obj.limits(2));
            end
            obj = obj.evaluateEnvironments();
        end

        function value = get_anion_types(obj)
            if isempty(obj.valences)
                error("KSSOLV:Matgenlab:LobsterNeighbors:Valences", ...
                    "No cations and anions defined");
            end
            values = {};
            for index = find(obj.valences < 0)
                values{end + 1} = obj.structure(index).specie;
            end
            if isempty(values)
                value = {};
                return
            end
            symbols = cellfun(@(item) string(item.symbol), values);
            [~, uniqueIndices] = unique(symbols, "stable");
            value = values(uniqueIndices);
        end

        function value = get.anion_types(obj)
            value = obj.get_anion_types();
        end

        function value = get_nn_info(obj, structure, n, varargin)
            useWeights = false;
            if ~isempty(varargin)
                parsed = parseOptions(struct("use_weights", false), varargin);
                useWeights = logical(parsed.use_weights);
            end
            if useWeights
                error("KSSOLV:Matgenlab:LobsterNeighbors:Weights", ...
                    "LobsterEnv cannot use weights");
            end
            if structure.num_sites ~= obj.structure.num_sites
                error("KSSOLV:Matgenlab:LobsterNeighbors:StructureLength", ...
                    "Length of structure (%d) and LobsterNeighbors (%d) differ", ...
                    structure.num_sites, obj.structure.num_sites);
            end
            n = normalizeSite(n, structure.num_sites);
            value = obj.sg_list{n};
        end

        function value = get_light_structure_environment(obj, varargin)
            options = parseOptions(struct( ...
                "only_cation_environments", false, ...
                "only_indices", [], "on_error", "raise"), varargin);
            count = obj.structure.num_sites;
            symbols = cell(1, count);
            csms = cell(1, count);
            permutations = cell(1, count);
            finder = kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.LocalGeometryFinder();
            finder.setup_structure(obj.structure);
            for siteIndex = 1:count
                coordinates = obj.list_coords{siteIndex};
                coordination = size(coordinates, 1);
                if coordination > 13
                    message = sprintf(['Environment cannot be determined ' ...
                        'for site %d. Number of neighbors (%d) is larger ' ...
                        'than 13.'], siteIndex - 1, coordination);
                    if strcmpi(options.on_error, "raise")
                        error("KSSOLV:Matgenlab:LobsterNeighbors:LargeCN", ...
                            "%s", message);
                    elseif strcmpi(options.on_error, "warn")
                        warning("KSSOLV:Matgenlab:LobsterNeighbors:LargeCN", ...
                            ['Site %d has %d neighbors (>13). Using ' ...
                            'coordination number instead of geometry.'], ...
                            siteIndex - 1, coordination);
                    end
                    symbols{siteIndex} = string(coordination);
                    csms{siteIndex} = [];
                    permutations{siteIndex} = [];
                elseif coordination == 0
                    symbols{siteIndex} = [];
                    csms{siteIndex} = [];
                    permutations{siteIndex} = [];
                else
                    finder.setup_local_geometry(siteIndex, coordinates, ...
                        "optimization", 2);
                    measures = finder.get_coordination_symmetry_measures( ...
                        "optimization", 2);
                    keys = measures.keys;
                    scores = cellfun(@(key) measures(key).csm, keys);
                    [~, best] = min(scores);
                    record = measures(keys{best});
                    symbols{siteIndex} = string(keys{best});
                    csms{siteIndex} = record.csm;
                    permutations{siteIndex} = record.indices;
                end
            end
            keep = true(1, count);
            if ~isempty(options.only_indices)
                requested = normalizeSites(options.only_indices, count);
                keep = ismember(1:count, requested);
            elseif options.only_cation_environments
                if isempty(obj.valences)
                    error("KSSOLV:Matgenlab:LobsterNeighbors:Valences", ...
                        "No valences are provided");
                end
                keep = obj.valences >= 0;
            end
            neighbors = obj.list_neighsite;
            indices = obj.list_neighisite;
            for siteIndex = find(~keep)
                symbols{siteIndex} = [];
                csms{siteIndex} = [];
                permutations{siteIndex} = [];
                neighbors{siteIndex} = {};
                indices{siteIndex} = [];
            end
            value = kssolv.analysis.matgenlab.analysis. ...
                LobsterLightStructureEnvironments.from_Lobster( ...
                symbols, csms, permutations, neighbors, indices, ...
                obj.structure, obj.valences);
        end

        function value = get_info_icohps_to_neighbors(obj, varargin)
            options = parseOptions(struct( ...
                "isites", [], "onlycation_isites", true), varargin);
            sites = obj.selectedSites(options.isites, ...
                options.onlycation_isites);
            total = 0;
            populations = [];
            labels = strings(1, 0);
            atoms = {};
            central = [];
            for siteIndex = sites
                values = obj.list_icohps{siteIndex};
                keys = string(obj.list_keys{siteIndex});
                total = total + sum(values);
                populations = [populations, values];
                labels = [labels, keys];
                central = [central, repmat(siteIndex - 1, 1, numel(keys))];
                for key = keys
                    interaction = obj.interactionByLabel(key);
                    atoms{end + 1} = string(interaction.centers);
                end
            end
            value = kssolv.analysis.matgenlab.analysis. ...
                ICOHPNeighborsInfo(total, populations, ...
                numel(populations), labels, atoms, central);
        end

        function [plotLabel, summedCohp] = ...
                get_info_cohps_to_neighbors(obj, varargin)
            options = parseOptions(struct( ...
                "path_to_cohpcar", "COHPCAR.lobster", ...
                "coxxcar_obj", [], "isites", [], ...
                "only_bonds_to", [], "onlycation_isites", true, ...
                "per_bond", true, "summed_spin_channels", false), ...
                varargin);
            information = obj.get_info_icohps_to_neighbors( ...
                "isites", options.isites, ...
                "onlycation_isites", options.onlycation_isites);
            labels = information.labels;
            atoms = information.atoms;
            centralSites = information.central_isites;
            if isempty(obj.completecohp)
                if ~isempty(options.coxxcar_obj)
                    obj.completecohp = options.coxxcar_obj;
                elseif ~isempty(options.path_to_cohpcar)
                    folder = tempname;
                    mkdir(folder);
                    cleanup = onCleanup(@() rmdir(folder, "s"));
                    poscarPath = fullfile(folder, "POSCAR.vasp");
                    kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                        obj.structure).write_file(poscarPath);
                    obj.completecohp = kssolv.analysis.matgenlab. ...
                        electronic_structure.CompleteCohp.from_file( ...
                        "LOBSTER", options.path_to_cohpcar, poscarPath, ...
                        "are_coops", obj.are_coops, ...
                        "are_cobis", obj.are_cobis);
                    clear cleanup
                else
                    error("KSSOLV:Matgenlab:LobsterNeighbors:Cohpcar", ...
                        "Please provide either path_to_cohpcar or coxxcar_obj");
                end
            end
            if numel(obj.Icohpcollection) ~= obj.completecohp.bonds.Count
                error("KSSOLV:Matgenlab:LobsterNeighbors:CohpMismatch", ...
                    "COHPCAR and ICOHPLIST do not fit together");
            end
            if ~isempty(options.only_bonds_to)
                allowed = false(1, numel(labels));
                requested = string(options.only_bonds_to);
                for index = 1:numel(labels)
                    pair = string(atoms{index});
                    pairElements = regexprep(pair, "\d+$", "");
                    centralElement = obj.structure( ...
                        centralSites(index) + 1).specie.symbol;
                    for element = requested
                        if string(centralElement) ~= element
                            allowed(index) = any(pairElements == element);
                        else
                            allowed(index) = all(pairElements == element);
                        end
                        if allowed(index), break; end
                    end
                end
                labels = labels(allowed);
                atoms = atoms(allowed);
            end
            if isempty(labels)
                plotLabel = [];
                summedCohp = [];
                return
            end
            divisor = 1;
            if options.per_bond, divisor = numel(labels); end
            plotLabel = obj.get_plot_label(atoms, options.per_bond);
            summedCohp = obj.completecohp. ...
                get_summed_cohp_by_label_list(labels, divisor, ...
                options.summed_spin_channels);
        end

        function axesValue = plot_cohps_of_neighbors(obj, varargin)
            options = parseOptions(struct( ...
                "path_to_cohpcar", "COHPCAR.lobster", ...
                "coxxcar_obj", [], "isites", [], ...
                "onlycation_isites", true, "only_bonds_to", [], ...
                "per_bond", false, "summed_spin_channels", false, ...
                "xlim", [], "ylim", [-10, 6], "integrated", false), ...
                varargin);
            [label, curve] = obj.get_info_cohps_to_neighbors( ...
                "path_to_cohpcar", options.path_to_cohpcar, ...
                "coxxcar_obj", options.coxxcar_obj, ...
                "isites", options.isites, ...
                "only_bonds_to", options.only_bonds_to, ...
                "onlycation_isites", options.onlycation_isites, ...
                "per_bond", options.per_bond, ...
                "summed_spin_channels", options.summed_spin_channels);
            if isempty(curve)
                error("KSSOLV:Matgenlab:LobsterNeighbors:NoCohp", ...
                    "No matching bonds were found.");
            end
            plotter = kssolv.analysis.matgenlab.electronic_structure. ...
                CohpPlotter(true, obj.are_coops, obj.are_cobis);
            plotter.add_cohp(label, curve);
            axesValue = plotter.get_plot(options.xlim, options.ylim, [], ...
                options.integrated);
        end

        function value = get_info_icohps_between_neighbors(obj, varargin)
            options = parseOptions(struct( ...
                "isites", [], "onlycation_isites", true), varargin);
            sites = obj.selectedSites(options.isites, ...
                options.onlycation_isites);
            labels = strings(1, 0);
            populations = [];
            atoms = {};
            for central = sites
                neighborIndices = obj.list_neighisite{central};
                neighborSites = obj.list_neighsite{central};
                for first = 1:numel(neighborIndices)
                    for second = first + 1:numel(neighborIndices)
                        firstIndex = neighborIndices(first);
                        secondIndex = neighborIndices(second);
                        firstImage = floor(round( ...
                            neighborSites{first}.frac_coords, 4));
                        secondImage = floor(round( ...
                            neighborSites{second}.frac_coords, 4));
                        if firstIndex <= secondIndex
                            translation = firstImage - secondImage;
                        else
                            translation = secondImage - firstImage;
                        end
                        done = false;
                        for interactionIndex = 1:numel(obj.Icohpcollection)
                            interaction = obj.Icohpcollection{interactionIndex};
                            [atom1, atom2] = atomIndices(interaction);
                            if ~samePair(atom1, atom2, ...
                                    firstIndex, secondIndex)
                                continue
                            end
                            population = interactionPopulation(interaction);
                            outsideExplicitLimits = false;
                            if ~isempty(obj.limits)
                                outsideExplicitLimits = ...
                                    population < obj.lowerlimit || ...
                                    population > obj.upperlimit;
                            end
                            if interaction.length > 6 || ...
                                    outsideExplicitLimits
                                continue
                            end
                            interactionTranslation = ...
                                interaction.cells{2};
                            if atom1 ~= atom2
                                matches = isequal(translation, ...
                                    interactionTranslation);
                            else
                                matches = isequal(translation, ...
                                    interactionTranslation) || ...
                                    isequal(translation, ...
                                    -interactionTranslation);
                            end
                            if matches && ~(done && atom1 == atom2)
                                populations(end + 1) = population;
                                labels(end + 1) = ...
                                    string(interaction.index);
                                atoms{end + 1} = ...
                                    string(interaction.centers);
                                done = atom1 == atom2;
                            end
                        end
                    end
                end
            end
            value = kssolv.analysis.matgenlab.analysis. ...
                ICOHPNeighborsInfo(sum(populations), populations, ...
                numel(populations), labels, atoms, []);
        end

        function label = get_plot_label(~, atoms, perBond)
            bondTypes = strings(1, numel(atoms));
            for index = 1:numel(atoms)
                pair = sort(regexprep(string(atoms{index}), "\d+$", ""));
                bondTypes(index) = pair(1) + "-" + pair(2);
            end
            uniqueTypes = unique(bondTypes, "stable");
            pieces = strings(1, numel(uniqueTypes));
            for index = 1:numel(uniqueTypes)
                pieces(index) = sum(bondTypes == uniqueTypes(index)) + ...
                    " x " + uniqueTypes(index);
            end
            label = strjoin(pieces, ", ");
            if perBond, label = label + " (per bond)"; end
        end
    end

    methods (Static)
        function obj = from_files(varargin)
            options = parseOptions(struct( ...
                "structure_path", "CONTCAR", ...
                "icoxxlist_path", "ICOHPLIST.lobster", ...
                "are_coops", false, "are_cobis", false, ...
                "charge_path", [], "blist_sg1_path", [], ...
                "blist_sg2_path", [], "id_blist_sg1", "icoop", ...
                "id_blist_sg2", "icobi"), varargin, true);
            structure = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                from_file(options.structure_path).structure;
            interactions = kssolv.analysis.matgenlab.io.lobster. ...
                Icohplist(false, options.are_coops, options.are_cobis, ...
                options.icoxxlist_path);
            charge = [];
            if ~isempty(options.charge_path)
                charge = kssolv.analysis.matgenlab.io.lobster. ...
                    Charge(options.charge_path);
            end
            firstList = [];
            secondList = [];
            if fieldOr(options, "add_additional_data_sg", false)
                firstList = additionalList(options.blist_sg1_path, ...
                    options.id_blist_sg1);
                secondList = additionalList(options.blist_sg2_path, ...
                    options.id_blist_sg2);
            end
            constructorOptions = rmfield(options, ...
                ["structure_path", "icoxxlist_path", "charge_path", ...
                "blist_sg1_path", "blist_sg2_path"]);
            constructorOptions.charge_obj = charge;
            constructorOptions.bonding_list_1 = firstList;
            constructorOptions.bonding_list_2 = secondList;
            pairs = structToPairs(constructorOptions);
            obj = kssolv.analysis.matgenlab.analysis.LobsterNeighbors( ...
                structure, interactions, pairs{:});
        end
    end

    methods (Access = private)
        function [lower, upper] = limitFromExtremum(obj, percentage)
            eligible = obj.Icohpcollection;
            if obj.adapt_extremum_to_add_cond && ...
                    obj.additional_condition ~= 0
                keep = cellfun(@(item) obj.conditionAllows(item), eligible);
                eligible = eligible(keep);
            end
            if isempty(eligible)
                error("KSSOLV:Matgenlab:LobsterNeighbors:NoInteractions", ...
                    "No interactions satisfy the additional condition.");
            end
            values = cellfun(@interactionPopulation, eligible);
            if obj.are_coops || obj.are_cobis
                extremum = max(values) * percentage;
                if ~isempty(obj.noise_cutoff)
                    extremum = max(extremum, obj.noise_cutoff);
                end
                lower = extremum;
                upper = Inf;
            else
                extremum = min(values) * percentage;
                if ~isempty(obj.noise_cutoff)
                    extremum = min(extremum, -obj.noise_cutoff);
                end
                lower = -Inf;
                upper = extremum;
            end
        end

        function obj = evaluateEnvironments(obj)
            count = obj.structure.num_sites;
            obj.list_icohps = cell(1, count);
            obj.list_lengths = cell(1, count);
            obj.list_keys = cell(1, count);
            obj.list_neighsite = cell(1, count);
            obj.list_neighisite = cell(1, count);
            obj.list_coords = cell(1, count);
            obj.sg_list = cell(1, count);
            if obj.backward_compatibility
                warning("KSSOLV:Matgenlab:LobsterNeighbors:Legacy", ...
                    ['You are using an older version for neighbor ' ...
                    'detection that might not consider rare LOBSTER edge ' ...
                    'cases.']);
            end
            for central = 1:count
                populations = [];
                lengths = [];
                keys = strings(1, 0);
                sites = {};
                indices = [];
                coordinates = zeros(0, 3);
                info = {};
                translations = zeros(0, 3);
                for interactionIndex = 1:numel(obj.Icohpcollection)
                    interaction = obj.Icohpcollection{interactionIndex};
                    [atom1, atom2] = atomIndices(interaction);
                    if central ~= atom1 && central ~= atom2, continue; end
                    population = interactionPopulation(interaction);
                    if interaction.length > 6 || ...
                            population < obj.lowerlimit || ...
                            population > obj.upperlimit || ...
                            ~obj.conditionAllows(interaction)
                        continue
                    end
                    if central == atom1
                        neighborIndex = atom2;
                        image = reshape(double(interaction.cells{2}), 1, 3);
                    else
                        neighborIndex = atom1;
                        image = -reshape(double(interaction.cells{2}), 1, 3);
                    end
                    partner = obj.structure(neighborIndex).specie.symbol;
                    if ~isempty(obj.only_bonds_to) && ...
                            ~any(string(obj.only_bonds_to) == string(partner))
                        continue
                    end
                    base = obj.structure(neighborIndex);
                    neighbor = kssolv.analysis.matgenlab.core. ...
                        PeriodicSite(base.species, ...
                        base.frac_coords + image, obj.structure.lattice, ...
                        "properties", base.site_properties, ...
                        "label", base.label);
                    populations(end + 1) = population;
                    lengths(end + 1) = interaction.length;
                    keys(end + 1) = string(interaction.index);
                    sites{end + 1} = neighbor;
                    indices(end + 1) = neighborIndex;
                    coordinates(end + 1, :) = neighbor.coords;
                    translations(end + 1, :) = image;
                    edge = struct("ICOHP", population, ...
                        "bond_length", interaction.length, ...
                        "bond_label", string(interaction.index));
                    if obj.add_additional_data_sg
                        edge.(upper(char(obj.id_blist_sg1))) = ...
                            populationByLabel(obj.bonding_list_1, ...
                            interaction.index);
                        edge.(upper(char(obj.id_blist_sg2))) = ...
                            populationByLabel(obj.bonding_list_2, ...
                            interaction.index);
                    end
                    info{end + 1} = struct( ... %#ok<AGROW>
                        "site", neighbor, "image", image, "weight", 1, ...
                        "edge_properties", edge, ...
                        "site_index", neighborIndex);
                end
                kssolv.analysis.matgenlab.analysis.check_ICOHPs( ...
                    lengths, populations, translations);
                obj.list_icohps{central} = populations;
                obj.list_lengths{central} = lengths;
                obj.list_keys{central} = keys;
                obj.list_neighsite{central} = sites;
                obj.list_neighisite{central} = indices;
                obj.list_coords{central} = coordinates;
                obj.sg_list{central} = info;
            end
        end

        function value = conditionAllows(obj, interaction)
            if obj.additional_condition == 0
                value = true;
                return
            end
            [first, second] = atomIndices(interaction);
            elements = regexprep(string(interaction.centers), "\d+$", "");
            if isempty(obj.valences) && ...
                    ismember(obj.additional_condition, [1, 3, 5, 6])
                error("KSSOLV:Matgenlab:LobsterNeighbors:Valences", ...
                    "No valences are provided.");
            end
            switch obj.additional_condition
                case 1
                    value = obj.valences(first) * obj.valences(second) < 0;
                case 2
                    value = elements(1) ~= elements(2);
                case 3
                    value = obj.valences(first) * obj.valences(second) < 0 && ...
                        elements(1) ~= elements(2);
                case 4
                    value = any(elements == "O");
                case 5
                    value = (obj.valences(first) > 0 && ...
                        obj.valences(second) > 0) || ...
                        (obj.valences(first) < 0 && ...
                        obj.valences(second) < 0);
                case 6
                    value = obj.valences(first) > 0 && ...
                        obj.valences(second) > 0;
            end
        end

        function sites = selectedSites(obj, requested, onlyCations)
            if isempty(requested)
                if onlyCations
                    if isempty(obj.valences)
                        error("KSSOLV:Matgenlab:LobsterNeighbors:Valences", ...
                            "No valences are provided");
                    end
                    sites = find(obj.valences >= 0);
                else
                    sites = 1:obj.structure.num_sites;
                end
            else
                % Public MATLAB indexing is one-based. A zero in an
                % explicitly supplied list selects pymatgen site 0.
                requested = reshape(double(requested), 1, []);
                if any(requested == 0), requested = requested + 1; end
                sites = normalizeSites(requested, obj.structure.num_sites);
            end
        end

        function interaction = interactionByLabel(obj, label)
            match = find(cellfun(@(item) ...
                string(item.index) == string(label), ...
                obj.Icohpcollection), 1);
            if isempty(match)
                error("KSSOLV:Matgenlab:LobsterNeighbors:Label", ...
                    "Unknown interaction label '%s'.", string(label));
            end
            interaction = obj.Icohpcollection{match};
        end
    end
end

function interactions = mainInteractions(source)
interactions = source.interactions;
keep = cellfun(@(item) isempty(item.orbitals{1}) && ...
    isempty(item.orbitals{2}), interactions);
interactions = interactions(keep);
end

function value = interactionPopulation(interaction)
value = interaction.icoxx.up;
if isfield(interaction.icoxx, "down")
    value = value + interaction.icoxx.down;
end
end

function [first, second] = atomIndices(interaction)
first = atomIndex(interaction.centers{1});
second = atomIndex(interaction.centers{2});
end

function value = atomIndex(text)
token = regexp(char(string(text)), "(\d+)$", "tokens", "once");
value = str2double(token{1});
end

function value = samePair(first, second, otherFirst, otherSecond)
value = (first == otherFirst && second == otherSecond) || ...
    (first == otherSecond && second == otherFirst);
end

function value = populationByLabel(source, label)
interactions = mainInteractions(source);
match = find(cellfun(@(item) item.index == double(label), interactions), 1);
if isempty(match)
    error("KSSOLV:Matgenlab:LobsterNeighbors:AdditionalLabel", ...
        "Additional interaction list lacks label %s.", string(label));
end
value = interactionPopulation(interactions{match});
end

function value = additionalList(path, identity)
areCoops = strcmpi(identity, "icoop");
areCobis = strcmpi(identity, "icobi");
value = kssolv.analysis.matgenlab.io.lobster.Icohplist( ...
    false, areCoops, areCobis, path);
end

function output = parseOptions(output, input, allowUnknown)
if nargin < 3, allowUnknown = false; end
names = string(fieldnames(output));
position = 1;
index = 1;
while index <= numel(input)
    if (ischar(input{index}) || isstring(input{index})) && ...
            index < numel(input)
        match = find(strcmpi(string(input{index}), names), 1);
        if ~isempty(match)
            output.(char(names(match))) = input{index + 1};
            index = index + 2;
            continue
        elseif allowUnknown
            output.(char(string(input{index}))) = input{index + 1};
            index = index + 2;
            continue
        end
    end
    if position > numel(names)
        error("KSSOLV:Matgenlab:LobsterNeighbors:Arguments", ...
            "Too many positional arguments.");
    end
    output.(char(names(position))) = input{index};
    position = position + 1;
    index = index + 1;
end
end

function value = structToPairs(input)
names = fieldnames(input);
value = cell(1, 2 * numel(names));
for index = 1:numel(names)
    value{2 * index - 1} = names{index};
    value{2 * index} = input.(names{index});
end
end

function value = fieldOr(input, field, fallback)
if isfield(input, field), value = input.(field);
else, value = fallback; end
end

function index = normalizeSite(index, count)
index = double(index);
if index == 0, index = 1; end
if ~isscalar(index) || index ~= fix(index) || index < 1 || index > count
    error("KSSOLV:Matgenlab:LobsterNeighbors:SiteIndex", ...
        "Site index is out of range.");
end
end

function indices = normalizeSites(indices, count)
indices = reshape(double(indices), 1, []);
if any(indices ~= fix(indices)) || any(indices < 1) || any(indices > count)
    error("KSSOLV:Matgenlab:LobsterNeighbors:SiteIndex", ...
        "Site index is out of range.");
end
end
