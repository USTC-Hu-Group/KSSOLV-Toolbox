classdef TransformedStructure < handle
    %TRANSFORMEDSTRUCTURE Structure plus a reversible transformation history.

    properties
        final_structure
        history cell = cell(1, 0)
        other_parameters = struct()
    end

    properties (Access = private)
        undone_ cell = cell(0, 2)
    end

    properties (Dependent, SetAccess = private)
        was_modified
        structures
    end

    methods
        function obj = TransformedStructure(structure, transformations, ...
                history, otherParameters)
            if nargin < 2 || isempty(transformations), transformations = {}; end
            if nargin < 3 || isempty(history), history = {}; end
            if nargin < 4 || isempty(otherParameters), otherParameters = struct(); end
            if ~iscell(transformations), transformations = num2cell(transformations); end
            if ~iscell(history)
                if isstruct(history), history = num2cell(history);
                else, history = {history};
                end
            end
            obj.final_structure = structure;
            obj.history = reshape(history, 1, []);
            obj.other_parameters = otherParameters;
            for index = 1:numel(transformations)
                obj.append_transformation(transformations{index});
            end
        end

        function undo_last_change(obj)
            if isempty(obj.history)
                error("KSSOLV:Matgenlab:TransformedStructure:Undo", ...
                    "No more changes to undo");
            end
            latest = obj.history{end};
            if ~isstruct(latest) || ~isfield(latest, "input_structure")
                error("KSSOLV:Matgenlab:TransformedStructure:UndoInput", ...
                    "Can't undo. Latest history has no input_structure");
            end
            obj.history(end) = [];
            obj.undone_(end + 1, :) = {latest, obj.final_structure};
            input = latest.input_structure;
            if isstruct(input)
                input = kssolv.analysis.matgenlab.core.Structure.from_dict(input);
            end
            obj.final_structure = input;
        end

        function redo_next_change(obj)
            if isempty(obj.undone_)
                error("KSSOLV:Matgenlab:TransformedStructure:Redo", ...
                    "No more changes to redo");
            end
            obj.history{end + 1} = obj.undone_{end, 1};
            obj.final_structure = obj.undone_{end, 2};
            obj.undone_(end, :) = [];
        end

        function alternatives = append_transformation(obj, transformation, ...
                returnAlternatives, clearRedo)
            if nargin < 3, returnAlternatives = false; end
            if nargin < 4, clearRedo = true; end
            if clearRedo, obj.undone_ = cell(0, 2); end
            alternatives = {};
            inputStructure = obj.final_structure;
            inputDictionary = inputStructure.as_dict();

            if returnAlternatives && transformation.is_one_to_many
                ranked = transformation.apply_transformation( ...
                    inputStructure, returnAlternatives);
                if ~iscell(ranked), ranked = {ranked}; end
                if isempty(ranked)
                    error("KSSOLV:Matgenlab:TransformedStructure:Alternatives", ...
                        "One-to-many transformation returned no structures.");
                end
                alternatives = cell(1, numel(ranked) - 1);
                for index = 2:numel(ranked)
                    [structure, actual, output] = unpackRanked( ...
                        ranked{index}, transformation);
                    historyEntry = transformationHistory( ...
                        actual, inputDictionary, output);
                    alternativeHistory = obj.history;
                    alternativeHistory{numel(alternativeHistory) + 1} = ...
                        historyEntry;
                    alternatives{index - 1} = ...
                        kssolv.analysis.matgenlab.alchemy. ...
                        TransformedStructure(structure, {}, ...
                        alternativeHistory, cloneParameters( ...
                        obj.other_parameters));
                end
                [structure, actual, output] = unpackRanked( ...
                    ranked{1}, transformation);
                obj.history{end + 1} = transformationHistory( ...
                    actual, inputDictionary, output);
                obj.final_structure = structure;
                return
            end

            structure = transformation.apply_transformation(inputStructure);
            obj.history{end + 1} = transformationHistory( ...
                transformation, inputDictionary, struct());
            obj.final_structure = structure;
        end

        function append_filter(obj, structureFilter)
            entry = structureFilter.as_dict();
            entry.input_structure = obj.final_structure.as_dict();
            obj.history{end + 1} = entry;
        end

        function extend_transformations(obj, transformations, returnAlternatives)
            if nargin < 3, returnAlternatives = false; end
            if ~iscell(transformations), transformations = num2cell(transformations); end
            for index = 1:numel(transformations)
                obj.append_transformation( ...
                    transformations{index}, returnAlternatives);
            end
        end

        function value = get_vasp_input(obj, vaspInputSet, varargin)
            if nargin < 2 || isempty(vaspInputSet)
                missingVaspInputSet();
            end
            inputSet = constructInputSet(vaspInputSet, ...
                obj.final_structure, varargin{:});
            if ismethod(inputSet, "get_input_set")
                value = inputSet.get_input_set();
            elseif isa(inputSet, "kssolv.analysis.matgenlab.io.vasp.VaspInput")
                value = inputSet;
            else
                error("KSSOLV:Matgenlab:TransformedStructure:VaspInputSet", ...
                    "Input-set factory must return get_input_set() or VaspInput.");
            end
            encoded = char(kssolv.analysis.matgenlab.util.encode(obj.as_dict()));
            if isa(value, "containers.Map")
                value("transformations.json") = encoded;
            elseif isstruct(value)
                value.transformations_json = encoded;
            elseif isa(value, "kssolv.analysis.matgenlab.io.vasp.VaspInput")
                value = struct("vasp_input", value, ...
                    "transformations_json", encoded);
            end
        end

        function write_vasp_input(obj, vaspInputSet, outputDir, ...
                createDirectory, varargin)
            if nargin < 2 || isempty(vaspInputSet), missingVaspInputSet(); end
            if nargin < 3 || isempty(outputDir), outputDir = "."; end
            if nargin < 4, createDirectory = true; end
            inputSet = constructInputSet(vaspInputSet, ...
                obj.final_structure, varargin{:});
            if ismethod(inputSet, "write_input")
                try
                    inputSet.write_input(output_dir = string(outputDir), ...
                        make_dir_if_not_present = logical(createDirectory));
                catch exception
                    if ~startsWith(exception.identifier, "MATLAB:")
                        rethrow(exception)
                    end
                    inputSet.write_input(outputDir, createDirectory);
                end
            elseif isa(inputSet, "kssolv.analysis.matgenlab.io.vasp.VaspInput")
                inputSet.write_input(output_dir = string(outputDir), ...
                    make_dir_if_not_present = logical(createDirectory));
            else
                error("KSSOLV:Matgenlab:TransformedStructure:VaspInputSet", ...
                    "Input-set factory result does not implement write_input().");
            end
            if ~isfolder(outputDir)
                if createDirectory, mkdir(outputDir);
                else
                    error("KSSOLV:Matgenlab:TransformedStructure:Directory", ...
                        "Output directory '%s' does not exist.", outputDir);
                end
            end
            filename = fullfile(outputDir, "transformations.json");
            writeText(filename, ...
                kssolv.analysis.matgenlab.util.encode(obj.as_dict(), ...
                PrettyPrint = true));
        end

        function result = set_parameter(obj, key, value)
            if isa(obj.other_parameters, "containers.Map")
                obj.other_parameters(char(string(key))) = value;
            else
                name = matlab.lang.makeValidName(string(key));
                obj.other_parameters.(name) = value;
            end
            result = obj;
        end

        function value = get.was_modified(obj)
            values = obj.structures;
            value = numel(values) >= 2 && ...
                values{end} ~= values{end - 1};
        end

        function value = get.structures(obj)
            value = cell(1, 0);
            for index = 1:numel(obj.history)
                entry = obj.history{index};
                if isstruct(entry) && isfield(entry, "input_structure")
                    structure = entry.input_structure;
                    if isstruct(structure)
                        structure = kssolv.analysis.matgenlab.core. ...
                            Structure.from_dict(structure);
                    end
                    value{end + 1} = structure; %#ok<AGROW>
                end
            end
            value{end + 1} = obj.final_structure;
        end

        function value = asDict(obj)
            value = obj.final_structure.as_dict();
            value.x_module = "pymatgen.alchemy.materials";
            value.x_class = "TransformedStructure";
            value.history = obj.history;
            value.last_modified = utcNow();
            value.other_parameters = obj.other_parameters;
        end

        function value = as_dict(obj), value = obj.asDict(); end

        function snl = to_snl(obj, authors, varargin)
            snlHistory = cell(1, numel(obj.history));
            for index = 1:numel(obj.history)
                description = obj.history{index};
                name = "pymatgen";
                url = "http://pypi.python.org/pypi/pymatgen";
                if isstruct(description) && isfield(description, "x_snl")
                    metadata = description.x_snl;
                    description = rmfield(description, "x_snl");
                    if isfield(metadata, "name"), name = metadata.name; end
                    if isfield(metadata, "url"), url = metadata.url; end
                end
                snlHistory{index} = kssolv.analysis.matgenlab.util. ...
                    HistoryNode(name, url, description);
            end
            if ~isemptyMapping(obj.other_parameters)
                warning("KSSOLV:Matgenlab:TransformedStructure:SNLParameters", ...
                    "Data in TransformedStructure.other_parameters discarded during type conversion to SNL");
            end
            snl = constructSNL( ...
                obj.final_structure, authors, snlHistory, varargin{:});
        end
    end

    methods (Static)
        function obj = from_cif_str(cifString, transformations, ...
                primitive, occupancyTolerance)
            if nargin < 2, transformations = {}; end
            if nargin < 3, primitive = true; end
            if nargin < 4, occupancyTolerance = 1; end
            parser = kssolv.analysis.matgenlab.io.cif.CifParser. ...
                from_str(cifString, ...
                occupancy_tolerance = occupancyTolerance);
            parsed = parser.parse_structures(primitive = primitive, ...
                on_error = "raise");
            dictionary = parser.as_dict();
            source = "uploaded cif";
            cifData = struct();
            if isa(dictionary, "containers.Map") && ~isempty(keys(dictionary))
                headers = keys(dictionary);
                cifData = dictionary(headers{1});
                if isa(cifData, "containers.Map") && ...
                        isKey(cifData, "_database_code_ICSD")
                    source = string(cifData("_database_code_ICSD")) + "-ICSD";
                elseif isstruct(cifData) && ...
                        isfield(cifData, "x_database_code_ICSD")
                    source = string(cifData.x_database_code_ICSD) + "-ICSD";
                end
            end
            sourceHistory = {struct("source", source, "datetime", utcNow(), ...
                "original_file", replace(string(cifString), "'", '"'), ...
                "cif_data", cifData)};
            obj = kssolv.analysis.matgenlab.alchemy.TransformedStructure( ...
                parsed{1}, transformations, sourceHistory);
        end

        function obj = from_poscar_str(poscarString, transformations)
            if nargin < 2, transformations = {}; end
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                from_str(poscarString);
            if ~poscar.true_names
                error("KSSOLV:Matgenlab:TransformedStructure:PoscarNames", ...
                    "Transformation can be created only from POSCAR strings with proper VASP5 element symbols.");
            end
            sourceHistory = {struct("source", "POSCAR", ...
                "datetime", utcNow(), ...
                "original_file", replace(string(poscarString), "'", '"'))};
            obj = kssolv.analysis.matgenlab.alchemy.TransformedStructure( ...
                poscar.structure, transformations, sourceHistory);
        end

        function obj = from_dict(value)
            structure = kssolv.analysis.matgenlab.core.Structure.from_dict(value);
            storedHistory = value.history;
            if isstruct(storedHistory), storedHistory = num2cell(storedHistory); end
            if ~iscell(storedHistory), storedHistory = {storedHistory}; end
            if isfield(value, "other_parameters")
                parameters = value.other_parameters;
            else
                parameters = struct();
            end
            obj = kssolv.analysis.matgenlab.alchemy.TransformedStructure( ...
                structure, {}, storedHistory, parameters);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.alchemy. ...
                TransformedStructure.from_dict(value);
        end

        function obj = from_snl(snl)
            storedHistory = cell(1, numel(snl.history));
            for index = 1:numel(snl.history)
                node = snl.history{index};
                description = node.description;
                if ~isstruct(description)
                    description = struct("description", description);
                end
                description.x_snl = struct( ...
                    "url", node.url, "name", node.name);
                storedHistory{index} = description;
            end
            obj = kssolv.analysis.matgenlab.alchemy.TransformedStructure( ...
                snl.structure, {}, storedHistory);
        end
    end
