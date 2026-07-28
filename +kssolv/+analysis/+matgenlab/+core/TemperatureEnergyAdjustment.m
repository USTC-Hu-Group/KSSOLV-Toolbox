classdef TemperatureEnergyAdjustment < kssolv.analysis.matgenlab.core.EnergyAdjustment
    properties
        adj_per_deg (1,1) double = 0
        temp (1,1) double = 0
        n_atoms (1,1) double = 0
        uncertainty_per_deg (1,1) double = NaN
    end
    methods
        function obj = TemperatureEnergyAdjustment(adj_per_deg,temp,n_atoms,varargin)
            options=struct(uncertainty_per_deg=NaN,name="",cls=struct(), ...
                description="Temperature-based energy adjustment");
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
                0,NaN,options.name,options.cls,options.description);
            obj.adj_per_deg=double(adj_per_deg); obj.temp=double(temp);
            obj.n_atoms=double(n_atoms);
            obj.uncertainty_per_deg=double(options.uncertainty_per_deg);
        end
        function normalize(obj,factor),obj.n_atoms=obj.n_atoms/factor;end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.core.entries", ...
                x_class="TemperatureEnergyAdjustment",x_version=NaN, ...
                adj_per_deg=obj.adj_per_deg,temp=obj.temp,n_atoms=obj.n_atoms, ...
                uncertainty_per_deg=obj.uncertainty_per_deg, ...
                name=obj.name,cls=obj.cls,description=obj.description);
        end
    end
    methods (Static)
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.core.TemperatureEnergyAdjustment( ...
                data.adj_per_deg,data.temp,data.n_atoms, ...
                "uncertainty_per_deg",fieldOr(data,"uncertainty_per_deg",NaN), ...
                "name",fieldOr(data,"name",""),"cls",fieldOr(data,"cls",struct()), ...
                "description",fieldOr(data,"description","Temperature-based energy adjustment"));
            function value=fieldOr(input,name,default)
                if isfield(input,name)&&~isempty(input.(name)),value=input.(name);
                else,value=default;end
            end
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.TemperatureEnergyAdjustment.from_dict(data);
        end
    end
end
