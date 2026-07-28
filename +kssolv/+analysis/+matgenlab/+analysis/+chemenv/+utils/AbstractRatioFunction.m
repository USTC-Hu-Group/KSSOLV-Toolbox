classdef AbstractRatioFunction
    %ABSTRACTRATIOFUNCTION Validated wrapper around a ratio function.
    %#ok<*ALIGN>
    properties (SetAccess=protected)
        function_name (1,1) string
        options struct=struct()
    end
    methods
        function obj=AbstractRatioFunction(functionName,varargin)
            if nargin==0,return,end
            options=[];
            if ~isempty(varargin)
                if (ischar(varargin{1})||isstring(varargin{1}))&& ...
                        strcmpi(string(varargin{1}),"options_dict")
                    options=varargin{2};
                else,options=varargin{1};end
            end
            obj.function_name=string(functionName);
            allowed=obj.allowed_functions();
            if ~isfield(allowed,char(obj.function_name))
                error("KSSOLV:Matgenlab:ChemEnv:RatioFunction", ...
                    "function='%s' is not allowed in RatioFunction of type %s.", ...
                    obj.function_name,class(obj));
            end
            obj=obj.setup_parameters(options);
        end
        function obj=setup_parameters(obj,options)
            allowed=obj.allowed_functions();
            required=string(allowed.(char(obj.function_name)));
            options=asStruct(options);
            names=string(fieldnames(options));
            if ~all(ismember(required,names))
                error("KSSOLV:Matgenlab:ChemEnv:RatioOptions", ...
                    "Required options %s should be provided for function '%s'.", ...
                    strjoin(required,", "),obj.function_name);
            end
            if ~all(ismember(names,required))
                invalid=names(~ismember(names,required));
                error("KSSOLV:Matgenlab:ChemEnv:RatioOptions", ...
                    "Option '%s' is not allowed for function '%s'.", ...
                    invalid(1),obj.function_name);
            end
            obj.options=options;
        end
        function value=evaluate(obj,input)
            value=obj.(char(obj.function_name))(input);
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv.utils.func_utils", ...
                x_class=shortClass(obj),options=obj.options);
            value.("function")=obj.function_name;
        end
    end
    methods (Access=protected)
        function value=allowed_functions(~),value=struct();end
    end
    methods (Static)
        function obj=from_dict(value)
            className=string(value.x_class);
            constructor=str2func("kssolv.analysis.matgenlab.analysis.chemenv."+ ...
                "utils."+className);
            obj=constructor(value.("function"),value.options);
        end
    end
end
function value=asStruct(input)
if isempty(input),value=struct();return,end
if isstruct(input),value=input;return,end
value=struct();
for key=string(keys(input)),value.(char(key))=input(char(key));end
end
function value=shortClass(obj)
parts=split(string(class(obj)),".");value=parts(end);
end
