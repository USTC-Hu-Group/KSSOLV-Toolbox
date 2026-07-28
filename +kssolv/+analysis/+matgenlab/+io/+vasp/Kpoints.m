classdef Kpoints
    %KPOINTS Read, generate, serialize, and write VASP KPOINTS files.
    %
    % Native MATLAB port of pymatgen-core v2026.7.24
    % pymatgen.io.vasp.inputs.Kpoints.

    properties
        comment (1,1) string = "Default gamma"
        num_kpts (1,1) double = 0
        kpts_shift (1,3) double = [0, 0, 0]
        kpts_weights = []
        coord_type = []
        labels = []
        tet_number (1,1) double = 0
        tet_weight (1,1) double = 0
        tet_connections = {}
        genvec1 = []
        genvec2 = []
        genvec3 = []
        shift = []
    end

    properties (Dependent)
        kpts
        style
    end

    properties (Access = private)
        kpts_ = [1, 1, 1]
        style_ (1,1) string = "Gamma"
        preserveIntegerCoordinates_ (1,1) logical = false
    end

    properties (Constant)
        supported_modes = "kssolv.analysis.matgenlab.io.vasp.KpointsSupportedModes"
    end

    methods
        function obj = Kpoints(varargin)
            options = struct("comment","Default gamma","num_kpts",0, ...
                "style","Gamma","kpts",[1,1,1], ...
                "kpts_shift",[0,0,0],"kpts_weights",[], ...
                "coord_type",[],"labels",[],"tet_number",0, ...
                "tet_weight",0,"tet_connections",{{}});
            names = string(fieldnames(options)).';
            if ~isempty(varargin)
                named = (ischar(varargin{1}) || isstring(varargin{1})) && ...
                    any(string(varargin{1}) == names);
                if named
                    if mod(numel(varargin), 2) ~= 0
                        error("KSSOLV:Matgenlab:Kpoints:Options", ...
                            "Named options must be supplied in pairs.");
                    end
                    for index = 1:2:numel(varargin)
                        name = string(varargin{index});
                        if ~any(name == names)
                            error("KSSOLV:Matgenlab:Kpoints:Option", ...
                                "Unknown Kpoints option '%s'.", name);
                        end
                        options.(char(name)) = varargin{index + 1};
                    end
                else
                    if numel(varargin) > numel(names)
                        error("KSSOLV:Matgenlab:Kpoints:Arguments", ...
                            "Too many positional arguments.");
                    end
                    for index = 1:numel(varargin)
                        options.(char(names(index))) = varargin{index};
                    end
                end
            end
            validateattributes(options.num_kpts, {'numeric'}, ...
                {'scalar','integer'});
            validateattributes(options.tet_number, {'numeric'}, ...
                {'scalar','integer'});
            validateattributes(options.kpts_shift, {'numeric'}, ...
                {'size',[1,3]});
            if options.num_kpts > 0 && isempty(options.labels) && ...
                    isempty(options.kpts_weights)
                error("KSSOLV:Matgenlab:Kpoints:ExplicitMetadata", ...
                    "Explicit or line-mode kpoints require labels or weights.");
            end
            obj.comment = string(options.comment);
            obj.num_kpts = options.num_kpts;
            obj.kpts = options.kpts;
            obj.style = options.style;
            obj.kpts_shift = options.kpts_shift;
            obj.kpts_weights = options.kpts_weights;
            obj.coord_type = options.coord_type;
            if ~isempty(options.labels)
                obj.labels = reshape(string(options.labels), 1, []);
            end
            obj.tet_number = options.tet_number;
            obj.tet_weight = options.tet_weight;
            obj.tet_connections = options.tet_connections;
        end

        function value = get.kpts(obj), value = obj.kpts_; end

        function obj = set.kpts(obj, value)
            if iscell(value)
                sizes = cellfun(@numel, value);
                if isempty(value) || any(~ismember(sizes, [1, 3])) || ...
                        numel(unique(sizes)) > 1
                    error("KSSOLV:Matgenlab:Kpoints:InvalidKpoint", ...
                        "Each Kpoint must contain one or three numeric values.");
                end
                value = vertcat(value{:});
            end
            if ~isnumeric(value) || isempty(value)
                error("KSSOLV:Matgenlab:Kpoints:InvalidKpoint", ...
                    "Kpoints must be numeric.");
            end
            if isvector(value)
                value = reshape(value, 1, []);
            end
            if ~ismember(size(value, 2), [1, 3])
                error("KSSOLV:Matgenlab:Kpoints:InvalidKpoint", ...
                    "Each Kpoint must contain one or three values.");
            end
            obj.kpts_ = value;
        end

        function value = get.style(obj), value = obj.style_; end

        function obj = set.style(obj, value)
            value = kssolv.analysis.matgenlab.io.vasp. ...
                KpointsSupportedModes.from_str(value);
            if any(value == ["Automatic", "Gamma", "Monkhorst"]) && ...
                    size(obj.kpts_, 1) > 1
                error("KSSOLV:Matgenlab:Kpoints:AutomaticRows", ...
                    "Automatic KPOINTS modes permit only one division row.");
            end
            obj.style_ = value;
        end

        function tf = eq(obj, other)
            tf = isa(other, "kssolv.analysis.matgenlab.io.vasp.Kpoints") && ...
                isequaln(obj.as_dict(), other.as_dict());
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end

        function output = char(obj)
            lines = [obj.comment; string(obj.num_kpts); obj.style_];
            initial = lower(extractBefore(obj.style_, 2));
            if initial == "l"
                lines(end + 1) = string(obj.coord_type);
            end
            for index = 1:size(obj.kpts_, 1)
                if any(initial == ["a", "g", "m"])
                    line = strjoin(string(round(obj.kpts_(index, :))), " ");
                else
                    if obj.preserveIntegerCoordinates_
                        line = strjoin(arrayfun(@obj.formatCompactFloat, ...
                            obj.kpts_(index, :)), " ");
                    else
                        line = strjoin(arrayfun(@obj.formatFloat, ...
                            obj.kpts_(index, :)), " ");
                    end
                end
                if initial == "l"
                    if ~isempty(obj.labels)
                        line = line + " ! " + obj.labels(index);
                    end
                    if mod(index, 2) == 0, line = line + newline; end
                elseif obj.num_kpts > 0 && ~isempty(obj.kpts_weights)
                    line = line + " " + ...
                        string(fix(obj.kpts_weights(index)));
                    if ~isempty(obj.labels)
                        label = obj.labels(index);
                        if ismissing(label), label = "None"; end
                        line = line + " " + label;
                    end
                end
                lines(end + 1) = line; %#ok<AGROW>
            end
            if ~any(initial == ["l", "a", "g", "m"]) && obj.tet_number > 0
                lines(end + 1) = "Tetrahedron";
                lines(end + 1) = obj.tet_number + " " + ...
                    sprintf("%.6f", obj.tet_weight);
                for index = 1:numel(obj.tet_connections)
                    entry = obj.tet_connections{index};
                    lines(end + 1) = strjoin(string([entry{1}, entry{2}]), " "); %#ok<AGROW>
                end
            end
            if obj.num_kpts <= 0 && any(obj.kpts_shift ~= 0)
                lines(end + 1) = strjoin(arrayfun(@obj.formatShift, ...
                    obj.kpts_shift), " ");
            end
            output = char(strjoin(lines, newline) + newline);
        end

        function output = string(obj), output = string(char(obj)); end

        function write_file(obj, filename)
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, char(obj));
        end

        function output = copy(obj)
            output = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                from_dict(obj.as_dict());
        end

        function output = as_dict(obj)
            output = struct();
            output.x_module = "pymatgen.io.vasp.inputs";
            output.x_class = "Kpoints";
            output.comment = obj.comment;
            output.nkpoints = obj.num_kpts;
            output.generation_style = obj.style_;
            output.kpoints = obj.kpts_;
            output.usershift = obj.kpts_shift;
            output.kpts_weights = obj.kpts_weights;
            output.coord_type = obj.coord_type;
            output.labels = obj.labels;
            output.tet_number = obj.tet_number;
            output.tet_weight = obj.tet_weight;
            output.tet_connections = obj.tet_connections;
            for name = ["genvec1", "genvec2", "genvec3", "shift"]
                if ~isempty(obj.(name)), output.(name) = obj.(name); end
            end
        end
    end

    methods (Static)
        function obj = automatic(subdivisions, options)
            arguments
                subdivisions (1,1) double {mustBeInteger, mustBePositive}
                options.comment (1,1) string = ...
                    "Fully automatic kpoint scheme"
            end
            warning("KSSOLV:Matgenlab:Kpoints:KspacingPreferred", ...
                "Please use INCAR KSPACING tag.");
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment = options.comment, style = "Automatic", ...
                kpts = subdivisions);
        end

        function obj = gamma_automatic(kpts, shift, options)
            arguments
                kpts (1,3) double {mustBeInteger, mustBePositive} = [1,1,1]
                shift (1,3) double = [0,0,0]
                options.comment (1,1) string = "Automatic kpoint scheme"
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment = options.comment, style = "Gamma", kpts = kpts, ...
                kpts_shift = shift);
        end

        function obj = monkhorst_automatic(kpts, shift, options)
            arguments
                kpts (1,3) double {mustBeInteger, mustBePositive} = [2,2,2]
                shift (1,3) double = [0,0,0]
                options.comment (1,1) string = "Automatic kpoint scheme"
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment = options.comment, style = "Monkhorst", ...
                kpts = kpts, kpts_shift = shift);
        end

        function obj = automatic_density(structure, kppa, options)
            arguments
                structure
                kppa (1,1) double {mustBePositive}
                options.force_gamma (1,1) logical = false
                options.comment = []
            end
            comment = options.comment;
            if isempty(comment)
                comment = sprintf( ...
                    "pymatgen with grid density = %.0f / number of atoms", ...
                    kppa);
            end
            rounded = floor(kppa ^ (1 / 3) + 0.5);
            if abs(rounded ^ 3 - kppa) < 1, kppa = 1.01 * kppa; end
            lengths = structure.lattice.abc;
            multiplier = (kppa / structure.num_sites * prod(lengths)) ^ (1 / 3);
            divisions = floor(max(multiplier ./ lengths, 1));
            gamma = options.force_gamma || any(mod(divisions, 2) == 1) || ...
                structure.lattice.is_hexagonal() || ...
                kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                isFaceCentered(structure);
            if gamma
                obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    gamma_automatic(divisions, [0,0,0], comment = comment);
            else
                obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    monkhorst_automatic(divisions, [0,0,0], comment = comment);
            end
        end

        function obj = automatic_gamma_density(structure, kppa, options)
            arguments
                structure
                kppa (1,1) double {mustBePositive}
                options.comment = []
            end
            comment = options.comment;
            if isempty(comment)
                comment = sprintf( ...
                    "pymatgen with grid density = %.0f / number of atoms", ...
                    kppa);
            end
            lengths = structure.lattice.abc;
            multiplier = ...
                (kppa / structure.num_sites * prod(lengths)) ^ (1 / 3);
            divisions = round(multiplier ./ lengths);
            divisions(divisions < 1) = 1;
            low = divisions <= 8;
            divisions(low) = divisions(low) + mod(divisions(low), 2);
            divisions(~low) = divisions(~low) - ...
                mod(divisions(~low), 2) + 1;
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                gamma_automatic(divisions, [0,0,0], comment = comment);
        end

        function obj = automatic_density_by_vol(structure, kppvol, options)
            arguments
                structure
                kppvol (1,1) double {mustBePositive}
                options.force_gamma (1,1) logical = false
                options.comment = []
            end
            kppa = kppvol * structure.lattice.reciprocal_lattice.volume * ...
                structure.num_sites;
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                automatic_density(structure, kppa, ...
                force_gamma = options.force_gamma, ...
                comment = options.comment);
        end

        function obj = automatic_density_by_lengths( ...
                structure, length_densities, options)
            arguments
                structure
                length_densities (1,:) double {mustBePositive}
                options.force_gamma (1,1) logical = false
                options.comment = []
            end
            if numel(length_densities) ~= 3
                error("KSSOLV:Matgenlab:Kpoints:LengthDensities", ...
                    "The dimensions of length_densities must be 3, not %d.", ...
                    numel(length_densities));
            end
            comment = options.comment;
            if isempty(comment)
                comment = "k-point density of (" + ...
                    strjoin(string(length_densities), ", ") + ...
                    ")/[a, b, c]";
            end
            divisions = ceil(length_densities ./ structure.lattice.abc);
            gamma = options.force_gamma || any(mod(divisions, 2) == 1) || ...
                structure.lattice.is_hexagonal() || ...
                kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                isFaceCentered(structure);
            if gamma
                obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    gamma_automatic(divisions, [0,0,0], comment = comment);
            else
                obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    monkhorst_automatic(divisions, [0,0,0], comment = comment);
            end
        end

        function obj = automatic_linemode(divisions, ibz, options)
            arguments
                divisions (1,1) double {mustBeInteger, mustBePositive}
                ibz
                options.comment (1,1) string = "Line_mode KPOINTS file"
            end
            pathData = ibz.kpath;
            points = pathData.kpoints;
            paths = pathData.path;
            kpts = zeros(0, 3);
            labels = strings(1, 0);
            for pathIndex = 1:numel(paths)
                path = reshape(string(paths{pathIndex}), 1, []);
                kpts(end + 1, :) = points.(char(path(1))); %#ok<AGROW>
                labels(end + 1) = path(1); %#ok<AGROW>
                for index = 2:numel(path) - 1
                    coordinate = points.(char(path(index)));
                    kpts(end + 1:end + 2, :) = ...
                        repmat(coordinate, 2, 1);
                    labels(end + 1:end + 2) = path(index);
                end
                kpts(end + 1, :) = points.(char(path(end))); %#ok<AGROW>
                labels(end + 1) = path(end); %#ok<AGROW>
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment = options.comment, num_kpts = divisions, ...
                style = "Line_mode", coord_type = "Reciprocal", ...
                kpts = kpts, labels = labels);
            obj.preserveIntegerCoordinates_ = true;
        end

        function obj = from_file(filename)
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints.from_str( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
        end

        function obj = from_str(contents)
            lines = string(regexp(char(string(contents)), ...
                "\r\n|\n|\r", "split")).';
            lines = strtrim(lines);
            if numel(lines) < 4
                error("KSSOLV:Matgenlab:Kpoints:Truncated", ...
                    "KPOINTS requires at least four lines.");
            end
            comment = lines(1);
            numKpts = sscanf(lines(2), "%d", 1);
            initial = lower(extractBefore(lines(3), 2));
            if initial == "a"
                divisions = sscanf(lines(4), "%d", 1);
                warning("off", ...
                    "KSSOLV:Matgenlab:Kpoints:KspacingPreferred");
                cleanup = onCleanup(@() warning("on", ...
                    "KSSOLV:Matgenlab:Kpoints:KspacingPreferred"));
                obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    automatic(divisions, comment = comment);
                clear cleanup
                return
            end
            if any(initial == ["g", "m"])
                divisions = sscanf(lines(4), "%f").';
                if numel(divisions) ~= 3
                    error("KSSOLV:Matgenlab:Kpoints:InvalidKpoint", ...
                        "Invalid Kpoint length.");
                end
                shift = [0,0,0];
                if numel(lines) > 4
                    candidate = sscanf(lines(5), "%f").';
                    if ~isempty(candidate)
                        if numel(candidate) ~= 3
                            error("KSSOLV:Matgenlab:Kpoints:InvalidShift", ...
                                "Invalid kpoint shift length.");
                        end
                        shift = candidate;
                    end
                end
                if initial == "g"
                    obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                        gamma_automatic(divisions, shift, comment = comment);
                else
                    obj = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                        monkhorst_automatic(divisions, shift, comment = comment);
                end
                return
            end
            if numKpts <= 0
                style = "Reciprocal";
                if any(initial == ["c", "k"]), style = "Cartesian"; end
                kpts = zeros(3, 3);
                for index = 1:3
                    kpts(index, :) = sscanf(lines(index + 3), "%f").';
                end
                shift = sscanf(lines(7), "%f").';
                if numel(shift) ~= 3, shift = [0,0,0]; end
                obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                    comment = comment, num_kpts = numKpts, style = style, ...
                    kpts = kpts, kpts_shift = shift);
                return
            end
            if initial == "l"
                coordType = "Reciprocal";
                if any(lower(extractBefore(lines(4), 2)) == ["c", "k"])
                    coordType = "Cartesian";
                end
                kpts = zeros(0, 3);
                labels = strings(1, 0);
                expression = "^\s*([eE0-9.+-]+)\s+" + ...
                    "([eE0-9.+-]+)\s+([eE0-9.+-]+)\s*!?\s*(.*)$";
                for index = 5:numel(lines)
                    token = regexp(lines(index), expression, "tokens", "once");
                    if isempty(token), continue; end
                    kpts(end + 1, :) = cellfun(@str2double, token(1:3)); %#ok<AGROW>
                    labels(end + 1) = strtrim(string(token{4})); %#ok<AGROW>
                end
                obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                    comment = comment, num_kpts = numKpts, ...
                    style = "Line_mode", kpts = kpts, ...
                    coord_type = coordType, labels = labels);
                return
            end
            style = "Reciprocal";
            if any(initial == ["c", "k"]), style = "Cartesian"; end
            kpts = zeros(numKpts, 3);
            weights = zeros(1, numKpts);
            labels = strings(1, numKpts);
            labels(:) = missing;
            for index = 1:numKpts
                token = split(lines(index + 3));
                token(token == "") = [];
                kpts(index, :) = str2double(token(1:3));
                weights(index) = str2double(token(4));
                if numel(token) > 4, labels(index) = token(5); end
            end
            tetNumber = 0;
            tetWeight = 0;
            connections = {};
            location = 4 + numKpts;
            if numel(lines) >= location && ...
                    startsWith(lower(lines(location)), "t")
                header = sscanf(lines(location + 1), "%f").';
                tetNumber = header(1);
                tetWeight = header(2);
                connections = cell(1, tetNumber);
                for index = 1:tetNumber
                    row = sscanf(lines(location + 1 + index), "%d").';
                    connections{index} = {row(1), row(2:5)};
                end
            end
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment = comment, num_kpts = numKpts, style = style, ...
                kpts = kpts, kpts_weights = weights, labels = labels, ...
                tet_number = tetNumber, tet_weight = tetWeight, ...
                tet_connections = connections);
        end

        function obj = from_dict(input)
            obj = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "comment", ""), ...
                num_kpts = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "nkpoints", 0), ...
                style = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "generation_style", "Gamma"), ...
                kpts = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "kpoints", [1,1,1]), ...
                kpts_shift = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "usershift", [0,0,0]), ...
                kpts_weights = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "kpts_weights", []), ...
                coord_type = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "coord_type", []), ...
                labels = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "labels", []), ...
                tet_number = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "tet_number", 0), ...
                tet_weight = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "tet_weight", 0), ...
                tet_connections = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    field(input, "tet_connections", {}));
            for name = ["genvec1", "genvec2", "genvec3", "shift"]
                if isfield(input, name), obj.(name) = input.(name); end
            end
        end
    end

    methods (Access = private)
        function value = formatFloat(~, input)
            if input == fix(input), value = sprintf("%.1f", input);
            else, value = string(sprintf("%.15g", input));
            end
        end

        function value = formatCompactFloat(~, input)
            value = string(sprintf("%.15g", input));
        end

        function value = formatShift(~, input)
            if input == fix(input), value = string(sprintf("%d", input));
            else, value = string(sprintf("%.15g", input));
            end
        end
    end

    methods (Static, Access = private)
        function tf = isFaceCentered(structure)
            tf = false;
            try
                analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure);
                tf = startsWith(analyzer.get_space_group_symbol(), "F");
            catch
            end
        end

        function value = field(input, name, fallback)
            if isfield(input, name), value = input.(name);
            else, value = fallback;
            end
        end
    end
end
