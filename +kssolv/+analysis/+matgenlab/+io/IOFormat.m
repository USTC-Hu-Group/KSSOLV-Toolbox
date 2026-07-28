classdef IOFormat
    %IOFORMAT Common descriptor for structure and molecule format plugins.
    properties
        name (1,1) string
        patterns cell = cell(1,0)
        read_str = []
        read_file = []
        write_str = []
        write_file = []
        binary (1,1) logical = false
        case_insensitive (1,1) logical = true
        extra (1,1) struct = struct()
    end
    methods
        function obj=IOFormat(name,varargin)
            if nargin<1,name="";end
            obj.name=lower(string(name));
            options=struct("patterns",{{}},"read_str",[], ...
                "read_file",[],"write_str",[],"write_file",[], ...
                "binary",false,"case_insensitive",true,"extra",struct());
            if isscalar(varargin)&&isstruct(varargin{1})
                supplied=varargin{1};names=fieldnames(supplied);
                for index=1:numel(names)
                    if isfield(options,names{index})
                        options.(names{index})=supplied.(names{index});
                    end
                end
            else
                names=fieldnames(options);
                for index=1:2:numel(varargin)
                    if index==numel(varargin),break,end
                    match=find(strcmpi(string(varargin{index}), ...
                        string(names)),1);
                    if ~isempty(match)
                        options.(names{match})=varargin{index+1};
                    end
                end
            end
            if ischar(options.patterns)||isstring(options.patterns)
                obj.patterns=cellstr(options.patterns);
            else
                obj.patterns=reshape(options.patterns,1,[]);
            end
            obj.read_str=options.read_str;
            obj.read_file=options.read_file;
            obj.write_str=options.write_str;
            obj.write_file=options.write_file;
            obj.binary=logical(options.binary);
            obj.case_insensitive=logical(options.case_insensitive);
            obj.extra=options.extra;
        end
        function equal=eq(obj,other)
            equal=isa(other,class(obj))&&obj.name==other.name&& ...
                isequal(obj.patterns,other.patterns)&& ...
                isequal(obj.read_str,other.read_str)&& ...
                isequal(obj.read_file,other.read_file)&& ...
                isequal(obj.write_str,other.write_str)&& ...
                isequal(obj.write_file,other.write_file)&& ...
                obj.binary==other.binary&& ...
                obj.case_insensitive==other.case_insensitive&& ...
                isequaln(obj.extra,other.extra);
        end
        function equal=ne(obj,other),equal=~(obj==other);end
    end
end
