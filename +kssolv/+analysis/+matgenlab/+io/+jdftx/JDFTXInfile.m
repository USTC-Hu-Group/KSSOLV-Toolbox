classdef JDFTXInfile < handle
    %JDFTXINFILE Parsed, validated, serializable JDFTx input command set.
    properties
        params struct = struct()
        tag_names struct = struct()
        tag_order string = strings(0, 1)
        path_parent string = ""
    end
    properties (Dependent)
        structure
    end

    methods
        function obj = JDFTXInfile(params)
            if nargin > 0 && ~isempty(params)
                names = fieldnames(params);
                for idx = 1:numel(names)
                    original = string(names{idx});
                    obj.set(original, params.(names{idx}));
                end
            end
        end

        function value = get(obj, tag, default)
            arguments
                obj
                tag
                default = []
            end
            field = matlab.lang.makeValidName(string(tag));
            if isfield(obj.params, field)
                value = obj.params.(field);
            else
                value = default;
            end
        end

        function set(obj, tag, value)
            tag = string(tag);
            field = matlab.lang.makeValidName(tag);
            obj.params.(field) = obj.normalize_value(tag, value);
            obj.tag_names.(field) = char(tag);
            if ~any(obj.tag_order == tag)
                obj.tag_order(end + 1, 1) = tag;
            end
        end

        function value = has(obj, tag)
            value = isfield(obj.params, matlab.lang.makeValidName(string(tag)));
        end

        function remove(obj, tag)
            tag = string(tag);
            field = matlab.lang.makeValidName(tag);
            if isfield(obj.params, field)
                obj.params = rmfield(obj.params, field);
                obj.tag_names = rmfield(obj.tag_names, field);
                obj.tag_order(obj.tag_order == tag) = [];
            end
        end

        function value = get.structure(obj)
            if obj.has("lattice") && obj.has("ion")
                value = kssolv.analysis.matgenlab.io.jdftx. ...
                    JDFTXStructure.from_jdftxinfile(obj);
            else
                value = [];
            end
        end

        function text = string(obj)
            text = join(string(obj.get_text_list()), newline);
        end

        function text = char(obj)
            text = char(string(obj));
        end

        function result = plus(obj, other)
            if ~isa(other, class(obj))
                error("KSSOLV:Matgenlab:JDFTX:InvalidAddition", ...
                    "JDFTXInfile can only be added to JDFTXInfile.");
            end
            result = obj.copy();
            for idx = 1:numel(other.tag_order)
                tag = other.tag_order(idx);
                if result.has(tag)
                    current = result.get(tag);
                    incoming = other.get(tag);
                    if ~isequaln(current, incoming)
                        error("KSSOLV:Matgenlab:JDFTX:ConflictingTag", ...
                            "Tag '%s' has conflicting values.", tag);
                    end
                else
                    result.set(tag, other.get(tag));
                end
            end
        end

        function result = as_dict(obj, options)
            arguments
                obj
                options.sort_tags (1, 1) logical = true
                options.skip_module_keys (1, 1) logical = false
            end
            result = struct();
            if ~options.skip_module_keys
                result.x_module = "pymatgen.io.jdftx.inputs";
                result.x_class = "JDFTXInfile";
            end
            tags = obj.tag_order;
            if options.sort_tags
                tags = sort(tags);
            end
            for idx = 1:numel(tags)
                tag = tags(idx);
                result.(matlab.lang.makeValidName(tag)) = obj.get(tag);
            end
            result.x_tag_names = obj.tag_names;
            result.x_tag_order = cellstr(obj.tag_order);
        end

        function result = copy(obj)
            result = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile();
            result.params = obj.params;
            result.tag_names = obj.tag_names;
            result.tag_order = obj.tag_order;
            result.path_parent = obj.path_parent;
        end

        function lines = get_text_list(obj)
            tags = obj.tag_order;
            lines = strings(0, 1);
            for idx = 1:numel(tags)
                tag = tags(idx);
                value = obj.get(tag);
                rendered = obj.render_tag(tag, value);
                lines = [lines; rendered(:)]; %#ok<AGROW>
            end
            lines = cellstr(lines);
        end

        function write_file(obj, filename)
            filename = string(filename);
            parent = fileparts(filename);
            if strlength(parent) > 0 && ~isfolder(parent)
                mkdir(parent);
            end
            handle = fopen(filename, "w");
            if handle < 0
                error("KSSOLV:Matgenlab:JDFTX:WriteFailed", ...
                    "Unable to open '%s' for writing.", filename);
            end
            cleanup = onCleanup(@() fclose(handle));
            fprintf(handle, "%s\n", string(obj));
        end

        function result = to_jdftxstructure(~, jdftxinfile, options)
            arguments
                ~
                jdftxinfile
                options.sort_structure (1, 1) logical = false
            end
            result = kssolv.analysis.matgenlab.io.jdftx.JDFTXStructure. ...
                from_jdftxinfile(jdftxinfile, ...
                sort_structure = options.sort_structure);
        end

        function result = to_pmg_structure(obj, jdftxinfile, options)
            arguments
                obj
                jdftxinfile = []
                options.sort_structure (1, 1) logical = false
            end
            if isempty(jdftxinfile)
                jdftxinfile = obj;
            end
            structure_obj = obj.to_jdftxstructure(jdftxinfile, ...
                sort_structure = options.sort_structure);
            result = structure_obj.structure;
        end

        function strip_structure_tags(obj)
            names = ["lattice", "ion", "coords-type", "latt-scale", ...
                "latt-move-scale"];
            for idx = 1:numel(names)
                obj.remove(names(idx));
            end
        end

        function append_tag(obj, tag, value)
            tag = string(tag);
            value = obj.normalize_value(tag, value);
            if ~obj.has(tag)
                obj.set(tag, {value});
                return
            end
            current = obj.get(tag);
            if ~iscell(current)
                current = {current};
            end
            current{end + 1} = value;
            obj.set(tag, current);
        end

        function output = validate_tags(obj, options)
            arguments
                obj
                options.try_auto_type_fix (1, 1) logical = false
                options.error_on_failed_fix (1, 1) logical = true
                options.return_list_rep (1, 1) logical = false
            end
            failures = strings(0, 1);
            for idx = 1:numel(obj.tag_order)
                tag = obj.tag_order(idx);
                tag_obj = kssolv.analysis.matgenlab.io.jdftx. ...
                    get_tag_object_on_val(tag, obj.get(tag));
                [~, valid, fixed] = tag_obj.validate_value_type( ...
                    tag, obj.get(tag), ...
                    try_auto_type_fix = options.try_auto_type_fix);
                if valid
                    obj.set(tag, fixed);
                else
                    failures(end + 1) = tag; %#ok<AGROW>
                end
            end
            if ~isempty(failures) && options.error_on_failed_fix
                error("KSSOLV:Matgenlab:JDFTX:InvalidTags", ...
                    "Invalid values for tags: %s", join(failures, ", "));
            end
            if options.return_list_rep
                output = obj.get_list_representation(obj);
            else
                output = failures;
            end
        end

        function validate_boundaries(obj)
            for idx = 1:numel(obj.tag_order)
                tag = obj.tag_order(idx);
                tag_obj = kssolv.analysis.matgenlab.io.jdftx. ...
                    get_tag_object_on_val(tag, obj.get(tag));
                [valid, message] = tag_obj.validate_value_bounds( ...
                    tag, obj.get(tag));
                if ~valid
                    error("KSSOLV:Matgenlab:JDFTX:Boundary", "%s", message);
                end
            end
        end

        function value = is_comparable_to(obj, other, options)
            arguments
                obj
                other
                options.exclude_tags = {}
                options.exclude_tag_categories = {}
                options.ensure_include_tags = {}
            end
            differing = obj.get_filtered_differing_tags(other, ...
                exclude_tags = options.exclude_tags, ...
                ensure_include_tags = options.ensure_include_tags);
            value = isempty(differing);
        end

        function tags = get_filtered_differing_tags(obj, other, options)
            arguments
                obj
                other
                options.exclude_tags = {}
                options.exclude_tag_categories = {}
                options.ensure_include_tags = {}
            end
            tags = obj.get_differing_tags(other);
            excluded = string(options.exclude_tags);
            included = string(options.ensure_include_tags);
            tags(ismember(tags, excluded) & ~ismember(tags, included)) = [];
        end

        function tags = get_differing_tags(obj, other)
            all_tags = unique([obj.tag_order; other.tag_order], "stable");
            different = false(size(all_tags));
            for idx = 1:numel(all_tags)
                tag = all_tags(idx);
                different(idx) = obj.has(tag) ~= other.has(tag) || ...
                    ~isequaln(obj.get(tag), other.get(tag));
            end
            tags = all_tags(different);
        end

        function tags = get_differing_tags_from(obj, other)
            tags = obj.get_differing_tags(other);
            tags = tags(arrayfun(@(x) obj.has(x), tags));
        end
    end

    methods (Static)
        function obj = from_dict(input, options)
            arguments
                input struct
                options.validate_value_boundaries (1, 1) logical = true
            end
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile();
            metadata = ["x_module", "x_class", "x_tag_names", "x_tag_order"];
            if isfield(input, "x_tag_names")
                obj.tag_names = input.x_tag_names;
            end
            if isfield(input, "x_tag_order")
                ordered = string(input.x_tag_order);
            else
                ordered = string(setdiff(fieldnames(input), metadata, "stable"));
            end
            for idx = 1:numel(ordered)
                field = matlab.lang.makeValidName(ordered(idx));
                if isfield(input, field)
                    if isfield(obj.tag_names, field)
                        tag = string(obj.tag_names.(field));
                    else
                        tag = ordered(idx);
                    end
                    obj.set(tag, input.(field));
                end
            end
            if options.validate_value_boundaries
                obj.validate_boundaries();
            end
        end

        function obj = from_file(filename, options)
            arguments
                filename
                options.dont_require_structure (1, 1) logical = false
                options.sort_tags (1, 1) logical = true
                options.assign_path_parent (1, 1) logical = true
                options.validate_value_boundaries (1, 1) logical = true
            end
            filename = string(filename);
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:JDFTX:MissingFile", ...
                    "Input file '%s' does not exist.", filename);
            end
            parent = string(fileparts(filename));
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile.from_str( ...
                fileread(filename), ...
                dont_require_structure = options.dont_require_structure, ...
                sort_tags = options.sort_tags, path_parent = parent, ...
                validate_value_boundaries = options.validate_value_boundaries);
            if options.assign_path_parent
                obj.path_parent = parent;
            end
        end

        function obj = from_structure(structure, options)
            arguments
                structure struct
                options.selective_dynamics = []
                options.write_cart_coords (1, 1) logical = false
            end
            jstructure = kssolv.analysis.matgenlab.io.jdftx. ...
                JDFTXStructure(structure, ...
                selective_dynamics = options.selective_dynamics, ...
                write_cart_coords = options.write_cart_coords);
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile. ...
                from_jdftxstructure(jstructure);
        end

        function obj = from_jdftxstructure(jdftxstructure)
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile. ...
                from_str(jdftxstructure.get_str());
        end

        function obj = from_str(input, options)
            arguments
                input
                options.dont_require_structure (1, 1) logical = false
                options.sort_tags (1, 1) logical = true
                options.path_parent string = ""
                options.validate_value_boundaries (1, 1) logical = true
            end
            commands = gather_commands(string(input));
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile();
            obj.path_parent = options.path_parent;
            for idx = 1:numel(commands)
                line = strtrim(commands(idx));
                tokens = regexp(line, "\s+", "split");
                tag = tokens(1);
                raw = strtrim(extractAfter(line, strlength(tag)));
                if tag == "include" && strlength(options.path_parent) > 0
                    included = fullfile(options.path_parent, raw);
                    child = kssolv.analysis.matgenlab.io.jdftx. ...
                        JDFTXInfile.from_file(included, ...
                        dont_require_structure = true, ...
                        validate_value_boundaries = false);
                    obj = obj + child;
                    continue
                end
                value = parse_tag_value(tag, raw);
                if any(tag == ["ion", "ion-species", "dump", ...
                        "fluid-solvent", "symmetry-matrix"])
                    obj.append_tag(tag, value);
                else
                    obj.set(tag, value);
                end
            end
            if options.sort_tags
                obj.tag_order = sort(obj.tag_order);
            end
            if ~options.dont_require_structure && ...
                    ~(obj.has("lattice") && obj.has("ion"))
                error("KSSOLV:Matgenlab:JDFTX:MissingStructure", ...
                    "JDFTx input requires lattice and ion tags.");
            end
            if options.validate_value_boundaries
                obj.validate_boundaries();
            end
        end

        function result = get_list_representation(jdftxinfile)
            result = jdftxinfile.copy();
        end

        function result = get_dict_representation(jdftxinfile)
            result = jdftxinfile.copy();
        end
    end

    methods (Access = private)
        function value = normalize_value(~, tag, value)
            if ischar(value)
                value = string(value);
            end
            if isstring(value) && isscalar(value)
                value = parse_tag_value(tag, value);
            elseif isnumeric(value) && tag == "lattice" && numel(value) == 9
                value = reshape(double(value), 3, 3);
            end
        end

        function lines = render_tag(~, tag, value)
            if iscell(value)
                lines = strings(numel(value), 1);
                for idx = 1:numel(value)
                    lines(idx) = render_single(tag, value{idx});
                end
            else
                lines = render_single(tag, value);
            end
        end
    end
