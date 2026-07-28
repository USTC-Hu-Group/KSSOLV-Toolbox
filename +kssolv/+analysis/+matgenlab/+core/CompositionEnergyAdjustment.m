classdef CompositionEnergyAdjustment < kssolv.analysis.matgenlab.core.EnergyAdjustment
    properties
        adj_per_atom (1,1) double = 0
        uncertainty_per_atom (1,1) double = NaN
        n_atoms (1,1) double = 0
    end
    methods
        function obj = CompositionEnergyAdjustment(adj_per_atom, n_atoms, varargin)
            options=struct(uncertainty_per_atom=NaN,name="",cls=struct(), ...
                description="Composition-based energy adjustment");
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
            obj.adj_per_atom = double(adj_per_atom);
            obj.uncertainty_per_atom = double(options.uncertainty_per_atom);
            obj.n_atoms = double(n_atoms);
        end
        function normalize(obj, factor), obj.n_atoms=obj.n_atoms/factor; end
        function data = as_dict(obj)
            data = struct(x_module="pymatgen.core.entries", ...
                x_class="CompositionEnergyAdjustment",x_version=NaN, ...
                adj_per_atom=obj.adj_per_atom, n_atoms=obj.n_atoms, ...
                uncertainty_per_atom=obj.uncertainty_per_atom, ...
                name=obj.name, cls=obj.cls, description=obj.description);
        end
    end
    methods (Static)
        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment( ...
                data.adj_per_atom,data.n_atoms, ...
                "uncertainty_per_atom",fieldOr(data,"uncertainty_per_atom",NaN), ...
                "name",fieldOr(data,"name",""),"cls",fieldOr(data,"cls",struct()), ...
                "description",fieldOr(data,"description","Composition-based energy adjustment"));
            function value=fieldOr(input,name,default)
                if isfield(input,name)&&~isempty(input.(name)),value=input.(name);
                else,value=default;end
            end
        end
        function obj = fromDict(data)
            obj=kssolv.analysis.matgenlab.core.CompositionEnergyAdjustment.from_dict(data);
        end
    end
end
