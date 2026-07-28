function add_config_var(tokens, backup_suffix, varargin)
%ADD_CONFIG_VAR Add or update a flat pymatgen YAML settings file.
%
% A config_path option is mandatory; this function never discovers or
% writes a real user configuration implicitly.

if nargin < 2, backup_suffix = ""; end
options = parseOptions(varargin{:});
tokens = reshape(string(tokens), 1, []);
if mod(numel(tokens), 2) ~= 0
    error("KSSOLV:Matgenlab:PmgConfig:UnevenTokens", ...
        "Uneven number %d of tokens; every key needs a value.", ...
        numel(tokens));
end
configPath = canonical(options.config_path);
oldPath = "";
if string(options.old_config_path) ~= ""
    oldPath = canonical(options.old_config_path);
end
if isfile(configPath)
    selectedPath = configPath;
elseif oldPath ~= "" && isfile(oldPath)
    selectedPath = oldPath;
else
    selectedPath = configPath;
end
[order, values] = readFlatYaml(selectedPath);
if isfile(selectedPath) && string(backup_suffix) ~= ""
    copyfile(selectedPath, selectedPath + string(backup_suffix), "f");
end
for index = 1:2:numel(tokens)
    key = tokens(index);
    validateKey(key);
    if ~isKey(values, char(key))
        order(end + 1, 1) = key; %#ok<AGROW>
    end
    values(char(key)) = parseToken(tokens(index + 1));
end
writeFlatYaml(selectedPath, order, values);
end

function options = parseOptions(varargin)
options = struct("config_path", "", "old_config_path", "");
if isscalar(varargin) && isstruct(varargin{1})
    input = varargin{1};
    names = fieldnames(input);
    for index = 1:numel(names)
        options.(names{index}) = input.(names{index});
    end
elseif mod(numel(varargin), 2) == 0
    for index = 1:2:numel(varargin)
        options.(char(string(varargin{index}))) = varargin{index + 1};
    end
else
    error("KSSOLV:Matgenlab:PmgConfig:Options", ...
        "Options must be a struct or name-value pairs.");
end
if string(options.config_path) == ""
    error("KSSOLV:Matgenlab:PmgConfig:ConfigPath", ...
        "An explicit config_path is required.");
end
end

function [order, values] = readFlatYaml(path)
order = strings(0, 1);
values = containers.Map("KeyType", "char", "ValueType", "any");
if ~isfile(path), return; end
lines = splitlines(string(fileread(path)));
for lineNumber = 1:numel(lines)
    line = strtrim(lines(lineNumber));
    if line == "" || startsWith(line, "#"), continue; end
    token = regexp(line, ...
        "^(?<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?<value>.*)$", ...
        "names", "once");
    if isempty(token)
        error("KSSOLV:Matgenlab:PmgConfig:ConfigYaml", ...
            "Unsupported flat YAML at %s:%d.", path, lineNumber);
    end
    key = string(token.key);
    if ~isKey(values, token.key), order(end + 1, 1) = key; end %#ok<AGROW>
    values(token.key) = parseYamlScalar(string(token.value));
end
end

function output = parseYamlScalar(input)
input = strtrim(input);
if input == ""
    output = struct("kind", "null", "value", []);
elseif strlength(input) >= 2 && ...
        ((startsWith(input, "'") && endsWith(input, "'")) || ...
        (startsWith(input, '"') && endsWith(input, '"')))
    output = struct("kind", "string", ...
        "value", replace(extractBetween(input, 2, ...
        strlength(input) - 1), "''", "'"));
elseif any(lower(input) == ["true", "yes"])
    output = struct("kind", "logical", "value", true);
elseif any(lower(input) == ["false", "no"])
    output = struct("kind", "logical", "value", false);
elseif any(lower(input) == ["null", "none", "~"])
    output = struct("kind", "null", "value", []);
elseif ~isnan(str2double(input))
    output = struct("kind", "number", "value", str2double(input));
else
    output = struct("kind", "string", "value", input);
end
end

function output = parseToken(input)
switch lower(input)
    case "true"
        output = struct("kind", "logical", "value", true);
    case "false"
        output = struct("kind", "logical", "value", false);
    case {"none", "null"}
        output = struct("kind", "null", "value", []);
    otherwise
        output = struct("kind", "string", "value", input);
end
end

function writeFlatYaml(path, order, values)
parent = string(fileparts(path));
if parent ~= "" && ~isfolder(parent)
    [created, message] = mkdir(parent);
    if ~created
        error("KSSOLV:Matgenlab:PmgConfig:CreateDirectory", ...
            "Unable to create '%s': %s", parent, message);
    end
end
file = fopen(path, "w", "n", "UTF-8");
if file < 0
    error("KSSOLV:Matgenlab:PmgConfig:ConfigWrite", ...
        "Unable to write config file: %s", path);
end
cleanup = onCleanup(@() fclose(file));
for index = 1:numel(order)
    key = char(order(index));
    fprintf(file, "%s:%s\n", key, encodeScalar(values(key)));
end
clear cleanup
end

function text = encodeScalar(record)
switch record.kind
    case "null"
        text = "";
    case "logical"
        if record.value, text = " true"; else, text = " false"; end
    case "number"
        text = " " + string(record.value);
    otherwise
        value = string(record.value);
        lowerValue = lower(value);
        needsQuotes = any(lowerValue == ...
            ["true", "false", "none", "null", "yes", "no", "~"]) || ...
            ~isnan(str2double(value)) || ...
            isempty(regexp(value, "^[A-Za-z_./~$][A-Za-z0-9_./~${}:+-]*$", ...
            "once"));
        if needsQuotes
            text = " '" + replace(value, "'", "''") + "'";
        else
            text = " " + value;
        end
end
text = char(text);
end

function validateKey(key)
if isempty(regexp(key, "^[A-Za-z_][A-Za-z0-9_]*$", "once"))
    error("KSSOLV:Matgenlab:PmgConfig:ConfigKey", ...
        "Invalid configuration key: %s", key);
end
end

function path = canonical(path)
path = string(path);
if ~startsWith(path, filesep) && ...
        ~(ispc && ~isempty(regexp(path, "^[A-Za-z]:[\\/]", "once")))
    path = fullfile(pwd, path);
end
path = string(char(java.io.File(char(path)).getCanonicalPath()));
end
