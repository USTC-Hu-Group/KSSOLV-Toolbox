classdef StandardTransmuter < handle
    %STANDARDTRANSMUTER Apply transformations and filters to a collection.

    properties
        transformed_structures cell
        ncores
    end

    methods
        function obj = StandardTransmuter(transformedStructures, ...
                transformations, extendCollection, ncores)
            if nargin < 2, transformations = {}; end
            if nargin < 3, extendCollection = 0; end
            if nargin < 4, ncores = []; end
            if ~iscell(transformedStructures)
                transformedStructures = num2cell(transformedStructures);
            end
            obj.transformed_structures = ...
                reshape(transformedStructures, 1, []);
            obj.ncores = ncores;
            if ~isempty(ncores) && (~isscalar(ncores) || ncores < 1 || ...
                    ncores ~= fix(ncores))
                error("KSSOLV:Matgenlab:StandardTransmuter:Cores", ...
                    "ncores must be empty or a positive integer.");
            end
            if ~iscell(transformations), transformations = num2cell(transformations); end
            for index = 1:numel(transformations)
                obj.append_transformation( ...
                    transformations{index}, extendCollection);
            end
        end

        function value = length(obj)
            value = numel(obj.transformed_structures);
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                value = obj.transformed_structures{reference(1).subs{1}};
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, reference);
            end
        end

        function undo_last_change(obj)
            for index = 1:numel(obj.transformed_structures)
                obj.transformed_structures{index}.undo_last_change();
            end
        end

        function redo_next_change(obj)
            for index = 1:numel(obj.transformed_structures)
                obj.transformed_structures{index}.redo_next_change();
            end
        end

        function changed = append_transformation(obj, transformation, ...
                extendCollection, clearRedo)
            if nargin < 3, extendCollection = false; end
            if nargin < 4, clearRedo = true; end
            if ~isempty(obj.ncores) && transformation.use_multiprocessing
                warning("KSSOLV:Matgenlab:StandardTransmuter:SerialFallback", ...
                    "MATLAB alchemy preserves deterministic ordering and " + ...
                    "applies this transformation serially.");
            end
            alternatives = cell(1, 0);
            for index = 1:numel(obj.transformed_structures)
                generated = obj.transformed_structures{index}. ...
                    append_transformation(transformation, ...
                    extendCollection, clearRedo);
                alternatives = [alternatives, generated]; %#ok<AGROW>
            end
            obj.transformed_structures = ...
                [obj.transformed_structures, alternatives];
            changed = cellfun(@(item) numel(item.history) > 1, ...
                obj.transformed_structures);
        end

        function extend_transformations(obj, transformations)
            if ~iscell(transformations), transformations = num2cell(transformations); end
            for index = 1:numel(transformations)
                obj.append_transformation(transformations{index});
            end
        end

        function apply_filter(obj, structureFilter)
            keep = false(1, numel(obj.transformed_structures));
            for index = 1:numel(obj.transformed_structures)
                keep(index) = structureFilter.test( ...
                    obj.transformed_structures{index}.final_structure);
            end
            obj.transformed_structures = obj.transformed_structures(keep);
            for index = 1:numel(obj.transformed_structures)
                obj.transformed_structures{index}. ...
                    append_filter(structureFilter);
            end
        end

        function write_vasp_input(obj, varargin)
            kssolv.analysis.matgenlab.alchemy.batch_write_vasp_input( ...
                obj.transformed_structures, varargin{:});
        end

        function set_parameter(obj, key, value)
            for index = 1:numel(obj.transformed_structures)
                obj.transformed_structures{index}.set_parameter(key, value);
            end
        end

        function add_tags(obj, tags)
            obj.set_parameter("tags", tags);
        end

        function append_transformed_structures(obj, value)
            if isa(value, ...
                    "kssolv.analysis.matgenlab.alchemy.StandardTransmuter")
                values = value.transformed_structures;
            else
                values = value;
                if ~iscell(values), values = num2cell(values); end
            end
            if ~all(cellfun(@(item) isa(item, ...
                    "kssolv.analysis.matgenlab.alchemy.TransformedStructure"), ...
                    values))
                error("KSSOLV:Matgenlab:StandardTransmuter:StructureType", ...
                    "Some transformed structure has incorrect type.");
            end
            obj.transformed_structures = ...
                [obj.transformed_structures, reshape(values, 1, [])];
        end
    end

    methods (Static)
        function obj = from_structures(structures, transformations, ...
                extendCollection)
            if nargin < 2, transformations = {}; end
            if nargin < 3, extendCollection = 0; end
            if ~iscell(structures), structures = num2cell(structures); end
            transformed = cellfun(@(structure) ...
                kssolv.analysis.matgenlab.alchemy. ...
                TransformedStructure(structure), reshape(structures, 1, []), ...
                "UniformOutput", false);
            obj = kssolv.analysis.matgenlab.alchemy.StandardTransmuter( ...
                transformed, transformations, extendCollection);
        end
    end
end
