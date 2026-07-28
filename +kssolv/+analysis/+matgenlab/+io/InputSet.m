classdef InputSet < kssolv.analysis.matgenlab.util.MSONable
    %INPUTSET Dict-like collection of named calculation input files.
    properties
        inputs
        kwargs (1,1) struct = struct()
    end
    properties (Access=private)
        input_order cell = cell(1,0)
    end
    methods
        function obj=InputSet(inputs,varargin)
            if nargin<1||isempty(inputs)
                inputs=containers.Map("KeyType","char","ValueType","any");
            end
            [obj.inputs,obj.input_order]=normalizeInputs(inputs);
            if isscalar(varargin)&&isstruct(varargin{1})
                obj.kwargs=varargin{1};
            else
                for index=1:2:numel(varargin)
                    if index==numel(varargin),break,end
                    name=matlab.lang.makeValidName( ...
                        char(string(varargin{index})));
                    obj.kwargs.(name)=varargin{index+1};
                end
            end
        end
        function count=length(obj),count=numel(obj.input_order);end
        function count=numel(obj,varargin)
            if nargin>1,count=builtin("numel",obj,varargin{:});
            else,count=1;end
        end
        function names=keys(obj),names=obj.input_order;end
        function pairs=items(obj)
            pairs=cell(numel(obj.input_order),2);
            for index=1:numel(obj.input_order)
                pairs{index,1}=obj.input_order{index};
                pairs{index,2}=obj.inputs(obj.input_order{index});
            end
        end
        function value=get(obj,name)
            name=char(string(name));
            if ~isKey(obj.inputs,name)
                error("KSSOLV:Matgenlab:InputSet:Key", ...
                    "Unknown input key '%s'.",name);
            end
            value=obj.inputs(name);
        end
        function obj=set(obj,name,value)
            name=char(string(name));
            if ~isKey(obj.inputs,name),obj.input_order{end+1}=name;end
            obj.inputs(name)=value;
        end
        function obj=remove(obj,name)
            name=char(string(name));
            if isKey(obj.inputs,name)
                remove(obj.inputs,name);
                obj.input_order(strcmp(obj.input_order,name))=[];
            end
        end
        function write_input(obj,directory,varargin)
            options=struct("make_dir",true,"overwrite",true, ...
                "zip_inputs",false);
            options=parseOptions(options,varargin{:});
            directory=char(string(directory));
            if ~isfolder(directory)
                if options.make_dir
                    [success,message]=mkdir(directory);
                    if ~success
                        error("KSSOLV:Matgenlab:InputSet:Directory", ...
                            "Unable to create '%s': %s",directory,message);
                    end
                else
                    error("KSSOLV:Matgenlab:InputSet:MissingDirectory", ...
                        "Input directory '%s' does not exist.",directory);
                end
            end
            written=cell(1,numel(obj.input_order));
            for index=1:numel(obj.input_order)
                name=obj.input_order{index};
                target=safeTarget(directory,name);
                if isfile(target)&&~options.overwrite
                    error("KSSOLV:Matgenlab:InputSet:Exists", ...
                        "Input file '%s' already exists.",name);
                end
                contents=obj.inputs(name);
                if isa(contents,"kssolv.analysis.matgenlab.io.InputFile")
                    contents.write_file(target);
                else
                    writeText(target,contents);
                end
                written{index}=target;
            end
            if options.zip_inputs
                [~,className]=fileparts(strrep(class(obj),".",filesep));
                archive=fullfile(directory,className+".zip");
                if isfile(archive)&&~options.overwrite
                    error("KSSOLV:Matgenlab:InputSet:Exists", ...
                        "Archive '%s' already exists.",archive);
                end
                zip(archive,obj.input_order,directory);
                for index=1:numel(written)
                    if isfile(written{index}),delete(written{index});end
                end
            end
        end
        function writeInput(obj,directory,varargin)
            obj.write_input(directory,varargin{:});
        end
        function valid=validate(~)
            valid=false; %#ok<NASGU>
            error("KSSOLV:Matgenlab:InputSet:AbstractValidate", ...
                "validate has not been implemented in InputSet.");
        end
        function data=asDict(obj)
            names=obj.input_order;values=cell(size(names));
            for index=1:numel(names),values{index}=obj.inputs(names{index});end
            inputMap=containers.Map(names,values,"UniformValues",false);
            data=kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.io.core","InputSet",struct( ...
                "inputs",inputMap,"kwargs",obj.kwargs, ...
                "input_order",{obj.input_order}));
        end
        function data=as_dict(obj),data=obj.asDict();end
        function varargout=subsref(obj,reference)
            if strcmp(reference(1).type,"()")&& ...
                    isscalar(reference(1).subs)
                value=obj.get(reference(1).subs{1});
                if numel(reference)>1,value=builtin("subsref",value, ...
                        reference(2:end));end
                varargout={value};return
            end
            if strcmp(reference(1).type,".")&& ...
                    isfield(obj.kwargs,reference(1).subs)
                value=obj.kwargs.(reference(1).subs);
                if numel(reference)>1,value=builtin("subsref",value, ...
                        reference(2:end));end
                varargout={value};return
            end
            [varargout{1:nargout}]=builtin("subsref",obj,reference);
        end
        function obj=subsasgn(obj,reference,value)
            if strcmp(reference(1).type,"()")&& ...
                    isscalar(reference(1).subs)
                if isscalar(reference)
                    obj=obj.set(reference(1).subs{1},value);
                else
                    current=obj.get(reference(1).subs{1});
                    current=builtin("subsasgn",current,reference(2:end),value);
                    obj=obj.set(reference(1).subs{1},current);
                end
                return
            end
            obj=builtin("subsasgn",obj,reference,value);
        end
    end
    methods (Static)
        function obj=from_directory(directory)
            obj=kssolv.analysis.matgenlab.io.InputSet(); %#ok<NASGU>
            error("KSSOLV:Matgenlab:InputSet:AbstractFromDirectory", ...
                "from_directory has not been implemented for '%s'.", ...
                string(directory));
        end
        function obj=fromDirectory(directory)
            obj=kssolv.analysis.matgenlab.io.InputSet. ...
                from_directory(directory);
        end
        function obj=fromDict(data)
            kwargs=struct();
            if isfield(data,"kwargs"),kwargs=data.kwargs;end
            obj=kssolv.analysis.matgenlab.io.InputSet(data.inputs,kwargs);
            if isfield(data,"input_order")
                obj.input_order=reshape(cellstr( ...
                    string(data.input_order)),1,[]);
            end
        end
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.io.InputSet.fromDict(data);
        end
    end
