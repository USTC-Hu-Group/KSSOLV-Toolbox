classdef EnumlibAdaptor < handle
    %ENUMLIBADAPTOR Native enumlib adapter with explicit external execution.
    %
    % The class creates enumlib's struct_enum.in text and parses the returned
    % derivative structures in MATLAB. It never searches PATH or launches a
    % process. The caller must inject an executor function handle. The
    % executor receives one request struct and returns either ordered
    % matgenlab structures directly, or enum_stdout plus POSCAR texts.

    properties (Constant)
        amount_tol (1,1) double = 1e-5
    end

    properties (SetAccess = private)
        structure
        min_cell_size (1,1) double = 1
        max_cell_size (1,1) double = 1
        symm_prec (1,1) double = 0.1
        enum_precision_parameter (1,1) double = 0.001
        refine_structure (1,1) logical = false
        check_ordered_symmetry (1,1) logical = true
        timeout = []
        executor = []
        structures (1,:) cell = cell(1, 0)
        generated_input (1,1) string = ""
        index_species (1,:) cell = cell(1, 0)
        ordered_sites (1,:) cell = cell(1, 0)
    end

    methods
        function obj = EnumlibAdaptor(structure, min_cell_size, ...
                max_cell_size, symm_prec, enum_precision_parameter, ...
                refine_structure, check_ordered_symmetry, timeout, options)
            arguments
                structure (1,1) kssolv.analysis.matgenlab.core.IStructure
                min_cell_size (1,1) double = 1
                max_cell_size (1,1) double = 1
                symm_prec (1,1) double = 0.1
                enum_precision_parameter (1,1) double = 0.001
                refine_structure (1,1) logical = false
                check_ordered_symmetry (1,1) logical = true
                timeout = []
                options.executor = []
            end
            if min_cell_size < 1 || min_cell_size ~= fix(min_cell_size)
                error("KSSOLV:Matgenlab:Enumlib:MinCellSize", ...
                    "min_cell_size must be a positive integer.");
            end
            if max_cell_size < min_cell_size || ...
                    max_cell_size ~= fix(max_cell_size)
                error("KSSOLV:Matgenlab:Enumlib:MaxCellSize", ...
                    "max_cell_size must be an integer not less than min_cell_size.");
            end
            if ~isfinite(symm_prec) || symm_prec <= 0
                error("KSSOLV:Matgenlab:Enumlib:SymmPrec", ...
                    "symm_prec must be a finite positive scalar.");
            end
            if ~isfinite(enum_precision_parameter) || ...
                    enum_precision_parameter <= 0
                error("KSSOLV:Matgenlab:Enumlib:EnumPrecision", ...
                    "enum_precision_parameter must be finite and positive.");
            end
            if ~isempty(timeout) && (~isnumeric(timeout) || ...
                    ~isscalar(timeout) || ~isfinite(timeout) || timeout < 0)
                error("KSSOLV:Matgenlab:Enumlib:Timeout", ...
                    "timeout must be empty or a finite nonnegative scalar.");
            end
            if ~isempty(options.executor) && ...
                    ~isa(options.executor, "function_handle")
                error("KSSOLV:Matgenlab:Enumlib:ExecutorType", ...
                    "executor must be a MATLAB function handle.");
            end

            obj.min_cell_size = min_cell_size;
            obj.max_cell_size = max_cell_size;
            obj.symm_prec = symm_prec;
            obj.enum_precision_parameter = enum_precision_parameter;
            obj.refine_structure = refine_structure;
            obj.check_ordered_symmetry = check_ordered_symmetry;
            obj.timeout = timeout;
            obj.executor = options.executor;
            if refine_structure
                analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure, symm_prec);
                obj.structure = analyzer.get_refined_structure();
            else
                obj.structure = structure;
            end
        end

        function run(obj)
            %RUN Generate enumlib input, execute the injected boundary, parse output.
            if isempty(obj.executor)
                error("KSSOLV:Matgenlab:Enumlib:ExecutorRequired", ...
                    "EnumlibAdaptor.run requires an explicitly injected " + ...
                    "enumlib/makestr executor.");
            end
            obj.generated_input = obj.generateInput();
            timeoutSeconds = [];
            if ~isempty(obj.timeout), timeoutSeconds = obj.timeout * 60; end
            request = struct( ...
                "enum_input_filename", "struct_enum.in", ...
                "enum_input", obj.generated_input, ...
                "enum_command_role", "enumlib", ...
                "makestr_command_role", "makestr", ...
                "min_cell_size", obj.min_cell_size, ...
                "max_cell_size", obj.max_cell_size, ...
                "timeout_minutes", obj.timeout, ...
                "timeout_seconds", timeoutSeconds);
            response = obj.executor(request);
            [count, returnedStructures, poscarTexts] = ...
                obj.normalizeExecutorResponse(response);
            if count <= 0
                exception = kssolv.analysis.matgenlab.command_line. ...
                    enumlib_caller.EnumError( ...
                    "Unable to enumerate structure.");
                throwAsCaller(exception);
            end
            if isempty(returnedStructures)
                returnedStructures = cell(1, numel(poscarTexts));
                for index = 1:numel(poscarTexts)
                    returnedStructures{index} = ...
                        obj.structureFromPoscar(poscarTexts{index});
                end
            end
            if numel(returnedStructures) ~= count
                error("KSSOLV:Matgenlab:Enumlib:ExecutorResult", ...
                    "The executor reported %d structures but returned " + ...
                    "%d structure payloads.", count, ...
                    numel(returnedStructures));
            end
            obj.structures = returnedStructures;
        end
    end

    methods (Access = private)
        function text = generateInput(obj)
            analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.structure, obj.symm_prec);
            symmetric = analyzer.get_symmetrized_structure();
            groups = symmetric.equivalent_sites;

            indexSpecies = cell(1, 0);
            indexAmounts = zeros(1, 0);
            orderedGroups = cell(1, 0);
            disorderedGroups = cell(1, 0);
            coordinateLines = strings(1, 0);
            for groupIndex = 1:numel(groups)
                sites = groups{groupIndex};
                if sites{1}.is_ordered
                    orderedGroups{end + 1} = sites; %#ok<AGROW>
                    continue
                end
                [species, amounts] = sites{1}.species.items();
                if sum(amounts) < 1 - obj.amount_tol
                    species{end + 1} = ...
                        kssolv.analysis.matgenlab.core.DummySpecies("X"); %#ok<AGROW>
                    amounts(end + 1) = 1 - sum(amounts); %#ok<AGROW>
                end
                labels = zeros(1, numel(species));
                for speciesIndex = 1:numel(species)
                    location = speciesLocation(indexSpecies, ...
                        species{speciesIndex});
                    if location == 0
                        indexSpecies{end + 1} = species{speciesIndex}; %#ok<AGROW>
                        indexAmounts(end + 1) = ...
                            amounts(speciesIndex) * numel(sites); %#ok<AGROW>
                        location = numel(indexSpecies);
                    else
                        indexAmounts(location) = indexAmounts(location) + ...
                            amounts(speciesIndex) * numel(sites);
                    end
                    labels(speciesIndex) = location - 1;
                end
                label = strjoin(string(sort(labels)), "/");
                for siteIndex = 1:numel(sites)
                    coordinateLines(end + 1) = sprintf( ... %#ok<AGROW>
                        "%.6f %.6f %.6f %s", sites{siteIndex}.coords, label); %#ok<AGROW>
                end
                disorderedGroups{end + 1} = sites; %#ok<AGROW>
            end
            if isempty(disorderedGroups)
                error("KSSOLV:Matgenlab:Enumlib:OrderedStructure", ...
                    "EnumlibAdaptor requires at least one disordered site.");
            end

            obj.ordered_sites = cell(1, 0);
            if obj.check_ordered_symmetry
                targetNumber = analyzer.get_space_group_number();
                currentSites = flattenGroups(disorderedGroups);
                currentNumber = spaceGroupNumber(currentSites, obj.symm_prec);
                [~, order] = sort(cellfun(@numel, orderedGroups));
                orderedGroups = orderedGroups(order);
                while currentNumber ~= targetNumber && ~isempty(orderedGroups)
                    sites = orderedGroups{1};
                    orderedGroups(1) = [];
                    candidateSites = [currentSites, sites];
                    newNumber = ...
                        spaceGroupNumber(candidateSites, obj.symm_prec);
                    if newNumber ~= currentNumber
                        indexSpecies{end + 1} = sites{1}.specie; %#ok<AGROW>
                        indexAmounts(end + 1) = numel(sites); %#ok<AGROW>
                        label = string(numel(indexSpecies) - 1);
                        for siteIndex = 1:numel(sites)
                            coordinateLines(end + 1) = sprintf( ... %#ok<AGROW>
                                "%.6f %.6f %.6f %s", ...
                                sites{siteIndex}.coords, label); %#ok<AGROW>
                        end
                        disorderedGroups{end + 1} = sites; %#ok<AGROW>
                        currentSites = candidateSites;
                        currentNumber = newNumber;
                    else
                        obj.ordered_sites = [obj.ordered_sites, sites];
                    end
                end
            end
            obj.ordered_sites = [obj.ordered_sites, ...
                flattenGroups(orderedGroups)];
            obj.index_species = indexSpecies;

            matrix = obj.structure.lattice.matrix;
            lines = [
                string(obj.structure.formula)
                "bulk"
                sprintf("%.6f %.6f %.6f", matrix(1, :))
                sprintf("%.6f %.6f %.6f", matrix(2, :))
                sprintf("%.6f %.6f %.6f", matrix(3, :))
                string(numel(indexSpecies))
                string(numel(coordinateLines))
                reshape(coordinateLines, [], 1)
                sprintf("%d %d", obj.min_cell_size, obj.max_cell_size)
                string(obj.enum_precision_parameter)
                "full"
                ];

            numberDisordered = sum(cellfun(@numel, disorderedGroups));
            maximumDenominator = numberDisordered * obj.max_cell_size;
            denominatorLcm = 1;
            for amount = indexAmounts
                denominator = limitedDenominator( ...
                    amount, maximumDenominator);
                denominatorLcm = lcm(denominatorLcm, denominator);
            end
            base = numberDisordered * denominatorLcm * 10;
            totalAmount = sum(indexAmounts);
            concentrationLines = strings(numel(indexAmounts), 1);
            for amountIndex = 1:numel(indexAmounts)
                amount = indexAmounts(amountIndex);
                concentration = amount / totalAmount;
                scaled = concentration * base;
                if abs(scaled - round(scaled)) < 1e-5
                    concentrationLines(amountIndex) = ...
                        sprintf("%d %d %d", ...
                        round(scaled), round(scaled), base);
                else
                    lowerBound = floor(scaled);
                    concentrationLines(amountIndex) = ...
                        sprintf("%d %d %d", ...
                        lowerBound - 1, lowerBound + 1, base);
                end
            end
            lines = [lines; concentrationLines; ""];
            text = strjoin(lines, newline);
        end

        function [count, structures, poscars] = ...
                normalizeExecutorResponse(obj, response)
            if ~isstruct(response) || ~isscalar(response)
                error("KSSOLV:Matgenlab:Enumlib:ExecutorResult", ...
                    "The enumlib executor must return a scalar struct.");
            end
            if isfield(response, "timed_out") && logical(response.timed_out)
                error("KSSOLV:Matgenlab:Enumlib:Timeout", ...
                    "Enumeration took more than timeout %g minutes", ...
                    obj.timeout);
            end
            status = fieldOr(response, "status", 0);
            if ~isscalar(status) || ~isnumeric(status) || status ~= 0
                stderr = string(fieldOr(response, "stderr", ""));
                error("KSSOLV:Matgenlab:Enumlib:Execution", ...
                    "Enumlib executor exited with status %g: %s", ...
                    double(status), stderr);
            end

            structures = normalizeStructures( ...
                fieldOr(response, "structures", {}));
            poscars = normalizeTexts(fieldOr(response, "poscar_texts", {}));
            if isempty(poscars) && isfield(response, "poscars")
                poscars = normalizeTexts(response.poscars);
            end
            if isfield(response, "num_structures")
                count = double(response.num_structures);
            elseif isfield(response, "count")
                count = double(response.count);
            elseif ~isempty(structures)
                count = numel(structures);
            elseif isfield(response, "enum_stdout")
                count = parseRunTotal(response.enum_stdout);
            elseif isfield(response, "stdout")
                count = parseRunTotal(response.stdout);
            else
                count = 0;
            end
            if ~isscalar(count) || ~isfinite(count) || ...
                    count < 0 || count ~= fix(count)
                error("KSSOLV:Matgenlab:Enumlib:ExecutorResult", ...
                    "The executor structure count must be a nonnegative integer.");
            end
        end

        function result = structureFromPoscar(obj, text)
            text = regexprep(char(string(text)), "scale factor", "1");
            text = regexprep(text, "(\d+)-(\d+)", "$1 -$2");
            numberSpecies = numel(obj.index_species);
            if numberSpecies > 118
                error("KSSOLV:Matgenlab:Enumlib:SpeciesCount", ...
                    "Cannot parse more than 118 enumlib species labels.");
            end
            synthetic = strings(1, numberSpecies);
            for index = 1:numberSpecies
                synthetic(index) = ...
                    kssolv.analysis.matgenlab.core.Element. ...
                    from_Z(index).symbol;
            end
            firstWarning = warning( ...
                "off", "KSSOLV:Matgenlab:Poscar:UnknownElements");
            secondWarning = warning( ...
                "off", "KSSOLV:Matgenlab:Poscar:ElementsOverwritten");
            cleanup = onCleanup(@() restoreWarnings( ...
                firstWarning, secondWarning));
            parsed = kssolv.analysis.matgenlab.io.vasp.Poscar.from_str( ...
                text, default_names = synthetic).structure;
            clear cleanup

            newLattice = parsed.lattice;
            sites = cell(1, 0);
            if ~isempty(obj.ordered_sites)
                originalLattice = obj.ordered_sites{1}.lattice;
                ordered = ...
                    kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                    obj.ordered_sites);
                transformation = round( ...
                    newLattice.matrix / originalLattice.matrix);
                ordered = ordered * transformation;
                sites = ordered.sites;
                superLattice = ordered.lattice;
            else
                superLattice = newLattice;
            end

            missingProperties = struct();
            names = fieldnames(obj.structure.site_properties);
            for index = 1:numel(names)
                missingProperties.(names{index}) = [];
            end
            for siteIndex = 1:parsed.num_sites
                symbol = parsed(siteIndex).specie.symbol;
                label = find(synthetic == symbol, 1);
                if isempty(label)
                    error("KSSOLV:Matgenlab:Enumlib:PoscarSpecies", ...
                        "Cannot map enumlib POSCAR species '%s'.", symbol);
                end
                species = obj.index_species{label};
                if isa(species, ...
                        "kssolv.analysis.matgenlab.core.DummySpecies")
                    continue
                end
                sites{end + 1} = ... %#ok<AGROW>
                    kssolv.analysis.matgenlab.core.PeriodicSite( ...
                    species, parsed(siteIndex).frac_coords, superLattice, ...
                    to_unit_cell = true, ...
                    properties = missingProperties); %#ok<AGROW>
            end
            if isempty(sites)
                error("KSSOLV:Matgenlab:Enumlib:EmptyStructure", ...
                    "The enumlib POSCAR contains only vacancies.");
            end
            result = ...
                kssolv.analysis.matgenlab.core.Structure.from_sites(sites);
            result = result.get_sorted_structure();
        end
    end