end

function entry = transformationHistory(transformation, input, output)
entry = transformation.as_dict();
entry.input_structure = input;
entry.output_parameters = output;
end

function [structure, transformation, output] = unpackRanked(value, fallback)
transformation = fallback;
output = struct();
if isstruct(value)
    if ~isfield(value, "structure")
        error("KSSOLV:Matgenlab:TransformedStructure:RankedEntry", ...
            "Ranked transformation entry has no structure field.");
    end
    structure = value.structure;
    names = fieldnames(value);
    for index = 1:numel(names)
        name = names{index};
        if strcmp(name, "transformation")
            transformation = value.(name);
        elseif ~strcmp(name, "structure")
            output.(name) = value.(name);
        end
    end
else
    structure = value;
end
end

function value = cloneParameters(value)
value = kssolv.analysis.matgenlab.util.toDict(value);
end

function value = utcNow()
value = string(datetime("now", "TimeZone", "UTC", ...
    "Format", "yyyy-MM-dd HH:mm:ss.SSSSSSXXX"));
end

function inputSet = constructInputSet(factory, structure, varargin)
if isa(factory, "function_handle")
    inputSet = factory(structure, varargin{:});
elseif ischar(factory) || (isstring(factory) && isscalar(factory))
    constructor = str2func(string(factory));
    inputSet = constructor(structure, varargin{:});
