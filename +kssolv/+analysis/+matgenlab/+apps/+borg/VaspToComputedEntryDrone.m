classdef VaspToComputedEntryDrone < ...
        kssolv.analysis.matgenlab.apps.borg.AbstractDrone
    %VASPTOCOMPUTEDENTRYDRONE Assimilate VASP runs into computed entries.
    %
    % This native implementation follows pymatgen 2026.5.4. It recognizes
    % normal vasprun.xml runs and two-stage relax1/relax2 layouts.

    properties (SetAccess = private)
        inc_structure (1,1) logical = false
        parameters (1,:) string = strings(1,0)
        data (1,:) string = strings(1,0)
    end

    methods
        function obj = VaspToComputedEntryDrone(varargin)
            options = parseOptions(varargin{:});
            obj.inc_structure = logical(options.inc_structure);
            defaults = ["is_hubbard", "hubbards", "potcar_spec", ...
                "potcar_symbols", "run_type"];
            obj.parameters = unique([defaults, ...
                reshape(string(options.parameters), 1, [])], "stable");
            obj.data = reshape(string(options.data), 1, []);
        end

        function text = char(~)
            text = 'VaspToComputedEntryDrone';
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function entry = assimilate(obj, path)
            path = string(path);
            names = directoryNames(path);
            if any(names == "relax1") && any(names == "relax2")
                candidates = matchingFiles(fullfile(path, "relax2"), ...
                    "vasprun.xml*");
                if isempty(candidates)
                    entry = [];
                    return
                end
                filename = candidates(1);
            else
                candidates = matchingFiles(path, "vasprun.xml*");
                if isempty(candidates)
                    entry = [];
                    return
                end
                filename = candidates(end);
                if numel(candidates) > 1
                    warning("KSSOLV:Matgenlab:Borg:MultipleVasprun", ...
                        "%d vasprun.xml.* found. %s is being parsed.", ...
                        numel(candidates), filename);
                end
            end
            try
                run = kssolv.analysis.matgenlab.io.vasp.Vasprun(filename);
                entry = run.get_computed_entry(obj.inc_structure, ...
                    "parameters", cellstr(obj.parameters), ...
                    "data", cellstr(obj.data));
            catch exception
                warning("KSSOLV:Matgenlab:Borg:VasprunParse", ...
                    "Unable to assimilate %s: %s", filename, ...
                    exception.message);
                entry = [];
            end
        end

        function paths = get_valid_paths(~, path)
            [parent, subdirectories, ~] = walkTuple(path);
            normalized = replace(string(parent), "\", "/");
            subdirectories = reshape(string(subdirectories), 1, []);
            if any(subdirectories == "relax1") && ...
                    any(subdirectories == "relax2")
                paths = string(parent);
                return
            end
            if endsWith(normalized, "/relax1") || ...
                    endsWith(normalized, "/relax2")
                paths = strings(1,0);
                return
            end
            hasVasprun = ~isempty(matchingFiles(parent, "vasprun.xml*"));
            hasPoscar = ~isempty(matchingFiles(parent, "POSCAR*"));
            hasOszicar = ~isempty(matchingFiles(parent, "OSZICAR*"));
            if hasVasprun || (hasPoscar && hasOszicar)
                paths = string(parent);
            else
                paths = strings(1,0);
            end
        end

        function value = as_dict(obj)
            initArgs = struct();
            initArgs.inc_structure = obj.inc_structure;
            initArgs.parameters = cellstr(obj.parameters);
            initArgs.data = cellstr(obj.data);
            value = struct();
            value.init_args = initArgs;
            value.x_module = "pymatgen.apps.borg.hive";
            value.x_class = "VaspToComputedEntryDrone";
        end
    end

    methods (Static)
        function obj = from_dict(value)
            initArgs = value.init_args;
            obj = kssolv.analysis.matgenlab.apps.borg. ...
                VaspToComputedEntryDrone( ...
                fieldOr(initArgs, "inc_structure", false), ...
                fieldOr(initArgs, "parameters", {}), ...
                fieldOr(initArgs, "data", {}));
        end
    end
end

function options = parseOptions(varargin)
options = struct("inc_structure", false, "parameters", {{}}, "data", {{}});
names = string(fieldnames(options));
position = 1;
index = 1;
while index <= numel(varargin)
    value = varargin{index};
    if (ischar(value) || (isstring(value) && isscalar(value))) && ...
            any(strcmpi(string(value), names))
        if index == numel(varargin)
            error("KSSOLV:Matgenlab:Borg:Arguments", ...
                "Name-value arguments must occur in pairs.");
        end
        match = find(strcmpi(string(value), names), 1);
        options.(char(names(match))) = varargin{index + 1};
        index = index + 2;
    else
        if position > numel(names)
            error("KSSOLV:Matgenlab:Borg:Arguments", ...
                "Too many positional arguments.");
        end
        options.(char(names(position))) = value;
        position = position + 1;
        index = index + 1;
    end
end
end

function names = directoryNames(path)
listing = dir(path);
listing = listing([listing.isdir]);
names = string({listing.name});
names = names(~ismember(names, [".", ".."]));
end

function paths = matchingFiles(parent, pattern)
listing = dir(fullfile(string(parent), string(pattern)));
listing = listing(~[listing.isdir]);
if isempty(listing)
    paths = strings(1,0);
else
    paths = sort(string(fullfile({listing.folder}, {listing.name})));
end
end

function [parent, subdirectories, files] = walkTuple(path)
if iscell(path) && numel(path) >= 3
    parent = path{1};
    subdirectories = path{2};
    files = path{3};
elseif isstruct(path) && all(isfield(path, ...
        ["parent", "subdirectories", "files"]))
    parent = path.parent;
    subdirectories = path.subdirectories;
    files = path.files;
else
    error("KSSOLV:Matgenlab:Borg:WalkTuple", ...
        "path must be {parent, subdirectories, files}.");
end
end

function value = fieldOr(data, name, default)
if isfield(data, name)
    value = data.(name);
else
    value = default;
end
end
