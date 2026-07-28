classdef IsingModel < kssolv.analysis.matgenlab.core.EnergyModel
    properties
        j (1,1) double
        max_radius (1,1) double
    end
    methods
        function obj=IsingModel(j,max_radius),obj.j=j;obj.max_radius=max_radius;end
        function value=get_energy(obj,structure)
            neighbors=structure.get_all_neighbors(obj.max_radius);value=0;
            for ii=1:structure.num_sites
                spin1=structure(ii).specie.spin;if isnan(spin1),spin1=0;end
                for jj=1:numel(neighbors{ii})
                    spin2=neighbors{ii}{jj}.specie.spin;if isnan(spin2),spin2=0;end
                    value=value+obj.j*spin1*spin2/neighbors{ii}{jj}.nn_distance^2;
                end
            end
        end
        function data=as_dict(obj)
            data=struct(version="0.1",x_module="pymatgen.core.energy_models", ...
                x_class="IsingModel", ...
                init_args=struct(j=obj.j,max_radius=obj.max_radius));
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            obj=kssolv.analysis.matgenlab.core.IsingModel( ...
                data.init_args.j,data.init_args.max_radius);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.IsingModel.from_dict(data);
        end
    end
end