end

function [mapping,order]=normalizeInputs(inputs)
mapping=containers.Map("KeyType","char","ValueType","any");
if isa(inputs,"containers.Map")
    order=keys(inputs);
    for index=1:numel(order),mapping(order{index})=inputs(order{index});end
elseif isstruct(inputs)
    order=fieldnames(inputs).';
    for index=1:numel(order),mapping(order{index})=inputs.(order{index});end
elseif iscell(inputs)&&size(inputs,2)==2
    order=cellstr(string(inputs(:,1))).';
    for index=1:numel(order),mapping(order{index})=inputs{index,2};end
else
    error("KSSOLV:Matgenlab:InputSet:Inputs", ...
        "inputs must be a struct, containers.Map or N-by-2 cell array.");
end
end
function options=parseOptions(options,varargin)
names=fieldnames(options);
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end
function target=safeTarget(directory,name)
if startsWith(name,filesep)||contains(name,"..")|| ...
        ~isempty(regexp(name,"^[A-Za-z]:","once"))
    error("KSSOLV:Matgenlab:InputSet:UnsafePath", ...
        "Input names must be relative paths within the target directory.");
end
target=fullfile(directory,name);
end
function writeText(path,value)
if isstring(value)||ischar(value)
    text=char(string(value));
elseif ismethod(value,"char")
    text=char(value);
else
    text=char(string(value));
end
fileId=fopen(path,"wt","n","UTF-8");
if fileId<0
    error("KSSOLV:Matgenlab:InputSet:Open", ...
        "Unable to open '%s' for writing.",path);
end
cleanup=onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",text);
end
