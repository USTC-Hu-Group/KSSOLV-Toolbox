classdef ConstantEnergyAdjustment < kssolv.analysis.matgenlab.core.EnergyAdjustment
    methods
        function obj = ConstantEnergyAdjustment(value, varargin)
            options=struct(uncertainty=NaN,name="Constant energy adjustment", ...
                cls=struct(),description="Constant energy adjustment");
            names=fieldnames(options);pos=1;ii=1;
            while ii<=numel(varargin)
                if (ischar(varargin{ii})||isstring(varargin{ii}))&& ...
                        any(strcmpi(string(varargin{ii}),string(names)))
                    key=names{strcmpi(string(varargin{ii}),string(names))};
                    options.(key)=varargin{ii+1};ii=ii+2;
                else
                    options.(names{pos})=varargin{ii};pos=pos+1;ii=ii+1;
                end
            end
            obj@kssolv.analysis.matgenlab.core.EnergyAdjustment( ...
                value,options.uncertainty,options.name,options.cls,options.description);
        end
    end
    methods (Static)
        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment( ...
                data.value,"uncertainty",fieldOr(data,"uncertainty",NaN), ...
                "name",fieldOr(data,"name","Constant energy adjustment"), ...
                "cls",fieldOr(data,"cls",struct()), ...
                "description",fieldOr(data,"description","Constant energy adjustment"));
            function value = fieldOr(input,name,default)
                if isfield(input,name) && ~isempty(input.(name)), value=input.(name);
                else, value=default; end
            end
        end
        function obj = fromDict(data)
            obj = kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment.from_dict(data);
        end
    end
end
