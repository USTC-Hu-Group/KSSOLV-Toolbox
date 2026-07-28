classdef AbstractInput < handle
    properties (Access = protected)
        vars_ struct = struct()
    end
    properties (Dependent)
        vars
    end
    methods
        function value = get.vars(obj), value = obj.vars_; end
        function value = length(obj), value = numel(fieldnames(obj.vars_)); end
        function value = isempty(obj), value = isempty(fieldnames(obj.vars_)); end
        function value = get(obj, key, default)
            if nargin < 3, default = []; end
            key = char(string(key));
            if isfield(obj.vars_, key), value = obj.vars_.(key); else, value = default; end
        end
        function value = pop(obj, key, default)
            if nargin < 3, default = []; end
            key = char(string(key)); value = obj.get(key, default);
            if isfield(obj.vars_, key), obj.vars_ = rmfield(obj.vars_, key); end
        end
        function value = set_vars(obj, varargin)
            values = kssolv.analysis.matgenlab.io.abinit.AbstractInput.argsToStruct(varargin{:});
            names = fieldnames(values); value = struct();
            for i = 1:numel(names)
                obj.setOne(names{i}, values.(names{i})); value.(names{i}) = values.(names{i});
            end
        end
        function value = set_vars_ifnotin(obj, varargin)
            values = kssolv.analysis.matgenlab.io.abinit.AbstractInput.argsToStruct(varargin{:});
            names = fieldnames(values); value = struct();
            for i = 1:numel(names)
                if ~isfield(obj.vars_, names{i})
                    obj.setOne(names{i}, values.(names{i})); value.(names{i}) = values.(names{i});
                end
            end
        end
        function value = pop_vars(obj, keys), value = obj.remove_vars(keys, false); end
        function value = remove_vars(obj, keys, strict)
            if nargin < 3, strict = true; end
            keys = string(keys); value = struct();
            for key = reshape(keys, 1, [])
                name = char(key);
                if ~isfield(obj.vars_, name)
                    if strict, error("KSSOLV:Matgenlab:Abinit:MissingVariable", "key='%s' not in self.", name); end
                else
                    value.(name) = obj.vars_.(name); obj.vars_ = rmfield(obj.vars_, name);
                end
            end
        end
        function write(obj, filepath)
            if nargin < 2, filepath = "run.abi"; end
            folder = fileparts(filepath); if strlength(string(folder)) > 0 && ~isfolder(folder), mkdir(folder); end
            fid = fopen(filepath, "w"); cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, "%s", obj.to_str());
        end
        function value = char(obj), value = obj.to_str(); end
        function value = string(obj), value = string(obj.to_str()); end
        function value = deepcopy(obj), value = obj.copyImpl(); end
        function value = subsref(obj, s)
            if strcmp(s(1).type, "()") && numel(s(1).subs) == 1 && (ischar(s(1).subs{1}) || isstring(s(1).subs{1})) %#ok<ISCL>
                value = obj.get(s(1).subs{1});
                if numel(s) > 1, value = builtin("subsref", value, s(2:end)); end
            else, value = builtin("subsref", obj, s);
            end
        end
        function obj = subsasgn(obj, s, value)
            if strcmp(s(1).type, "()") && numel(s(1).subs) == 1 %#ok<ISCL>
                obj.setOne(s(1).subs{1}, value);
            else, obj = builtin("subsasgn", obj, s, value);
            end
        end
    end
    methods (Access = protected)
        function setOne(obj, key, value), obj.vars_.(char(string(key))) = value; end
        function value = copyImpl(obj), value = obj; end
    end
    methods (Static, Access = protected)
        function value = argsToStruct(varargin)
            if isempty(varargin), value = struct(); return; end
            if numel(varargin) == 1 && isstruct(varargin{1}), value = varargin{1}; return; end %#ok<ISCL>
            value = struct();
            for i = 1:2:numel(varargin), value.(char(string(varargin{i}))) = varargin{i + 1}; end
        end
    end
    methods (Abstract)
        value = to_str(obj, varargin)
    end
end
