classdef GaussianToComputedEntryDrone < ...
        kssolv.analysis.matgenlab.apps.borg.AbstractDrone
    %GAUSSIANTOCOMPUTEDENTRYDRONE Assimilate Gaussian output files.

    properties (SetAccess = private)
        inc_structure (1,1) logical = false
        parameters (1,:) string = strings(1,0)
        data (1,:) string = strings(1,0)
        file_extensions (1,:) string = ".log"
    end

    methods
        function obj = GaussianToComputedEntryDrone(varargin)
            options = parseOptions(varargin{:});
            obj.inc_structure = logical(options.inc_structure);
            defaults = ["functional", "basis_set", "charge", ...
                "spin_multiplicity", "route_parameters"];
            obj.parameters = unique([defaults, ...
                reshape(string(options.parameters), 1, [])], "stable");
            dataDefaults = ["stationary_type", "properly_terminated"];
            obj.data = unique([dataDefaults, ...
                reshape(string(options.data), 1, [])], "stable");
            obj.file_extensions = reshape( ...
                string(options.file_extensions), 1, []);
        end

        function text = char(~)
            text = 'GaussianToComputedEntryDrone';
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function entry = assimilate(obj, path)
            path = string(path);
            try
                run = kssolv.analysis.matgenlab.io.GaussianOutput(path);
            catch exception
                warning("KSSOLV:Matgenlab:Borg:GaussianParse", ...
                    "Unable to assimilate %s: %s", path, ...
                    exception.message);
                entry = [];
                return
            end
            parametersValue = struct();
            for name = obj.parameters
                parametersValue.(matlab.lang.makeValidName(name)) = ...
                    run.(char(name));
            end
            dataValue = struct();
            for name = obj.data
                dataValue.(matlab.lang.makeValidName(name)) = ...
                    run.(char(name));
            end
            if obj.inc_structure
                entry = kssolv.analysis.matgenlab.core. ...
                    ComputedStructureEntry(run.final_structure, ...
                    run.final_energy, "parameters", parametersValue, ...
                    "data", dataValue);
            else
                entry = kssolv.analysis.matgenlab.core.ComputedEntry( ...
                    run.final_structure.composition, run.final_energy, ...
                    "parameters", parametersValue, "data", dataValue);
            end
        end

        function paths = get_valid_paths(obj, path)
            [parent, ~, files] = walkTuple(path);
            files = reshape(string(files), 1, []);
            paths = strings(1,0);
            for file = files
                [~, ~, extension] = fileparts(file);
                if any(string(extension) == obj.file_extensions)
                    paths(end + 1) = string(fullfile(parent, file)); %#ok<AGROW>
                end
            end
        end

        function value = as_dict(obj)
            initArgs = struct();
            initArgs.inc_structure = obj.inc_structure;
            initArgs.parameters = cellstr(obj.parameters);
            initArgs.data = cellstr(obj.data);
            initArgs.file_extensions = cellstr(obj.file_extensions);
            value = struct();
            value.init_args = initArgs;
            value.x_module = "pymatgen.apps.borg.hive";
            value.x_class = "GaussianToComputedEntryDrone";
        end
    end

    methods (Static)
        function obj = from_dict(value)
            initArgs = value.init_args;
            obj = kssolv.analysis.matgenlab.apps.borg. ...
                GaussianToComputedEntryDrone( ...
                fieldOr(initArgs, "inc_structure", false), ...
                fieldOr(initArgs, "parameters", {}), ...
                fieldOr(initArgs, "data", {}), ...
                fieldOr(initArgs, "file_extensions", {".log"}));
        end
    end
end

function options = parseOptions(varargin)
options = struct("inc_structure", false, "parameters", {{}}, ...
    "data", {{}}, "file_extensions", {{".log"}});
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
