classdef TensorCollection < kssolv.analysis.matgenlab.util.MSONable
    %TENSORCOLLECTION Ordered heterogeneous-rank collection of tensors.

    properties (SetAccess = private)
        tensors cell
        base_class (1,1) string
    end

    properties (Dependent, SetAccess = private)
        symmetrized
        voigt
        ranks
        voigt_symmetrized
    end

    methods
        function obj = TensorCollection(tensor_list, base_class)
            arguments
                tensor_list = {}
                base_class (1,1) string = ...
                    "kssolv.analysis.matgenlab.core.Tensor"
            end
            if ~iscell(tensor_list)
                if isnumeric(tensor_list) && ~ismatrix(tensor_list)
                    count = size(tensor_list,1);
                    converted = cell(1,count);
                    for index = 1:count
                        converted{index} = squeeze(tensor_list(index,:,:,:));
                    end
                    tensor_list = converted;
                else
                    tensor_list = {tensor_list};
                end
            end
            obj.tensors = cell(size(tensor_list));
            for index = 1:numel(tensor_list)
                if isa(tensor_list{index}, base_class)
                    obj.tensors{index} = tensor_list{index};
                else
                    obj.tensors{index} = feval(base_class, tensor_list{index});
                end
            end
            obj.base_class = base_class;
        end

        function n = length(obj)
            n = numel(obj.tensors);
        end

        function varargout = subsref(obj, subscript)
            if subscript(1).type == "()"
                indices = subscript(1).subs{1};
                if isscalar(indices)
                    result = obj.tensors{indices};
                else
                    result = kssolv.analysis.matgenlab.core.TensorCollection( ...
                        obj.tensors(indices), obj.base_class);
                end
                if numel(subscript) > 1
                    result = builtin("subsref", result, subscript(2:end));
                end
                varargout{1} = result;
            elseif subscript(1).type == "{}"
                result = obj.tensors{subscript(1).subs{:}};
                if numel(subscript) > 1
                    result = builtin("subsref", result, subscript(2:end));
                end
                varargout{1} = result;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, subscript);
            end
        end

        function result = zeroed(obj, tol)
            if nargin < 2
                tol = 0.001;
            end
            result = obj.map(@(tensor) tensor.zeroed(tol));
        end

        function result = transform(obj, symm_op)
            result = obj.map(@(tensor) tensor.transform(symm_op));
        end

        function result = rotate(obj, matrix, tol)
            if nargin < 3
                tol = 0.001;
            end
            result = obj.map(@(tensor) tensor.rotate(matrix,tol));
        end

        function result = get.symmetrized(obj)
            result = obj.map(@(tensor) tensor.symmetrized);
        end

        function tf = is_symmetric(obj, tol)
            if nargin < 2
                tol = 1e-5;
            end
            tf = all(cellfun(@(tensor) tensor.is_symmetric(tol), ...
                obj.tensors));
        end

        function result = fit_to_structure(obj, structure, symprec)
            if nargin < 3
                symprec = 0.1;
            end
            result = obj.map(@(tensor) ...
                tensor.fit_to_structure(structure,symprec));
        end

        function tf = is_fit_to_structure(obj, structure, tol)
            if nargin < 3
                tol = 0.01;
            end
            tf = all(cellfun(@(tensor) ...
                tensor.is_fit_to_structure(structure,tol), obj.tensors));
        end

        function values = get.voigt(obj)
            values = cellfun(@(tensor) tensor.voigt, obj.tensors, ...
                UniformOutput=false);
        end

        function values = get.ranks(obj)
            values = cellfun(@(tensor) tensor.rank, obj.tensors);
        end

        function tf = is_voigt_symmetric(obj, tol)
            if nargin < 2
                tol = 1e-6;
            end
            tf = all(cellfun(@(tensor) ...
                tensor.is_voigt_symmetric(tol), obj.tensors));
        end

        function result = convert_to_ieee(obj, structure, initial_fit, ...
                refine_rotation)
            if nargin < 3
                initial_fit = true;
            end
            if nargin < 4
                refine_rotation = true;
            end
            result = obj.map(@(tensor) tensor.convert_to_ieee( ...
                structure,initial_fit,refine_rotation));
        end

        function result = round(obj, varargin)
            result = obj.map(@(tensor) tensor.round(varargin{:}));
        end

        function result = get.voigt_symmetrized(obj)
            result = obj.map(@(tensor) tensor.voigt_symmetrized);
        end

        function data = asDict(obj, voigt)
            if nargin < 2
                voigt = false;
            end
            if voigt
                tensorList = obj.voigt;
            else
                tensorList = cellfun(@double, obj.tensors, ...
                    UniformOutput=false);
            end
            data = struct( ...
                "x_module", "pymatgen.core.tensors", ...
                "x_class", "TensorCollection", ...
                "tensor_list", {tensorList});
            if voigt
                data.voigt = true;
            end
        end

        function data = as_dict(obj, varargin)
            data = obj.asDict(varargin{:});
        end
    end

    methods (Static)
        function obj = from_voigt(voigt_input_list, base_class)
            if nargin < 2
                base_class = "kssolv.analysis.matgenlab.core.Tensor";
            end
            if ~iscell(voigt_input_list)
                error("KSSOLV:Matgenlab:TensorCollection:CellRequired", ...
                    "voigt_input_list must be a cell array.");
            end
            tensors = cellfun(@(value) ...
                feval(base_class + ".from_voigt", value), ...
                voigt_input_list, UniformOutput=false);
            obj = kssolv.analysis.matgenlab.core.TensorCollection( ...
                tensors, base_class);
        end

        function obj = from_dict(data)
            tensors = data.tensor_list;
            if isfield(data,"voigt") && data.voigt
                if ~iscell(tensors)
                    count = size(tensors,1);
                    split = cell(1,count);
                    for index = 1:count
                        split{index} = squeeze(tensors(index,:,:,:));
                    end
                    tensors = split;
                end
                obj = ...
                    kssolv.analysis.matgenlab.core.TensorCollection. ...
                    from_voigt(tensors);
            else
                obj = ...
                    kssolv.analysis.matgenlab.core.TensorCollection(tensors);
            end
        end
    end

    methods (Access = private)
        function result = map(obj, operation)
            values = cellfun(operation, obj.tensors, UniformOutput=false);
            result = kssolv.analysis.matgenlab.core.TensorCollection( ...
                values, obj.base_class);
        end
    end
end
