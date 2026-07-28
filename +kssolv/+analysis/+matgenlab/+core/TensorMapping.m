classdef TensorMapping < handle
    %TENSORMAPPING Approximate-equality mapping keyed by tensors.

    properties
        tol (1,1) double {mustBePositive} = 1e-5
    end

    properties (SetAccess = private)
        tensor_list cell
        value_list cell
    end

    methods
        function obj = TensorMapping(tensors, values, tol)
            arguments
                tensors = {}
                values = {}
                tol (1,1) double {mustBePositive} = 1e-5
            end
            if ~iscell(tensors)
                tensors = num2cell(tensors);
            end
            if ~iscell(values)
                values = num2cell(values);
            end
            if numel(tensors) ~= numel(values)
                error("KSSOLV:Matgenlab:TensorMapping:LengthMismatch", ...
                    "TensorMapping must be initialized with tensors and values of equivalent length");
            end
            obj.tensor_list = reshape(tensors,1,[]);
            obj.value_list = reshape(values,1,[]);
            obj.tol = tol;
        end

        function n = length(obj)
            n = numel(obj.tensor_list);
        end

        function varargout = subsref(obj, subscript)
            if subscript(1).type == "()"
                key = subscript(1).subs{1};
                index = obj.itemIndex(key);
                if isempty(index)
                    error("KSSOLV:Matgenlab:TensorMapping:KeyNotFound", ...
                        "Tensor key was not found in mapping.");
                end
                result = obj.value_list{index};
                if numel(subscript) > 1
                    result = builtin("subsref", result, subscript(2:end));
                end
                varargout{1} = result;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, subscript);
            end
        end

        function obj = subsasgn(obj, subscript, value)
            if subscript(1).type == "()"
                key = subscript(1).subs{1};
                index = obj.itemIndex(key);
                if isempty(index)
                    obj.tensor_list{end+1} = key;
                    obj.value_list{end+1} = value;
                else
                    obj.value_list{index} = value;
                end
            else
                obj = builtin("subsasgn", obj, subscript, value);
            end
        end

        function remove(obj, key)
            index = obj.itemIndex(key);
            if isempty(index)
                error("KSSOLV:Matgenlab:TensorMapping:KeyNotFound", ...
                    "Tensor key was not found in mapping.");
            end
            obj.tensor_list(index) = [];
            obj.value_list(index) = [];
        end

        function tf = contains(obj, key)
            tf = ~isempty(obj.itemIndex(key));
        end

        function values = values(obj)
            values = obj.value_list;
        end

        function [keys, values] = items(obj)
            keys = obj.tensor_list;
            values = obj.value_list;
        end

        function keys = keys(obj)
            keys = obj.tensor_list;
        end
    end

    methods (Access = private)
        function index = itemIndex(obj, item)
            index = [];
            if isempty(obj.tensor_list)
                return
            end
            if isa(item,"kssolv.analysis.matgenlab.core.Tensor")
                item = double(item);
            end
            matches = false(1,numel(obj.tensor_list));
            for candidate = 1:numel(obj.tensor_list)
                key = obj.tensor_list{candidate};
                if isa(key,"kssolv.analysis.matgenlab.core.Tensor")
                    key = double(key);
                end
                matches(candidate) = isequal(size(key),size(item)) && ...
                    all(abs(key-item) < obj.tol,"all");
            end
            found = find(matches);
            if numel(found) > 1
                error("KSSOLV:Matgenlab:TensorMapping:KeyCollision", ...
                    "Tensor key collision.");
            end
            if ~isempty(found)
                index = found;
            end
        end
    end
end
