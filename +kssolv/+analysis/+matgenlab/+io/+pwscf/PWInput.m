classdef PWInput
    %PWINPUT Native Quantum ESPRESSO pw.x input reader and writer.
    properties
        structure
        pseudo
        sections (1,1) struct
        kpoints_mode (1,1) string = "automatic"
        kpoints_grid = [1, 1, 1]
        kpoints_shift = [0, 0, 0]
        format_options (1,1) struct
    end

    methods
        function obj = PWInput(structure, pseudo, control, system, ...
                electrons, ions, cellSection, kpointsMode, kpointsGrid, ...
                kpointsShift, formatOptions)
            if nargin < 2, pseudo = []; end
            if nargin < 3 || isempty(control) || ...
                    (isstruct(control) && isempty(fieldnames(control)))
                control = struct("calculation", "scf");
            end
            if nargin < 4 || isempty(system), system = struct(); end
            if nargin < 5 || isempty(electrons), electrons = struct(); end
            if nargin < 6 || isempty(ions), ions = struct(); end
            if nargin < 7 || isempty(cellSection), cellSection = struct(); end
            if nargin < 8 || isempty(kpointsMode), kpointsMode = "automatic"; end
            if nargin < 9 || isempty(kpointsGrid), kpointsGrid = [1, 1, 1]; end
            if nargin < 10 || isempty(kpointsShift), kpointsShift = [0, 0, 0]; end
            if nargin < 11 || isempty(formatOptions), formatOptions = struct(); end

            obj.structure = structure;
            obj.pseudo = normalizeMap(pseudo);
            obj.sections = struct("control", control, "system", system, ...
                "electrons", electrons, "ions", ions, "cell", cellSection);
            obj.kpoints_mode = string(kpointsMode);
            obj.kpoints_grid = double(kpointsGrid);
            obj.kpoints_shift = double(kpointsShift);
            defaults = struct("indent", 2, ...
                "kpoints_crystal_b_indent", 1, "coord_decimals", 6, ...
                "atomic_mass_decimals", 4, "kpoints_grid_decimals", 4);
            obj.format_options = mergeStruct(defaults, formatOptions);
            obj.validatePseudo();
        end

        function value = string(obj)
            value = obj.to_string();
        end

        function value = char(obj)
            value = char(obj.to_string());
        end

        function value = to_string(obj)
            indent = string(repmat(' ', 1, obj.format_options.indent));
            [descriptions, propertyMode] = obj.siteDescriptions();
            lines = strings(0, 1);
            sectionNames = ["control", "system", "electrons", "ions", "cell"];
            for sectionName = sectionNames
                lines(end + 1) = "&" + upper(sectionName); %#ok<AGROW>
                section = obj.sections.(sectionName);
                names = sort(string(fieldnames(section)));
                for name = reshape(names, 1, [])
                    item = section.(name);
                    if isvector(item) && numel(item) > 1 && ...
                            (isnumeric(item) || islogical(item))
                        limit = min(numel(item), descriptions.Count);
                        for index = 1:limit
                            lines(end + 1) = indent + name + "(" + index + ...
                                ") = " + formatValue(item(index)); %#ok<AGROW>
                        end
                    else
                        lines(end + 1) = indent + name + " = " + ...
                            formatValue(item); %#ok<AGROW>
                    end
                end
                if sectionName == "system"
                    if ~isfield(section, "ibrav")
                        lines(end + 1) = indent + "ibrav = 0"; %#ok<AGROW>
                    end
                    if ~isfield(section, "nat")
                        lines(end + 1) = indent + "nat = " + ...
                            obj.structure.num_sites; %#ok<AGROW>
                    end
                    if ~isfield(section, "ntyp")
                        lines(end + 1) = indent + "ntyp = " + ...
                            descriptions.Count; %#ok<AGROW>
                    end
                end
                lines(end + 1) = "/"; %#ok<AGROW>
                first = numel(lines) - countSectionLines(lines) + 1;
                if first + 1 <= numel(lines) - 1
                    lines(first+1:numel(lines)-1) = ...
                        lines(first+1:numel(lines)-1) + ",";
                end
            end

            lines(end + 1) = "ATOMIC_SPECIES";
            names = sort(string(descriptions.keys));
            for name = reshape(names, 1, [])
                entry = descriptions(char(name));
                symbol = regexp(char(name), "[A-Z][a-z]?", "match", "once");
                element = kssolv.analysis.matgenlab.core.Element(symbol);
                mass = sprintf("%.*f", ...
                    obj.format_options.atomic_mass_decimals, ...
                    double(element.atomic_mass));
                lines(end + 1) = indent + name + "  " + mass + ...
                    " " + string(entry.pseudo); %#ok<AGROW>
            end

            lines(end + 1) = "ATOMIC_POSITIONS crystal";
            decimals = obj.format_options.coord_decimals;
            for index = 1:obj.structure.num_sites
                site = obj.structure(index);
                if propertyMode
                    name = findDescription(descriptions, site.site_properties);
                else
                    name = site.species_string;
                end
                coords = compose("%." + decimals + "f", ...
                    site.frac_coords);
                lines(end + 1) = indent + name + " " + ...
                    join(coords, " "); %#ok<AGROW>
            end

            lines(end + 1) = "K_POINTS " + obj.kpoints_mode;
            if obj.kpoints_mode == "automatic"
                values = [reshape(obj.kpoints_grid, 1, []), ...
                    reshape(obj.kpoints_shift, 1, [])];
                lines(end + 1) = indent + ...
                    join(string(round(values)), " ");
            elseif obj.kpoints_mode == "crystal_b"
                kIndent = string(repmat(' ', 1, ...
                    obj.format_options.kpoints_crystal_b_indent));
                lines(end + 1) = kIndent + size(obj.kpoints_grid, 1);
                decimals = obj.format_options.kpoints_grid_decimals;
                for index = 1:size(obj.kpoints_grid, 1)
                    values = compose("%." + decimals + "f", ...
                        obj.kpoints_grid(index, :));
                    lines(end + 1) = kIndent + join(values, " "); %#ok<AGROW>
                end
            end

            lines(end + 1) = "CELL_PARAMETERS angstrom";
            decimals = obj.format_options.coord_decimals;
            for index = 1:3
                values = compose("%." + decimals + "f", ...
                    obj.structure.lattice.matrix(index, :));
                lines(end + 1) = indent + join(values, " "); %#ok<AGROW>
            end
            value = join(lines, newline);
        end

        function value = as_dict(obj)
            value = struct("structure", obj.structure.as_dict(), ...
                "pseudo", obj.pseudo, "sections", obj.sections, ...
                "kpoints_mode", obj.kpoints_mode, ...
                "kpoints_grid", obj.kpoints_grid, ...
                "kpoints_shift", obj.kpoints_shift, ...
                "format_options", obj.format_options);
        end

        function value = asDict(obj), value = obj.as_dict(); end

        function write_file(obj, filename)
            fileId = fopen(filename, "w", "n", "UTF-8");
            if fileId < 0
                error("KSSOLV:Matgenlab:PWSCF:Open", ...
                    "Unable to open '%s' for writing.", string(filename));
            end
            cleanup = onCleanup(@() fclose(fileId));
            fwrite(fileId, char(obj), "char");
            clear cleanup
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.pwscf.PWInput( ...
                kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure), ...
                value.pseudo, value.sections.control, ...
                value.sections.system, value.sections.electrons, ...
                value.sections.ions, value.sections.cell, ...
                value.kpoints_mode, value.kpoints_grid, ...
                value.kpoints_shift, value.format_options);
        end

        function obj = from_file(filename)
            filename = string(filename);
            if endsWith(lower(filename), ".gz")
                folder = string(tempname);
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                paths = gunzip(filename, folder);
                text = fileread(paths{1});
                clear cleanup
            else
                text = fileread(filename);
            end
            obj = kssolv.analysis.matgenlab.io.pwscf.PWInput.from_str(text);
        end

        function obj = from_str(input)
            raw = splitlines(string(input));
            raw = regexprep(raw, "!.*$", "");
            raw = strip(raw, "right");
            raw = raw(strlength(strtrim(raw)) > 0);
            sections = struct("control", struct(), "system", struct(), ...
                "electrons", struct(), "ions", struct(), "cell", struct());
            pseudo = containers.Map("KeyType", "char", "ValueType", "any");
            lattice = zeros(0, 3);
            species = strings(0, 1);
            coords = zeros(0, 3);
            mode = "";
            section = "";
            structureUnits = "crystal";
            kpointsMode = "automatic";
            kpointsGrid = [1, 1, 1];
            kpointsShift = [0, 0, 0];
            formatOptions = struct();
            crystalCount = -1;
            crystalRows = zeros(0, 3);

            for line = reshape(raw, 1, [])
                trimmed = strtrim(line);
                if startsWith(trimmed, "&")
                    mode = "section";
                    section = lower(extractAfter(trimmed, 1));
                    continue
                elseif trimmed == "/"
                    mode = "";
                    continue
                elseif startsWith(trimmed, "ATOMIC_SPECIES")
                    mode = "pseudo"; continue
                elseif startsWith(trimmed, "ATOMIC_POSITIONS")
                    parts = split(trimmed);
                    structureUnits = parts(2);
                    mode = "positions"; continue
                elseif startsWith(trimmed, "CELL_PARAMETERS")
                    mode = "lattice"; continue
                elseif startsWith(trimmed, "K_POINTS")
                    parts = split(trimmed);
                    kpointsMode = parts(2);
                    mode = "kpoints";
                    crystalCount = -1;
                    continue
                elseif startsWith(trimmed, "OCCUPATIONS")
                    mode = "occupations"; continue
                end
                spaces = strlength(line) - strlength(strip(line, "left"));
                if mode ~= "kpoints" || kpointsMode == "automatic"
                    formatOptions.indent = double(spaces);
                end
                switch mode
                    case "section"
                        indexed = regexp(char(trimmed), ...
                            "^(\w+)\((\d+)\)\s*=\s*(.*?)[,\s]*$", ...
                            "tokens", "once");
                        if isempty(indexed)
                            token = regexp(char(trimmed), ...
                                "^(\w+)\s*=\s*(.*?)[,\s]*$", ...
                                "tokens", "once");
                            if isempty(token), continue; end
                            key = string(token{1});
                            rawValue = token{2};
                        else
                            key = string(indexed{1});
                            rawValue = indexed{3};
                        end
                        value = kssolv.analysis.matgenlab.io.pwscf. ...
                            PWInput.proc_val(key, rawValue);
                        if isempty(indexed)
                            sections.(section).(key) = value;
                        else
                            index = str2double(indexed{2});
                            if isfield(sections.(section), key)
                                values = sections.(section).(key);
                            else
                                values = zeros(1, 20);
                            end
                            values(index) = value;
                            sections.(section).(key) = values;
                        end
                    case "pseudo"
                        token = regexp(char(trimmed), ...
                            "^([A-Za-z][A-Za-z0-9+\-]*)\s+\S+\s+(.+)$", ...
                            "tokens", "once");
                        if ~isempty(token)
                            pseudo(token{1}) = string(strtrim(token{2}));
                        end
                    case "positions"
                        token = regexp(char(trimmed), ...
                            "^([A-Za-z][A-Za-z0-9+\-]*)\s+" + ...
                            "([-+0-9.eEdD]+)\s+([-+0-9.eEdD]+)\s+" + ...
                            "([-+0-9.eEdD]+)", "tokens", "once");
                        if ~isempty(token)
                            species(end + 1) = string(token{1}); %#ok<AGROW>
                            coords(end + 1, :) = parseNumbers(token(2:4)); %#ok<AGROW>
                            formatOptions.coord_decimals = max( ...
                                fieldOr(formatOptions, "coord_decimals", 0), ...
                                maxDecimals(token(2:4)));
                        end
                    case "lattice"
                        token = regexp(char(trimmed), ...
                            "^([-+0-9.eEdD]+)\s+([-+0-9.eEdD]+)\s+" + ...
                            "([-+0-9.eEdD]+)", "tokens", "once");
                        if ~isempty(token)
                            lattice(end + 1, :) = parseNumbers(token); %#ok<AGROW>
                            formatOptions.coord_decimals = max( ...
                                fieldOr(formatOptions, "coord_decimals", 0), ...
                                maxDecimals(token));
                        end
                    case "kpoints"
                        numbers = sscanf(char(trimmed), "%f").';
                        if kpointsMode == "automatic" && numel(numbers) >= 6
                            kpointsGrid = numbers(1:3);
                            kpointsShift = numbers(4:6);
                        elseif kpointsMode == "crystal_b"
                            formatOptions.kpoints_crystal_b_indent = ...
                                double(spaces);
                            if crystalCount < 0
                                crystalCount = numbers(1);
                            elseif size(crystalRows, 1) < crystalCount
                                crystalRows(end + 1, :) = numbers(1:3); %#ok<AGROW>
                                formatOptions.kpoints_grid_decimals = ...
                                    max(fieldOr(formatOptions, ...
                                    "kpoints_grid_decimals", 0), ...
                                    maxDecimals(regexp(char(trimmed), ...
                                    "\S+", "match")));
                            end
                        end
                end
            end
            if kpointsMode == "crystal_b", kpointsGrid = crystalRows; end
            cartesian = lower(structureUnits) == "angstrom";
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, cellstr(species), coords, ...
                coords_are_cartesian = cartesian);
            obj = kssolv.analysis.matgenlab.io.pwscf.PWInput( ...
                structure, pseudo, sections.control, sections.system, ...
                sections.electrons, sections.ions, sections.cell, ...
                kpointsMode, kpointsGrid, kpointsShift, formatOptions);
        end

        function value = proc_val(key, input)
            key = string(key);
            input = strtrim(string(input));
            boolKeys = ["wf_collect", "tstress", "tprnfor", ...
                "lkpoint_dir", "tefield", "dipfield", "lelfield", ...
                "lorbm", "lberry", "lfcpopt", "monopole", "nosym", ...
                "nosym_evc", "noinv", "no_t_rev", "force_symmorphic", ...
                "use_all_frac", "one_atom_occupations", ...
                "starting_spin_angle", "noncolin", ...
                "x_gamma_extrapolation", "lda_plus_u", "lspinorb", ...
                "london", "ts_vdw_isolated", "xdm", "uniqueb", ...
                "rhombohedral", "realxz", "block", ...
                "scf_must_converge", "adaptive_thr", "diago_full_acc", ...
                "tqr", "remove_rigid_rot", "refold_pos"];
            intKeys = ["nstep", "iprint", "nberrycyc", "gdir", ...
                "nppstr", "ibrav", "nat", "ntyp", "nbnd", "nr1", ...
                "nr2", "nr3", "nr1s", "nr2s", "nr3s", "nspin", ...
                "nqx1", "nqx2", "nqx3", "lda_plus_u_kind", "edir", ...
                "report", "esm_nfit", "space_group", "origin_choice", ...
                "electron_maxstep", "mixing_ndim", "mixing_fixed_ns", ...
                "ortho_para", "diago_cg_maxiter", "diago_david_ndim", ...
                "nraise", "bfgs_ndim", "if_pos", "nks", "nk1", ...
                "nk2", "nk3", "sk1", "sk2", "sk3", "nconstr"];
            floatKeys = ["etot_conv_thr", "forc_conv_thr", "conv_thr", ...
                "Hubbard_U", "Hubbard_J0", "degauss", ...
                "starting_magnetization"];
            lowerInput = lower(input);
            if any(key == boolKeys)
                if lowerInput == ".true.", value = true; return; end
                if lowerInput == ".false.", value = false; return; end
            end
            numericText = replace(lowerInput, "d", "e");
            if any(key == intKeys)
                token = regexp(char(numericText), "^-?\d+", ...
                    "match", "once");
                if ~isempty(token), value = str2double(token); return; end
            elseif any(key == floatKeys)
                token = regexp(char(numericText), ...
                    "^-?\d*\.?\d*(?:e-?\d+)?", "match", "once");
                if ~isempty(token), value = str2double(token); return; end
            end
            number = str2double(numericText);
            if ~isnan(number), value = number; return; end
            if contains(lowerInput, "true"), value = true; return; end
            if contains(lowerInput, "false"), value = false; return; end
            quoted = regexp(char(input), '^["''](.+)["'']$', ...
                "tokens", "once");
            if ~isempty(quoted), value = string(quoted{1}); else, value = []; end
        end
    end

    methods (Access = private)
        function validatePseudo(obj)
            if isempty(obj.pseudo)
                for index = 1:obj.structure.num_sites
                    if ~isfield(obj.structure(index).site_properties, "pseudo")
                        throw(kssolv.analysis.matgenlab.io.pwscf. ...
                            PWInputError("Missing " + ...
                            obj.structure(index).species_string + ...
                            " in pseudo specification!"));
                    end
                end
                return
            end
            species = unique(string(cellfun(@(site) site.species_string, ...
                obj.structure.sites, "UniformOutput", false)));
            for name = reshape(species, 1, [])
                if ~isKey(obj.pseudo, char(name))
                    throw(kssolv.analysis.matgenlab.io.pwscf. ...
                        PWInputError("Missing " + name + ...
                        " in pseudo specification!"));
                end
            end
        end

        function [descriptions, propertyMode] = siteDescriptions(obj)
            descriptions = containers.Map("KeyType", "char", ...
                "ValueType", "any");
            propertyMode = isempty(obj.pseudo);
            if ~propertyMode
                names = obj.pseudo.keys;
                for index = 1:numel(names)
                    descriptions(names{index}) = ...
                        struct("pseudo", obj.pseudo(names{index}));
                end
                return
            end
            counter = 0;
            for index = 1:obj.structure.num_sites
                site = obj.structure(index);
                name = findDescription(descriptions, site.site_properties);
                if strlength(name) == 0
                    counter = counter + 1;
                    name = string(site.specie.symbol) + counter;
                    descriptions(char(name)) = site.site_properties;
                end
            end
        end
    end