end

function location = speciesLocation(species, target)
location = 0;
for index = 1:numel(species)
    if species{index} == target
        location = index;
        return
    end
end
end

function sites = flattenGroups(groups)
sites = cell(1, 0);
for index = 1:numel(groups)
    sites = [sites, groups{index}]; %#ok<AGROW>
end
end

function number = spaceGroupNumber(sites, tolerance)
structure = kssolv.analysis.matgenlab.core.Structure.from_sites(sites);
analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure, tolerance);
number = analyzer.get_space_group_number();
end

function denominator = limitedDenominator(value, maximum)
bestError = Inf;
denominator = 1;
for candidate = 1:maximum
    errorValue = abs(value - round(value * candidate) / candidate);
    if errorValue < bestError
        bestError = errorValue;
        denominator = candidate;
    end
end
end

function count = parseRunTotal(output)
lines = splitlines(string(output));
count = 0;
started = false;
for index = 1:numel(lines)
    line = strtrim(lines(index));
    if endsWith(line, "RunTot")
        started = true;
    elseif started && ~isempty(regexp(line, "^\d+\s+.*", "once"))
        tokens = split(line);
        tokens(tokens == "") = [];
        candidate = str2double(tokens(end));
        if isfinite(candidate), count = candidate; end
    end
