classdef AbinitHeader
    properties
        summary string = ""
        data struct = struct()
    end
    methods
        function obj = AbinitHeader(summary, varargin)
            if nargin < 1, return; end
            if isstruct(summary) && nargin == 1
                obj.data = summary;
                obj.summary = "";
            else
                obj.summary = string(summary);
            end
            if nargin == 2 && isstruct(varargin{1})
                obj.data = varargin{1};
            elseif ~isempty(varargin)
                obj.data = struct(varargin{:});
            end
        end
        function value = get(obj, name, default)
            if nargin < 3, default = []; end
            name = char(string(name));
            if isfield(obj.data, name), value = obj.data.(name);
            else, value = default;
            end
        end
        function value = subsref(obj, s)
            if strcmp(s(1).type, "()") && numel(s(1).subs) == 1 %#ok<ISCL>
                value = obj.get(s(1).subs{1});
                if numel(s) > 1, value = builtin("subsref", value, s(2:end)); end
            elseif strcmp(s(1).type, ".") && isfield(obj.data, s(1).subs)
                value = obj.data.(s(1).subs);
                if numel(s) > 1, value = builtin("subsref", value, s(2:end)); end
            else
                value = builtin("subsref", obj, s);
            end
        end
        function value = to_str(obj, varargin)
            names = fieldnames(obj.data); lines = strings(0,1);
            title = "";
            for i=1:2:numel(varargin),if string(varargin{i})=="title",title=string(varargin{i+1});end,end
            if strlength(title)>0,lines(end+1)="======== "+title+" ========";end
            for i=1:numel(names),lines(end+1)=string(names{i})+": "+string(mat2str(obj.data.(names{i})));end %#ok<AGROW>
            value=char(join(lines,newline));
        end
        function value = to_string(obj,varargin),value=obj.to_str(varargin{:});end
        function value = char(obj),value=obj.to_str();end
        function value = string(obj),value=string(obj.to_str());end
    end
end