end

function commands = gather_commands(input)
lines = split(replace(input, sprintf("\r\n"), newline), newline);
commands = strings(0, 1);
buffer = "";
for idx = 1:numel(lines)
    line = strtrim(lines(idx));
    if strlength(line) == 0 || startsWith(line, "#")
        continue
    end
    comment = strfind(line, "#");
    if ~isempty(comment)
        line = strtrim(extractBefore(line, comment(1)));
    end
    continued = endsWith(line, "\");
    if continued
        line = strtrim(extractBefore(line, strlength(line)));
    end
    buffer = strtrim(buffer + " " + line);
    if ~continued
        commands(end + 1, 1) = buffer; %#ok<AGROW>
        buffer = "";
    end
end
if strlength(buffer) > 0
    commands(end + 1, 1) = buffer;
end
end

function value = parse_tag_value(tag, raw)
tag = string(tag);
raw = strtrim(string(raw));
tokens = regexp(raw, "\s+", "split");
tokens = tokens(strlength(tokens) > 0);
numbers = str2double(tokens);
all_numeric = ~isempty(tokens) && all(~isnan(numbers));
if tag == "dump-only" && isempty(tokens)
    value = true;
elseif isscalar(tokens) && any(lower(tokens) == ["yes", "no"])
    value = lower(tokens) == "yes";
elseif tag == "lattice" && all_numeric && numel(numbers) == 9
    value = reshape(numbers, 3, 3).';
elseif tag == "ion"
    value = parse_ion(tokens);
elseif tag == "dump"
    value = kssolv.analysis.matgenlab.io.jdftx. ...
        get_dump_tag_container().read(tag, raw);
elseif any(tag == ["elec-cutoff", "elec-smearing", "kpoint-folding", ...
        "latt-scale", "latt-move-scale", "kpoint", ...
        "coulomb-truncation-embed"]) && all_numeric
    value = numbers;
elseif all_numeric && isscalar(numbers)
    value = numbers(1);
elseif all_numeric
    value = numbers;
else
    value = raw;
end
end

function value = parse_ion(tokens)
if numel(tokens) < 5
    error("KSSOLV:Matgenlab:JDFTX:InvalidIon", ...
        "Ion tag requires species, three coordinates, and move scale.");
end
value = struct("species_id", tokens(1), ...
    "x0", str2double(tokens(2)), "x1", str2double(tokens(3)), ...
    "x2", str2double(tokens(4)));
cursor = 5;
if tokens(cursor) == "v"
    value.v = struct("vx0", str2double(tokens(cursor + 1)), ...
        "vx1", str2double(tokens(cursor + 2)), ...
        "vx2", str2double(tokens(cursor + 3)));
    cursor = cursor + 4;
end
value.moveScale = str2double(tokens(cursor));
if cursor < numel(tokens)
    value.constraint_type = tokens(cursor + 1);
    if cursor + 4 <= numel(tokens)
        value.d0 = str2double(tokens(cursor + 2));
        value.d1 = str2double(tokens(cursor + 3));
        value.d2 = str2double(tokens(cursor + 4));
    end
end
end

function text = render_single(tag, value)
tag = string(tag);
if isstruct(value)
    if tag == "ion"
        pieces = [string(value.species_id), ...
            compose("%.12f", [value.x0, value.x1, value.x2])];
        if isfield(value, "v")
            pieces = [pieces, "v", compose("%.12f", ...
                [value.v.vx0, value.v.vx1, value.v.vx2])];
        end
        pieces(end + 1) = string(value.moveScale);
        if isfield(value, "constraint_type")
            pieces = [pieces, string(value.constraint_type), ...
                compose("%.12f", [value.d0, value.d1, value.d2])];
        end
        text = tag + " " + join(pieces, " ");
    elseif tag == "dump"
        frequencies = fieldnames(value);
        pieces = strings(0, 1);
        for idx = 1:numel(frequencies)
            variables = fieldnames(value.(frequencies{idx}));
            pieces(end + 1) = string(frequencies{idx}) + " " + ...
                join(string(variables), " "); %#ok<AGROW>
        end
        text = tag + " " + join(pieces, " ");
    else
        text = tag + " " + string(jsonencode(value));
    end
elseif isnumeric(value)
    if tag == "lattice" && isequal(size(value), [3, 3])
        rows = strings(3, 1);
        for idx = 1:3
            rows(idx) = join(compose("%.12g", value(idx, :)), " ");
        end
        text = "lattice \" + newline + " " + ...
            join(rows, " \" + newline + " ");
    else
        text = tag + " " + join(compose("%.16g", value(:).'), " ");
    end
elseif islogical(value)
    if tag == "dump-only" && value
        text = tag;
    elseif value
        text = tag + " yes";
    else
        text = tag + " no";
    end
else
    text = tag + " " + string(value);
end
end
