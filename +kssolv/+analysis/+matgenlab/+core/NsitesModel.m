classdef NsitesModel < kssolv.analysis.matgenlab.core.EnergyModel
    methods
        function value=get_energy(~,structure),value=structure.num_sites;end
        function data=as_dict(~)
            data=struct(version="0.1",x_module="pymatgen.core.energy_models", ...
                x_class="NsitesModel",init_args=struct());
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(~),obj=kssolv.analysis.matgenlab.core.NsitesModel();end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.NsitesModel.from_dict(data);
        end
    end
end
