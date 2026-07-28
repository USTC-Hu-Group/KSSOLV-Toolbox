classdef EnergyAdjustment < handle
    %ENERGYADJUSTMENT Metadata-bearing correction to a computed energy.

    properties
        name (1,1) string = "Manual adjustment"
        cls = struct()
        description (1,1) string = ""
    end
    properties (Access = protected)
        value_ (1,1) double = 0
        uncertainty_ (1,1) double = NaN
    end
    properties (Dependent, SetAccess = private)
        value
        uncertainty
        explain
    end

    methods
        function obj = EnergyAdjustment(value, varargin)
            if nargin == 0, return; end
            options=struct(uncertainty=NaN,name="Manual adjustment", ...
                cls=struct(),description="");
            options=parseOptions(options,varargin);
            obj.value_ = double(value);
            obj.uncertainty_ = double(options.uncertainty);
            obj.name = string(options.name);
            obj.cls = options.cls;
            obj.description = string(options.description);
            function output=parseOptions(output,input)
                names=fieldnames(output);pos=1;ii=1;
                while ii<=numel(input)
                    if (ischar(input{ii})||isstring(input{ii}))&& ...
                            any(strcmpi(string(input{ii}),string(names)))
                        key=names{strcmpi(string(input{ii}),string(names))};
                        output.(key)=input{ii+1};ii=ii+2;
                    else
                        output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;
                    end
                end
            end
        end
        function value = get.value(obj)
            if isa(obj,"kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment")
                adjustmentName="adj_per_atom";
                atomsName="n_atoms";
                value=obj.(adjustmentName)*obj.(atomsName);
            elseif isa(obj,"kssolv.analysis.matgenlab.core.TemperatureEnergyAdjustment")
                adjustmentName="adj_per_deg";
                temperatureName="temp";
                atomsName="n_atoms";
                value=obj.(adjustmentName)*obj.(temperatureName)* ...
                    obj.(atomsName);
            else
                value=obj.value_;
            end
        end
        function value = get.uncertainty(obj)
            if isa(obj,"kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment")
                uncertaintyName="uncertainty_per_atom";
                atomsName="n_atoms";
                value=obj.(uncertaintyName)*obj.(atomsName);
            elseif isa(obj,"kssolv.analysis.matgenlab.core.TemperatureEnergyAdjustment")
                uncertaintyName="uncertainty_per_deg";
                temperatureName="temp";
                atomsName="n_atoms";
                value=obj.(uncertaintyName)*obj.(temperatureName)* ...
                    obj.(atomsName);
            else
                value=obj.uncertainty_;
            end
        end
        function value = get.explain(obj)
            if isa(obj,"kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment")
                adjustmentName="adj_per_atom";
                atomsName="n_atoms";
                value=sprintf("%s (%.3f eV/atom x %g atoms)", ...
                    obj.description,obj.(adjustmentName),obj.(atomsName));
            elseif isa(obj,"kssolv.analysis.matgenlab.core.TemperatureEnergyAdjustment")
                adjustmentName="adj_per_deg";
                temperatureName="temp";
                atomsName="n_atoms";
                value=sprintf("%s (%.4f eV/K/atom x %g K x %g atoms)", ...
                    obj.description,obj.(adjustmentName), ...
                    obj.(temperatureName),obj.(atomsName));
            else
                value = sprintf("%s (%.3f eV)", obj.description, obj.value);
            end
        end
        function normalize(obj, factor)
            obj.value_ = obj.value_ / factor;
            obj.uncertainty_ = obj.uncertainty_ / factor;
        end
        function data = as_dict(obj)
            parts = split(string(class(obj)), ".");
            data = struct( ...
                x_module="pymatgen.core.entries", ...
                x_class=parts(end), ...
                x_version=NaN, ...
                value=obj.value_, uncertainty=obj.uncertainty_, ...
                name=obj.name, cls=obj.cls, description=obj.description);
        end
        function data = asDict(obj), data = obj.as_dict(); end
    end

    methods (Static)
        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.EnergyAdjustment( ...
                data.value,"uncertainty",fieldOr(data,"uncertainty",NaN), ...
                "name",fieldOr(data,"name","Manual adjustment"), ...
                "cls",fieldOr(data,"cls",struct()), ...
                "description",fieldOr(data,"description",""));
            function value = fieldOr(input, name, default)
                if isfield(input,name) && ~isempty(input.(name))
                    value = input.(name);
                else
                    value = default;
                end
            end
        end
        function obj = fromDict(data)
            obj = kssolv.analysis.matgenlab.core.EnergyAdjustment.from_dict(data);
        end
    end
end
