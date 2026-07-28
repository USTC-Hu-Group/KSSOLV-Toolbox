classdef LobsterIn < kssolv.analysis.matgenlab.util.MSONable
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERIN Case-insensitive LOBSTER input-file model.
    properties
        data (1,1) struct = struct()
    end
    properties (Constant)
        FLOAT_KEYWORDS = ["cohpstartenergy", "cohpendenergy", ...
            "gaussiansmearingwidth", "usedecimalplaces", "cohpsteps", ...
            "basisrotation", "griddensityforprinting", "gridbufferforprinting"]
        STRING_KEYWORDS = ["basisset", "cohpgenerator", ...
            "realspacehamiltonian", "realspaceoverlap", ...
            "printpawrealspacewavefunction", ...
            "printlcaorealspacewavefunction", "kspacecohp", "ewaldsum"]
        BOOLEAN_KEYWORDS = ["saveprojectiontofile", "skipcar", "skipdos", ...
            "skipcohp", "skipcoop", "skipcobi", "skipmofe", ...
            "skipmolecularorbitals", "skipmadelungenergy", ...
            "loadprojectionfromfile", "printtotalspilling", ...
            "forceenergyrange", "densityofenergy", "bwdf", "bwdfcohp", ...
            "skippopulationanalysis", "skipgrosspopulation", ...
            "userecommendedbasisfunctions", "skipprojection", ...
            "printlmosonatoms", "printmofeatomwise", ...
            "printmofemoleculewise", "writeatomicorbitals", ...
            "writebasisfunctions", "writematricestofile", ...
            "nofftforvisualization", "rmsp", "onlyreadvasprun_xml", ...
            "nomemorymappedfiles", "skippaworthonormalitytest", ...
            "donotignoreexcessivebands", "donotuseabsolutespilling", ...
            "skipreorthonormalization", "forcev1hmatrix", ...
            "useoriginaltetrahedronmethod", "bandwisespilling", ...
            "kpointwisespilling", "lsodos", "autorotate", ...
            "donotorthogonalizebasis"]
        LIST_KEYWORDS = ["basisfunctions", "cohpbetween", "createfatband", ...
            "customstoforatom", "cobibetween", ...
            "printlmosonatomswriteatomicdensities"]
    end
    methods
        function obj = LobsterIn(settings)
            if nargin == 0, return; end
            names = fieldnames(settings);
            normalized = lower(strtrim(string(names)));
            if numel(unique(normalized)) ~= numel(normalized)
                error("KSSOLV:Matgenlab:Lobster:DuplicateKeyword", ...
                    "LOBSTER input contains duplicate case-insensitive keywords.");
            end
            available = obj.available_keywords();
            for index = 1:numel(names)
                key = normalized(index);
                if ~any(available == key)
                    error("KSSOLV:Matgenlab:Lobster:Keyword", ...
                        "LOBSTER keyword '%s' is not available.", key);
                end
                value = settings.(names{index});
                if ischar(value) || isstring(value), value = strtrim(value); end
                obj.data.(matlab.lang.makeValidName(key)) = value;
            end
        end

        function value = get(obj, key, fallback)
            if nargin < 3, fallback = []; end
            name = matlab.lang.makeValidName(lower(strtrim(string(key))));
            if isfield(obj.data, name), value = obj.data.(name);
            else, value = fallback; end
        end

        function tf = contains(obj, key)
            tf = isfield(obj.data, ...
                matlab.lang.makeValidName(lower(strtrim(string(key)))));
        end

        function result = diff(obj, other)
            same = struct();
            different = struct();
            names = union(fieldnames(obj.data), fieldnames(other.data));
            for index = 1:numel(names)
                name = names{index};
                hasFirst = isfield(obj.data, name);
                hasSecond = isfield(other.data, name);
                if hasFirst, first = obj.data.(name); else, first = []; end
                if hasSecond, second = other.data.(name); else, second = []; end
                equal = hasFirst && hasSecond;
                if equal && iscell(first) && iscell(second)
                    equal = isequal(sort(lower(strtrim(string(first)))), ...
                        sort(lower(strtrim(string(second)))));
                elseif equal
                    equal = isequal(first, second);
                end
                if equal
                    same.(name) = first;
                else
                    different.(name) = struct( ...
                        "lobsterin1", first, "lobsterin2", second);
                end
            end
            result = struct("Same", same, "Different", different);
        end

        function write_lobsterin(obj, path, overwrite)
            if nargin < 2 || isempty(path), path = "lobsterin"; end
            if nargin >= 3 && ~isempty(overwrite)
                names = fieldnames(overwrite);
                for index = 1:numel(names)
                    key = matlab.lang.makeValidName(lower(names{index}));
                    obj.data.(key) = overwrite.(names{index});
                end
            end
            names = fieldnames(obj.data);
            lines = strings(0, 1);
            for index = 1:numel(names)
                key = string(names{index});
                canonical = obj.canonical_keyword(key);
                value = obj.data.(names{index});
                if any(obj.BOOLEAN_KEYWORDS == key)
                    lines(end + 1) = canonical;
                elseif any(obj.LIST_KEYWORDS == key)
                    values = string(value);
                    lines = [lines; canonical + " " + values(:)];
                else
                    lines(end + 1) = canonical + " " + string(value);
                end
            end
            fileId = fopen(path, "wt", "n", "UTF-8");
            if fileId < 0
                error("KSSOLV:Matgenlab:Lobster:Write", ...
                    "Unable to write '%s'.", string(path));
            end
            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, "%s\n", lines);
        end

        function value = as_dict(obj)
            value = obj.data;
            value.x_module = "pymatgen.io.lobster.future.inputs";
            value.x_class = "LobsterIn";
        end
        function value = asDict(obj), value = obj.as_dict(); end

        function write_INCAR(obj, incar_input, incar_output, ~, isym, further_settings)
            if nargin < 2 || isempty(incar_input), incar_input = "INCAR"; end
            if nargin < 3 || isempty(incar_output), incar_output = "INCAR.lobster"; end
            if nargin < 5 || isempty(isym), isym = 0; end
            if nargin < 6, further_settings = struct(); end
            if ~any(isym == [-1, 0])
                error("KSSOLV:Matgenlab:Lobster:ISYM", "ISYM must be -1 or 0.");
            end
            text = kssolv.analysis.matgenlab.io.lobster.read_text(incar_input);
            text = regexprep(text, "(?im)^\s*(ISYM|NSW|LWAVE|NBANDS)\s*=.*$", "");
            basis = string(obj.get("basisfunctions", {}));
            count = 0;
            for item = basis(:).'
                tokens = split(strtrim(item));
                for orbital = tokens(2:end).'
                    if endsWith(orbital, "s"), count = count + 1;
                    elseif contains(orbital, "p"), count = count + 3;
                    elseif contains(orbital, "d"), count = count + 5;
                    elseif contains(orbital, "f"), count = count + 7;
                    end
                end
            end
            additions = ["ISYM = " + string(isym); "NSW = 0"; "LWAVE = TRUE"];
            if count > 0, additions(end + 1) = "NBANDS = " + string(count); end
            names = fieldnames(further_settings);
            for index = 1:numel(names)
                additions(end + 1) = upper(string(names{index})) + ...
                    " = " + string(further_settings.(names{index}));
            end
            kssolv.analysis.matgenlab.io.lobster.future.LobsterIn. ...
                write_text(incar_output, strtrim(string(text)) + newline + ...
                strjoin(additions, newline) + newline);
        end
    end

    methods (Static)
        function obj = from_file(path)
            lines = regexp(kssolv.analysis.matgenlab.io.lobster.read_text(path), ...
                "\r\n|\n|\r", "split");
            settings = struct();
            listKeys = kssolv.analysis.matgenlab.io.lobster.future. ...
                LobsterIn.LIST_KEYWORDS;
            for index = 1:numel(lines)
                line = strtrim(regexprep(lines{index}, "[!#].*$", ""));
                if isempty(line), continue; end
                parts = regexp(line, "\s+", "split");
                key = lower(string(parts{1}));
                name = matlab.lang.makeValidName(key);
                if any(listKeys == key)
                    if ~isfield(settings, name), settings.(name) = {}; end
                    settings.(name){end + 1} = strjoin(parts(2:end), " ");
                elseif numel(parts) == 1
                    settings.(name) = true;
                else
                    numeric = str2double(parts{2});
                    if ~isnan(numeric), settings.(name) = numeric;
                    else, settings.(name) = strjoin(parts(2:end), " "); end
                end
            end
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterIn(settings);
        end

        function obj = from_dict(value)
            names = fieldnames(value);
            settings = struct();
            for index = 1:numel(names)
                if ~startsWith(names{index}, "@") && ...
                        ~ismember(string(names{index}), ["x_module", "x_class"])
                    settings.(names{index}) = value.(names{index});
                end
            end
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterIn(settings);
        end

        function basis = get_basis(structure, potcar_symbols, basis_file)
            if nargin < 3 || isempty(basis_file)
                basis_file = fullfile(fileparts(mfilename("fullpath")), ...
                    "lobster_basis", "BASIS_PBE_54_standard.yaml");
            end
            text = kssolv.analysis.matgenlab.io.lobster.read_text(basis_file);
            basis = cell(1, numel(potcar_symbols));
            symbols = strings(1, numel(potcar_symbols));
            for index = 1:numel(potcar_symbols)
                potcar = string(potcar_symbols{index});
                symbols(index) = extractBefore(potcar + "_", "_");
                expression = "(?m)^\s*" + regexptranslate("escape", potcar) + ...
                    ":\s*['""]([^'""]+)['""]";
                token = regexp(text, expression, "tokens", "once");
                if isempty(token)
                    error("KSSOLV:Matgenlab:Lobster:Basis", ...
                        "Missing basis for POTCAR symbol '%s'.", potcar);
                end
                basis{index} = char(symbols(index) + " " + strtrim(token{1}));
            end
            if isprop(structure, "symbol_set")
                if ~isequal(sort(string(structure.symbol_set)), sort(symbols))
                    error("KSSOLV:Matgenlab:Lobster:BasisMismatch", ...
                        "Structure species do not correspond to POTCAR symbols.");
                end
            end
        end

        function values = get_all_possible_basis_functions(structure, potcar_symbols, min_file, max_file)
            root = fullfile(fileparts(mfilename("fullpath")), "lobster_basis");
            if nargin < 3 || isempty(min_file)
                min_file = fullfile(root, "BASIS_PBE_54_min.yaml");
            end
            if nargin < 4 || isempty(max_file)
                max_file = fullfile(root, "BASIS_PBE_54_max.yaml");
            end
            minimum = kssolv.analysis.matgenlab.io.lobster.future. ...
                LobsterIn.get_basis(structure, potcar_symbols, min_file);
            maximum = kssolv.analysis.matgenlab.io.lobster.future. ...
                LobsterIn.get_basis(structure, potcar_symbols, max_file);
            combinations = kssolv.analysis.matgenlab.io.lobster.future. ...
                get_all_possible_basis_combinations(minimum, maximum);
            values = cell(size(combinations));
            for index = 1:numel(combinations)
                value = struct();
                for entry = combinations{index}
                    parts = split(string(entry{1}));
                    value.(matlab.lang.makeValidName(parts(1))) = ...
                        char(strjoin(parts(2:end), " "));
                end
                values{index} = value;
            end
        end

        function write_POSCAR_with_standard_primitive(input, output, ~)
            if nargin < 1 || isempty(input), input = "POSCAR"; end
            if nargin < 2 || isempty(output), output = "POSCAR.lobster"; end
            text = kssolv.analysis.matgenlab.io.lobster.read_text(input);
            kssolv.analysis.matgenlab.io.lobster.future.LobsterIn. ...
                write_text(output, text);
        end

        function write_KPOINTS(~, output, ~, isym, from_grid, input_grid, varargin)
            if nargin < 2 || isempty(output), output = "KPOINTS.lobster"; end
            if nargin < 4 || isempty(isym), isym = 0; end
            if nargin < 5 || isempty(from_grid), from_grid = false; end
            if nargin < 6 || isempty(input_grid), input_grid = [5, 5, 5]; end
            if ~from_grid, input_grid = [5, 5, 5]; end
            if ~any(isym == [-1, 0])
                error("KSSOLV:Matgenlab:Lobster:ISYM", "ISYM must be -1 or 0.");
            end
            [x, y, z] = ndgrid(0:input_grid(1)-1, ...
                0:input_grid(2)-1, 0:input_grid(3)-1);
            points = [x(:) / input_grid(1), y(:) / input_grid(2), ...
                z(:) / input_grid(3)];
            lines = ["KPOINTS generated by matgenlab"; string(size(points, 1)); ...
                "Reciprocal"];
            for index = 1:size(points, 1)
                lines(end + 1) = compose("%.12f %.12f %.12f 1", points(index, :));
            end
            kssolv.analysis.matgenlab.io.lobster.future.LobsterIn. ...
                write_text(output, strjoin(lines, newline) + newline);
        end

        function obj = standard_calculations_from_vasp_files(varargin)
            parser = inputParser;
            parser.KeepUnmatched = true;
            addParameter(parser, "dict_for_basis", struct());
            addParameter(parser, "option", "standard");
            parse(parser, varargin{:});
            option = string(parser.Results.option);
            settings = struct("basisset", "pbeVaspFit2015", ...
                "cohpstartenergy", -15, "cohpendenergy", 5, ...
                "gaussiansmearingwidth", 0.05);
            dictionary = parser.Results.dict_for_basis;
            if ~isempty(fieldnames(dictionary))
                names = fieldnames(dictionary);
                settings.basisfunctions = cellfun(@(name) ...
                    char(string(name) + " " + string(dictionary.(name))), ...
                    names, "UniformOutput", false);
            else
                settings.basisfunctions = {};
            end
            if contains(option, "cohp"), settings.skipcohp = false; end
            if contains(option, "coop"), settings.skipcoop = false; end
            if contains(option, "cobi"), settings.skipcobi = false; end
            if contains(option, "fatband")
                settings.createfatband = settings.basisfunctions;
            end
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterIn(settings);
        end

        function values = available_keywords()
            cls = kssolv.analysis.matgenlab.io.lobster.future.LobsterIn;
            values = unique([cls.FLOAT_KEYWORDS, cls.STRING_KEYWORDS, ...
                cls.BOOLEAN_KEYWORDS, cls.LIST_KEYWORDS]);
        end
    end

    methods (Static, Access = private)
        function value = canonical_keyword(key)
            known = ["COHPstartEnergy", "COHPendEnergy", ...
                "gaussianSmearingWidth", "useDecimalPlaces", "COHPSteps", ...
                "basisRotation", "gridDensityForPrinting", ...
                "gridBufferForPrinting", "basisSet", "cohpGenerator", ...
                "realspaceHamiltonian", "realspaceOverlap", ...
                "printPAWRealSpaceWavefunction", ...
                "printLCAORealSpaceWavefunction", "kSpaceCOHP", ...
                "EwaldSum", "basisfunctions", "cohpbetween", ...
                "createFatband", "customSTOforAtom", "cobiBetween"];
            index = find(lower(known) == lower(string(key)), 1);
            if isempty(index), value = string(key); else, value = known(index); end
        end

        function write_text(path, text)
            fileId = fopen(path, "wt", "n", "UTF-8");
            if fileId < 0
                error("KSSOLV:Matgenlab:Lobster:Write", ...
                    "Unable to write '%s'.", string(path));
            end
            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, "%s", text);
        end
    end
end