elseif isobject(factory)
    inputSet = factory;
else
    error("KSSOLV:Matgenlab:TransformedStructure:VaspInputSet", ...
        "vasp_input_set must be a factory, class name, or input-set object.");
end
end

function missingVaspInputSet()
error("KSSOLV:Matgenlab:TransformedStructure:MissingMPRelaxSet", ...
    "MPRelaxSet is outside the frozen implemented module set. Supply a " + ...
    "VaspInputSet-compatible factory explicitly.");
end

function writeText(filename, value)
file = fopen(filename, "w");
if file < 0
    error("KSSOLV:Matgenlab:TransformedStructure:Write", ...
        "Cannot open '%s' for writing.", filename);
end
cleanup = onCleanup(@() fclose(file));
fwrite(file, char(value), "char");
end

function value = isemptyMapping(mapping)
if isa(mapping, "containers.Map"), value = mapping.Count == 0;
elseif isstruct(mapping), value = isempty(fieldnames(mapping));
else, value = isempty(mapping);
end
end

function snl = constructSNL(structure, authors, history, varargin)
options = struct("projects", {{}}, "references", "", "remarks", {{}}, ...
    "data", struct(), "created_at", []);
if mod(numel(varargin), 2) ~= 0
    error("KSSOLV:Matgenlab:TransformedStructure:SNLArguments", ...
        "SNL options must be supplied as name-value pairs.");
end
for index = 1:2:numel(varargin)
    name = char(lower(string(varargin{index})));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:TransformedStructure:SNLOption", ...
            "Unknown StructureNL option '%s'.", name);
    end
    options.(name) = varargin{index + 1};
end
snl = kssolv.analysis.matgenlab.util.StructureNL( ...
    structure, authors, options.projects, options.references, ...
    options.remarks, options.data, history, options.created_at);
end
