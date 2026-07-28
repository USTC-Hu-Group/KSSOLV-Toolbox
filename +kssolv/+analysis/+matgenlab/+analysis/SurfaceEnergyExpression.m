classdef SurfaceEnergyExpression
    %SURFACEENERGYEXPRESSION Affine chemical-potential expression.
    properties
        constant (1,1) double = 0
        coefficients (1,1) struct = struct()
    end
    properties (Dependent,SetAccess=private)
        free_symbols
    end
    methods
        function obj=SurfaceEnergyExpression(constant,coefficients)
            if nargin>0,obj.constant=double(constant);end
            if nargin>1&&~isempty(coefficients),obj.coefficients=coefficients;end
        end
        function names=get.free_symbols(obj)
            names=string(fieldnames(obj.coefficients)).';
        end
        function value=evaluate(obj,values,default)
            if nargin<3,default=0;end
            value=obj.constant;
            names=fieldnames(obj.coefficients);
            for index=1:numel(names)
                value=value+obj.coefficients.(names{index})* ...
                    lookupValue(values,names{index},default);
            end
        end
        function result=subs(obj,values)
            result=obj;names=fieldnames(obj.coefficients);
            for index=1:numel(names)
                [found,value]=lookupValue(values,names{index},0);
                if found
                    result.constant=result.constant+ ...
                        result.coefficients.(names{index})*value;
                    result.coefficients=rmfield(result.coefficients,names{index});
                end
            end
            if isempty(fieldnames(result.coefficients)),result=result.constant;end
        end
        function data=as_coefficients_dict(obj)
            data=obj.coefficients;data.constant=obj.constant;
        end
        function text=char(obj)
            text=sprintf("%.15g",obj.constant);
            names=fieldnames(obj.coefficients);
            for index=1:numel(names)
                text=sprintf("%s%+.15g*%s",text, ...
                    obj.coefficients.(names{index}),names{index});
            end
        end
    end
end
function varargout=lookupValue(values,name,default)
found=false;value=default;
if isempty(values)
elseif isa(values,"containers.Map")
    keysToTry={name,char(string(name))};
    for index=1:numel(keysToTry)
        if isKey(values,keysToTry{index})
            value=values(keysToTry{index});found=true;break
        end
    end
elseif isstruct(values)&&isfield(values,name)
    value=values.(name);found=true;
elseif istable(values)&&any(string(values.Properties.VariableNames)==string(name))
    value=values.(name)(1);found=true;
end
if nargout==1,varargout={value};else,varargout={found,value};end
end
