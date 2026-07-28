classdef Settings
    %SETTINGS Lazy pymatgen-compatible configuration loader.
    %
    % Configuration is loaded from PMG_CONFIG_FILE, then
    % ~/.config/.pmgrc.yaml, then ~/.pmgrc.yaml. Environment variables with
    % PMG_ prefixes override file values. VASP_PSP_DIR, MAPI_KEY, and
    % DEFAULT_FUNCTIONAL are exposed with a PMG_ prefix for compatibility.

    methods (Static)
        function value = all()
            value = kssolv.analysis.matgenlab.core.Settings.cache();
        end

        function value = get(name, defaultValue)
            arguments
                name (1,1) string
                defaultValue = []
            end
            settings = kssolv.analysis.matgenlab.core.Settings.cache();
            key = char(name);
            if isKey(settings, key)
                value = settings(key);
            else
                value = defaultValue;
            end
        end

        function refresh()
            kssolv.analysis.matgenlab.core.Settings.cache(true);
        end
    end

    methods (Static, Access = private)
        function settings = cache(reset)
            arguments
                reset (1,1) logical = false
            end
            persistent cachedSettings
            if reset || isempty(cachedSettings)
                cachedSettings = ...
                    kssolv.analysis.matgenlab.core.Settings.loadSettings();
            end
            settings = cachedSettings;
        end

        function settings = loadSettings()
            settings = containers.Map("KeyType", "char", "ValueType", "any");

            configuredPath = string(getenv("PMG_CONFIG_FILE"));
            userHome = string(getenv("HOME"));
            if userHome == "" && ispc
                userHome = string(getenv("USERPROFILE"));
            end
            candidates = [
                configuredPath
                fullfile(userHome, ".config", ".pmgrc.yaml")
                fullfile(userHome, ".pmgrc.yaml")
                ];
            candidates = unique(candidates(candidates ~= ""), "stable");
            for index = 1:numel(candidates)
                if isfile(candidates(index))
                    settings = ...
                        kssolv.analysis.matgenlab.core.Settings.readSimpleYaml( ...
                            candidates(index));
                    break
                end
            end

            environment = ...
                kssolv.analysis.matgenlab.core.Settings.environmentVariables();
            environmentKeys = keys(environment);
            compatibilityKeys = ["VASP_PSP_DIR", "MAPI_KEY", "DEFAULT_FUNCTIONAL"];
            for index = 1:numel(environmentKeys)
                key = string(environmentKeys{index});
                if startsWith(key, "PMG_")
                    settings(char(key)) = environment(char(key));
                elseif any(key == compatibilityKeys)
                    settings(char("PMG_" + key)) = environment(char(key));
                end
            end

            settingKeys = keys(settings);
            for index = 1:numel(settingKeys)
                key = string(settingKeys{index});
                if endsWith(key, "_DIR")
                    settings(char(key)) = ...
                        kssolv.analysis.matgenlab.core.Settings.expandPath( ...
                            string(settings(char(key))));
                end
            end
        end

        function settings = readSimpleYaml(path)
            % Pymatgen's settings file is a flat mapping. Reject nested YAML
            % explicitly instead of silently interpreting it incorrectly.
            settings = containers.Map("KeyType", "char", "ValueType", "any");
            lines = splitlines(string(fileread(path)));
            for lineNumber = 1:numel(lines)
                line = strtrim(eraseComment(lines(lineNumber)));
                if line == ""
                    continue
                end
                token = regexp(line, ...
                    "^(?<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?<value>.*)$", ...
                    "names", "once");
                if isempty(token)
                    error("KSSOLV:Matgenlab:Settings:UnsupportedYaml", ...
                        "Unsupported YAML at %s:%d.", path, lineNumber);
                end
                settings(token.key) = parseScalar(string(token.value));
            end

            function output = eraseComment(input)
                % Comments inside quoted scalars are retained.
                inSingle = false;
                inDouble = false;
                cut = strlength(input) + 1;
                characters = char(input);
                for position = 1:numel(characters)
                    if characters(position) == "'" && ~inDouble
                        inSingle = ~inSingle;
                    elseif characters(position) == '"' && ~inSingle
                        inDouble = ~inDouble;
                    elseif characters(position) == "#" && ~inSingle && ~inDouble
                        cut = position;
                        break
                    end
                end
                output = extractBefore(input, cut);
            end

            function output = parseScalar(input)
                input = strtrim(input);
                if strlength(input) >= 2 && ...
                        ((startsWith(input, "'") && endsWith(input, "'")) || ...
                        (startsWith(input, '"') && endsWith(input, '"')))
                    output = extractBetween(input, 2, strlength(input) - 1);
                    return
                end
                if any(lower(input) == ["true", "yes"])
                    output = true;
                    return
                end
                if any(lower(input) == ["false", "no"])
                    output = false;
                    return
                end
                if any(lower(input) == ["null", "none", "~"])
                    output = [];
                    return
                end
                number = str2double(input);
                if ~isnan(number)
                    output = number;
                else
                    output = char(input);
                end
            end
        end

        function variables = environmentVariables()
            variables = containers.Map("KeyType", "char", "ValueType", "char");
            try
                environment = java.lang.System.getenv();
                iterator = environment.entrySet().iterator();
                while iterator.hasNext()
                    entry = iterator.next();
                    variables(char(entry.getKey())) = char(entry.getValue());
                end
            catch
                known = ["PMG_CONFIG_FILE", "PMG_VASP_PSP_DIR", ...
                    "PMG_MAPI_KEY", "PMG_DEFAULT_FUNCTIONAL", ...
                    "VASP_PSP_DIR", "MAPI_KEY", "DEFAULT_FUNCTIONAL"];
                for index = 1:numel(known)
                    value = getenv(known(index));
                    if ~isempty(value)
                        variables(char(known(index))) = value;
                    end
                end
            end
        end

        function path = expandPath(path)
            if startsWith(path, "~")
                home = string(getenv("HOME"));
                if home == "" && ispc
                    home = string(getenv("USERPROFILE"));
                end
                path = home + extractAfter(path, 1);
            end

            names = regexp(path, "\$\{(?<braced>[A-Za-z_][A-Za-z0-9_]*)\}" + ...
                "|\$(?<plain>[A-Za-z_][A-Za-z0-9_]*)", "names");
            for index = 1:numel(names)
                name = string(names(index).braced);
                if name == ""
                    name = string(names(index).plain);
                end
                path = regexprep(path, "\$\{?" + name + "\}?", ...
                    string(getenv(name)), "once");
            end
            path = char(path);
        end
    end
end