end
end

function result = normalizeStructures(value)
if isempty(value)
    result = cell(1, 0);
elseif iscell(value)
    result = reshape(value, 1, []);
elseif isa(value, "kssolv.analysis.matgenlab.core.IStructure")
    result = num2cell(reshape(value, 1, []));
else
    error("KSSOLV:Matgenlab:Enumlib:ExecutorResult", ...
        "structures must contain matgenlab periodic structures.");
end
for index = 1:numel(result)
    if ~isa(result{index}, "kssolv.analysis.matgenlab.core.IStructure")
        error("KSSOLV:Matgenlab:Enumlib:ExecutorResult", ...
            "structures must contain matgenlab periodic structures.");
    end
end
end

function result = normalizeTexts(value)
if isempty(value)
    result = cell(1, 0);
elseif ischar(value) || (isstring(value) && isscalar(value))
    result = {char(string(value))};
elseif isstring(value)
    result = cellstr(reshape(value, 1, []));
elseif iscell(value)
    result = reshape(value, 1, []);
else
    error("KSSOLV:Matgenlab:Enumlib:ExecutorResult", ...
        "poscar_texts must be a sequence of text values.");
end
for index = 1:numel(result)
    if ~(ischar(result{index}) || ...
            (isstring(result{index}) && isscalar(result{index})))
        error("KSSOLV:Matgenlab:Enumlib:ExecutorResult", ...
            "poscar_texts must be a sequence of text values.");
    end
end
end

function value = fieldOr(input, name, defaultValue)
if isfield(input, name), value = input.(name);
else, value = defaultValue;
end
end

function restoreWarnings(first, second)
warning(first);
warning(second);
end
