classdef PotcarSingle
    %POTCARSINGLE One complete VASP pseudopotential dataset.
    %
    % Raw restricted POTCAR content is never bundled. This parser and the
    % bundled non-invertible summary statistics follow pymatgen-core
    % v2026.7.24.

    properties
        data (1,1) string = ""
        keywords (1,1) struct = struct()
    end

    properties (SetAccess = private)
        header (1,1) string = ""
        summary_stats (1,1) struct = struct()
    end

    properties (Access = private)
        symbol_ (1,1) string = ""
    end

    properties (Dependent, SetAccess = private)
        electron_configuration
        element
        atomic_no
        nelectrons
        symbol
        potential_type
        functional
        functional_class
        is_valid
    end

    methods
        function obj = PotcarSingle(data, symbol)
            if nargin == 0, return; end
            obj.data = string(data);
            lines = splitlines(obj.data);
            if isempty(lines), return; end
            obj.header = strtrim(lines(1));
            obj.keywords = obj.parseKeywords(char(obj.data));
            if nargin >= 2 && strlength(string(symbol)) > 0
                obj.symbol_ = string(symbol);
            elseif isfield(obj.keywords, "TITEL")
                tokens = split(strtrim(string(obj.keywords.TITEL)));
                tokens(tokens == "") = [];
                if numel(tokens) >= 2, obj.symbol_ = tokens(2);
                else, obj.symbol_ = strtrim(string(obj.keywords.TITEL));
                end
            end
            obj.summary_stats = obj.computeSummaryStats();
            if ~obj.is_valid
                warning("KSSOLV:Matgenlab:UnknownPotcarWarning", ...
                    "POTCAR data with symbol %s is not known to matgenlab. " + ...
                    "Your POTCAR may be corrupted or the POTCAR database is incomplete.", ...
                    obj.symbol_);
            end
        end

        function value = get.symbol(obj), value = obj.symbol_; end

        function value = get.nelectrons(obj)
            value = obj.keyword("ZVAL");
        end

        function value = get.electron_configuration(obj)
            value = obj.get_electron_configuration();
        end

        function value = get.element(obj)
            raw = string(obj.keyword("VRHFIN"));
            token = strtrim(extractBefore(raw + ":", ":"));
            try
                value = kssolv.analysis.matgenlab.core.Element(token).symbol;
            catch
                if token == "X"
                    value = "Xe";
                else
                    base = extractBefore(obj.symbol_ + "_", "_");
                    value = kssolv.analysis.matgenlab.core.Element(base).symbol;
                end
            end
        end

        function value = get.atomic_no(obj)
            value = kssolv.analysis.matgenlab.core.Element(obj.element).Z;
        end

        function value = get.potential_type(obj)
            if obj.truthyKeyword("LULTRA"), value = "US";
            elseif obj.truthyKeyword("LPAW"), value = "PAW";
            else, value = "NC";
            end
        end

        function value = get.functional(obj)
            [value, ~] = obj.functionalIdentity();
        end

        function value = get.functional_class(obj)
            [~, value] = obj.functionalIdentity();
        end

        function value = get.is_valid(obj)
            references = ...
                kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                matchingReferences(obj);
            value = false;
            for index = 1:numel(references)
                if kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                        compare_potcar_stats(references{index}, ...
                        obj.summary_stats)
                    value = true;
                    return
                end
            end
        end

        function value = get_electron_configuration(obj, tol)
            if nargin < 2, tol = 0.01; end
            lines = splitlines(obj.data);
            location = find(contains(lines, "Atomic configuration"), 1);
            if isempty(location)
                error("KSSOLV:Matgenlab:PotcarSingle:AtomicConfiguration", ...
                    "Cannot find atomic configuration section in POTCAR.");
            end
            entryMatch = regexp(lines(location + 1), ...
                "(\d+)\s+entries", "tokens", "once");
            if isempty(entryMatch)
                error("KSSOLV:Matgenlab:PotcarSingle:AtomicConfiguration", ...
                    "Cannot find entries in POTCAR.");
            end
            numberEntries = str2double(entryMatch{1});
            total = 0;
            rows = cell(0, 3);
            letters = ["s", "p", "d", "f", "g", "h"];
            last = location + 2 + numberEntries;
            for index = last:-1:location + 3
                values = sscanf(lines(index), "%f").';
                if numel(values) < 5, continue; end
                occupation = values(5);
                if occupation >= tol
                    rows(end + 1, :) = {values(1), ...
                        letters(values(2) + 1), occupation}; %#ok<AGROW>
                    total = total + occupation;
                end
                if total >= obj.nelectrons - tol, break; end
            end
            value = flipud(rows);
        end

        function output = spec(obj, extra_spec)
            if nargin < 2, extra_spec = strings(1, 0); end
            output = struct();
            output.titel = obj.keyword("TITEL");
            output.hash = [];
            output.summary_stats = obj.summary_stats;
            for name = reshape(string(extra_spec), 1, [])
                try
                    output.(char(name)) = obj.(char(name));
                catch
                    output.(char(name)) = [];
                end
            end
        end

        function write_file(obj, filename)
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, char(obj));
        end

        function output = copy(obj)
            previous = warning("off", ...
                "KSSOLV:Matgenlab:UnknownPotcarWarning");
            cleanup = onCleanup(@() warning(previous));
            output = kssolv.analysis.matgenlab.io.vasp.PotcarSingle( ...
                obj.data, obj.symbol_);
            clear cleanup
        end

        function tf = eq(obj, other)
            tf = isa(other, ...
                "kssolv.analysis.matgenlab.io.vasp.PotcarSingle") && ...
                obj.data == other.data && isequaln(obj.keywords, other.keywords);
        end

        function tf = ne(obj, other), tf = ~eq(obj, other); end

        function output = char(obj)
            output = char(obj.data + newline);
        end

        function output = string(obj), output = string(char(obj)); end

        function output = repr(obj)
            output = "PotcarSingle(symbol='" + obj.symbol + ...
                "', functional='" + obj.functional + "', TITEL='" + ...
                string(obj.keyword("TITEL")) + "', VRHFIN='" + ...
                string(obj.keyword("VRHFIN")) + ...
                "', n_valence_elec=" + sprintf("%.0f", obj.nelectrons) + ")";
        end

        function [functionals, symbols] = identify_potcar(obj, mode, data_tol)
            if nargin < 2, mode = "data"; end
            if nargin < 3, data_tol = 1e-6; end
            mode = string(mode);
            if mode == "data", fields = "header";
            elseif mode == "file", fields = ["header", "data"];
            else
                error("KSSOLV:Matgenlab:PotcarSingle:IdentifyMode", ...
                    "Bad mode='%s'. Choose 'data' or 'file'.", mode);
            end
            database = ...
                kssolv.analysis.matgenlab.io.vasp.PotcarSingle.statsDatabase();
            names = string(fieldnames(database)).';
            functionals = strings(1, 0);
            symbols = strings(1, 0);
            title = matlab.lang.makeValidName(erase( ...
                string(obj.keyword("TITEL")), " "));
            vrhfin = erase(string(obj.keyword("VRHFIN")), " ");
            for name = names
                group = database.(char(name));
                if ~isfield(group, title), continue; end
                candidates = obj.toCell(group.(title));
                for index = 1:numel(candidates)
                    candidate = candidates{index};
                    if string(candidate.VRHFIN) ~= vrhfin, continue; end
                    if kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                            compare_potcar_stats(candidate, obj.summary_stats, ...
                            data_tol, fields)
                        functionals(end + 1) = name; %#ok<AGROW>
                        symbols(end + 1) = string(candidate.symbol); %#ok<AGROW>
                    end
                end
            end
            functionals = unique(functionals);
            symbols = unique(symbols);
            if isempty(functionals) || isempty(symbols)
                functionals = strings(1, 0);
                symbols = strings(1, 0);
            end
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, ".")
                name = upper(reference(1).subs);
                if isfield(obj.keywords, name) && ...
                        ~isprop(obj, reference(1).subs) && ...
                        ~ismethod(obj, reference(1).subs)
                    value = obj.keywords.(name);
                    if numel(reference) > 1
                        value = builtin("subsref", value, reference(2:end));
                    end
                    varargout{1} = value;
                    return
                end
            end
            [varargout{1:nargout}] = builtin("subsref", obj, reference);
        end
    end

    methods (Static)
        function obj = from_file(filename)
            filename = string(filename);
            match = regexp(filename, "POTCAR\.([^/]+?)(?:\.gz|\.bz2)?$", ...
                "tokens", "once");
            if isempty(match), symbol = ""; else, symbol = string(match{1}); end
            obj = kssolv.analysis.matgenlab.io.vasp.PotcarSingle( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename), symbol);
        end

        function obj = from_symbol_and_functional(symbol, functional)
            if nargin < 2 || strlength(string(functional)) == 0
                functional = getenv("PMG_DEFAULT_FUNCTIONAL");
                if isempty(functional), functional = "PBE"; end
            end
            functional = string(functional);
            mapping = ...
                kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                functionalDirectories();
            if ~isfield(mapping, char(functional))
                error("KSSOLV:Matgenlab:PotcarSingle:Functional", ...
                    "Unknown POTCAR functional '%s'.", functional);
            end
            root = string(getenv("PMG_VASP_PSP_DIR"));
            if root == ""
                error("KSSOLV:Matgenlab:PmgVaspPspDirError", ...
                    "Set PMG_VASP_PSP_DIR=<directory-path> in the environment " + ...
                    "(needed to find POTCARs).");
            end
            if ~isfolder(root)
                error("KSSOLV:Matgenlab:PotcarSingle:PspDirectoryMissing", ...
                    "PMG_VASP_PSP_DIR='%s' does not exist.", root);
            end
            subdirectory = string(mapping.(char(functional)));
            bases = [
                fullfile(root, subdirectory, "POTCAR." + string(symbol))
                fullfile(root, subdirectory, string(symbol), "POTCAR")
                ];
            for base = bases.'
                for suffix = ["", ".gz", ".bz2"]
                    candidate = base + suffix;
                    if isfile(candidate)
                        obj = ...
                            kssolv.analysis.matgenlab.io.vasp.PotcarSingle. ...
                            from_file(candidate);
                        obj.symbol_ = string(symbol);
                        return
                    end
                end
            end
            error("KSSOLV:Matgenlab:PotcarSingle:PotcarMissing", ...
                "You do not have the right POTCAR with functional='%s' " + ...
                "and symbol='%s' in PMG_VASP_PSP_DIR='%s'.", ...
                functional, symbol, root);
        end

        function tf = compare_potcar_stats(first, second, tolerance, fields)
            if nargin < 3, tolerance = 1e-6; end
            if nargin < 4, fields = ["header", "data"]; end
            fields = reshape(string(fields), 1, []);
            tf = true;
            statistics = ["MEAN", "ABSMEAN", "VAR", "MIN", "MAX"];
            for field = fields
                firstKeywords = string(first.keywords.(field));
                secondKeywords = string(second.keywords.(field));
                if ~isequal(sort(firstKeywords), sort(secondKeywords))
                    tf = false;
                    return
                end
                for statistic = statistics
                    a = first.stats.(field).(statistic);
                    b = second.stats.(field).(statistic);
                    if ~(abs(a - b) < tolerance)
                        tf = false;
                        return
                    end
                end
            end
        end
    end

    methods (Access = private)
        function value = keyword(obj, name)
            name = upper(char(string(name)));
            if ~isfield(obj.keywords, name)
                error("KSSOLV:Matgenlab:PotcarSingle:Keyword", ...
                    "POTCAR keyword '%s' is absent.", name);
            end
            value = obj.keywords.(name);
        end

        function tf = truthyKeyword(obj, name)
            tf = false;
            if isfield(obj.keywords, name)
                value = obj.keywords.(name);
                tf = (islogical(value) || isnumeric(value)) && ...
                    isscalar(value) && logical(value);
            end
        end

        function [name, family] = functionalIdentity(obj)
            name = [];
            family = [];
            if ~isfield(obj.keywords, "LEXCH"), return; end
            switch lower(string(obj.keywords.LEXCH))
                case "pe", name = "PBE"; family = "GGA";
                case "91", name = "PW91"; family = "GGA";
                case "rp", name = "revPBE"; family = "GGA";
                case "am", name = "AM05"; family = "GGA";
                case "ps", name = "PBEsol"; family = "GGA";
                case "pw", name = "PW86"; family = "GGA";
                case "lm", name = "Langreth-Mehl-Hu"; family = "GGA";
                case "pb", name = "Perdew-Becke"; family = "GGA";
                case "ca", name = "Perdew-Zunger81"; family = "LDA";
                case "hl", name = "Hedin-Lundquist"; family = "LDA";
                case "wi", name = "Wigner Interpolation"; family = "LDA";
            end
        end

        function keywords = parseKeywords(obj, text)
            keywords = struct();
            section = regexp(text, ...
                "(?s)parameters from PSCTR are:.*?END of PSCTR-controll parameters", ...
                "match", "once");
            if isempty(section), return; end
            matches = regexp(section, ...
                "(?m)(\S+)\s*=\s*(.*?)(?=;|$)", "tokens");
            for index = 1:numel(matches)
                key = string(matches{index}{1});
                raw = strtrim(string(matches{index}{2}));
                [known, value] = obj.parseKeyword(key, raw);
                if known, keywords.(char(key)) = value; end
            end
            atomic = regexp(section, ...
                "(?s)Atomic configuration(.*?)Description", ...
                "tokens", "once");
            if ~isempty(atomic)
                lines = splitlines(string(atomic{1}));
                if numel(lines) >= 2
                    number = regexp(lines(2), "([0-9]+)", ...
                        "tokens", "once");
                    if ~isempty(number)
                        keywords.nentries = str2double(number{1});
                    end
                end
                orbitals = ...
                    kssolv.analysis.matgenlab.io.vasp.Orbital.empty(0, 1);
                for line = lines.'
                    values = sscanf(line, "%f").';
                    if numel(values) >= 5
                        orbitals(end + 1, 1) = ...
                            kssolv.analysis.matgenlab.io.vasp.Orbital( ...
                            values(1), values(2), values(3), ...
                            values(4), values(5)); %#ok<AGROW>
                    end
                end
                if ~isempty(orbitals), keywords.Orbitals = orbitals; end
            end
            description = regexp(section, ...
                "(?s)Description\s*\n(.*?)Error from kinetic energy " + ...
                "argument \(eV\)", "tokens", "once");
            if ~isempty(description)
                rows = kssolv.analysis.matgenlab.io.vasp. ...
                    OrbitalDescription.empty(0, 1);
                for line = splitlines(string(description{1})).'
                    values = sscanf(line, "%f").';
                    if numel(values) >= 4
                        fifth = [];
                        sixth = [];
                        if numel(values) > 4
                            fifth = values(5);
                            sixth = values(6);
                        end
                        rows(end + 1, 1) = ...
                            kssolv.analysis.matgenlab.io.vasp. ...
                            OrbitalDescription(values(1), values(2), ...
                            values(3), values(4), fifth, sixth); %#ok<AGROW>
                    end
                end
                if ~isempty(rows), keywords.OrbitalDescriptions = rows; end
            end
            kinetic = regexp(section, ...
                "(?s)Error from kinetic energy argument \(eV\)\s*\n" + ...
                "(.*?)END of PSCTR-controll parameters", ...
                "tokens", "once");
            rrkj = zeros(1, 0);
            if ~isempty(kinetic)
                for line = splitlines(string(kinetic{1})).'
                    if contains(line, "="), continue; end
                    values = sscanf(line, "%f").';
                    rrkj = [rrkj, values]; %#ok<AGROW>
                end
            end
            if ~isempty(rrkj), keywords.RRKJ = rrkj; end
        end

        function [known, value] = parseKeyword(~, key, raw)
            booleanKeys = ["LULTRA","LUNSCR","LCOR","LPAW"];
            floatKeys = ["EATOM","RPACOR","POMASS","ZVAL","RCORE", ...
                "RWIGS","ENMAX","ENMIN","EMMIN","EAUG","DEXC","RMAX", ...
                "RAUG","RDEP","RDEPT","QCUT","QGAM","RCLOC"];
            integerKeys = ["IUNSCR","ICORE","NDATA"];
            stringKeys = ["VRHFIN","LEXCH","TITEL","SHA256","COPYR"];
            listKeys = ["STEP","RRKJ","GGA"];
            known = true;
            if any(key == booleanKeys)
                value = startsWith(lower(raw), ["t", ".t"]);
            elseif any(key == floatKeys)
                value = str2double(regexp(raw, ...
                    "[-+]?\d*\.?\d+(?:[Ee][-+]?\d+)?", ...
                    "match", "once"));
            elseif any(key == integerKeys)
                value = str2double(regexp(raw, "[-+]?\d+", ...
                    "match", "once"));
            elseif any(key == stringKeys)
                value = strtrim(raw);
            elseif any(key == listKeys)
                tokens = regexp(raw, ...
                    "[-+]?\d*\.?\d+(?:[Ee][-+]?\d+)?", "match");
                value = cellfun(@str2double, tokens);
            else
                known = false;
                value = [];
            end
        end

        function output = computeSummaryStats(obj)
            marker = "END of PSCTR-controll parameters" + newline;
            parts = split(obj.data, marker);
            if numel(parts) < 2, body = ""; else, body = strjoin(parts(2:end), marker); end
            keys = strings(1, 0);
            numbers = zeros(1, 0);
            rows = regexp(char(body), "\n+|;", "split");
            for index = 1:numel(rows)
                words = regexp(strtrim(rows{index}), "\s+", "split");
                text = "";
                for wordIndex = 1:numel(words)
                    token = words{wordIndex};
                    if isempty(token), continue; end
                    if any(lower(string(token)) == ...
                            ["t", "f", "true", "false"])
                        numbers(end + 1) = double(startsWith( ...
                            lower(string(token)), "t")); %#ok<AGROW>
                        continue
                    end
                    if ~isempty(regexp(token, ...
                            "^[+-]?\d*\.?\d+[Dd][+-]?\d+$", "once"))
                        value = NaN;
                    else
                        value = str2double(token);
                    end
                    if ~isnan(value)
                        numbers(end + 1) = value; %#ok<AGROW>
                    else
                        text = text + string(strtrim(token));
                    end
                end
                if text ~= "", keys(end + 1) = lower(text); end %#ok<AGROW>
            end
            headerNumbers = zeros(1, 0);
            names = fieldnames(obj.keywords);
            for index = 1:numel(names)
                value = obj.keywords.(names{index});
                if islogical(value)
                    headerNumbers(end + 1) = double(value); %#ok<AGROW>
                elseif isnumeric(value)
                    headerNumbers = [headerNumbers, ...
                        reshape(double(value), 1, [])]; %#ok<AGROW>
                end
            end
            output = struct();
            output.keywords = struct( ...
                "header", {lower(string(names)).'}, "data", {keys});
            output.stats = struct( ...
                "header", obj.statistics(headerNumbers), ...
                "data", obj.statistics(numbers));
        end

        function value = statistics(~, numbers)
            if isempty(numbers)
                value = struct("MEAN", NaN, "ABSMEAN", NaN, ...
                    "VAR", NaN, "MIN", NaN, "MAX", NaN);
            else
                value = struct("MEAN", mean(numbers), ...
                    "ABSMEAN", mean(abs(numbers)), ...
                    "VAR", mean(numbers .^ 2), "MIN", min(numbers), ...
                    "MAX", max(numbers));
            end
        end

        function output = toCell(~, value)
            if iscell(value), output = value;
            elseif isstruct(value), output = num2cell(value);
            else, output = {value};
            end
        end
    end

    methods (Static)
        function mapping = functionalDirectories()
            mapping = struct( ...
                "PBE", "POT_GGA_PAW_PBE", ...
                "PBE_52", "POT_GGA_PAW_PBE_52", ...
                "PBE_52_W_HASH", "POTPAW_PBE_52", ...
                "PBE_54", "POT_GGA_PAW_PBE_54", ...
                "PBE_54_W_HASH", "POTPAW_PBE_54", ...
                "PBE_64", "POT_PAW_PBE_64", ...
                "LDA", "POT_LDA_PAW", ...
                "LDA_52", "POT_LDA_PAW_52", ...
                "LDA_52_W_HASH", "POTPAW_LDA_52", ...
                "LDA_54", "POT_LDA_PAW_54", ...
                "LDA_54_W_HASH", "POTPAW_LDA_54", ...
                "LDA_64", "POT_LDA_PAW_64", ...
                "PW91", "POT_GGA_PAW_PW91", ...
                "LDA_US", "POT_LDA_US", ...
                "PW91_US", "POT_GGA_US_PW91", ...
                "Perdew_Zunger81", "POT_LDA_PAW");
        end

        function database = statsDatabase()
            persistent cached
            if isempty(cached)
                source = fullfile(fileparts(mfilename("fullpath")), ...
                    "potcar-summary-stats.json.bz2");
                cached = jsondecode( ...
                    kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                    readText(source));
            end
            database = cached;
        end

        function references = matchingReferences(obj)
            references = cell(1, 0);
            if ~isfield(obj.keywords, "TITEL") || ...
                    ~isfield(obj.keywords, "VRHFIN")
                return
            end
            database = ...
                kssolv.analysis.matgenlab.io.vasp.PotcarSingle.statsDatabase();
            title = matlab.lang.makeValidName(erase( ...
                string(obj.keywords.TITEL), " "));
            vrhfin = erase(string(obj.keywords.VRHFIN), " ");
            functions = fieldnames(database);
            for functionIndex = 1:numel(functions)
                group = database.(functions{functionIndex});
                if ~isfield(group, title), continue; end
                candidates = group.(title);
                if isstruct(candidates), candidates = num2cell(candidates); end
                if ~iscell(candidates), candidates = {candidates}; end
                for index = 1:numel(candidates)
                    candidate = candidates{index};
                    if string(candidate.VRHFIN) == vrhfin
                        references{end + 1} = candidate; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