end

function map = normalizeMap(value)
if isa(value, "containers.Map")
    map = value;
elseif isempty(value)
    map = [];
elseif isstruct(value)
    map = containers.Map("KeyType", "char", "ValueType", "any");
    names = fieldnames(value);
    for index = 1:numel(names), map(names{index}) = value.(names{index}); end
else
    error("KSSOLV:Matgenlab:PWSCF:PseudoType", ...
        "pseudo must be a struct, containers.Map, or empty.");
end
end

function result = mergeStruct(first, second)
result = first;
names = fieldnames(second);
for index = 1:numel(names), result.(names{index}) = second.(names{index}); end
end

function value = formatValue(input)
if ischar(input) || isstring(input)
    value = "'" + string(input) + "'";
elseif islogical(input)
    if input, value = ".TRUE."; else, value = ".FALSE."; end
elseif isnumeric(input) && isscalar(input)
    if input == fix(input)
        value = string(sprintf("%.0f", input));
    else
        value = replace(string(sprintf("%.15g", input)), "e", "d");
    end
else
    value = string(input);
end
end

function count = countSectionLines(lines)
count = 0;
for index = numel(lines):-1:1
    count = count + 1;
    if startsWith(lines(index), "&"), break; end
end
end

function name = findDescription(descriptions, properties)
name = "";
names = sort(string(descriptions.keys));
for candidate = reshape(names, 1, [])
    entry = descriptions(char(candidate));
    if isequal(entry, properties), name = candidate; end
end
end

function values = parseNumbers(tokens)
values = cellfun(@(item) str2double(regexprep(item, "[dD]", "e")), tokens);
end

function value = maxDecimals(tokens)
value = 0;
for index = 1:numel(tokens)
    token = string(tokens{index});
    matched = regexp(char(token), "\.(\d+)", "tokens", "once");
    if ~isempty(matched), value = max(value, strlength(matched{1})); end
end
end

function value = fieldOr(input, name, fallback)
if isfield(input, name), value = input.(name); else, value = fallback; end
end
