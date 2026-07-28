classdef (Abstract) EnergyModel < kssolv.analysis.matgenlab.util.MSONable
    %ENERGYMODEL Interface for assigning a scalar energy to a structure.
    methods (Abstract)
        value=get_energy(obj,structure)
    end
    methods (Static)
        function obj=from_dict(data)
            cls=string(data.x_class);
            switch cls
                case "EwaldElectrostaticModel"
                    obj=kssolv.analysis.matgenlab.core.EwaldElectrostaticModel.from_dict(data);
                case "SymmetryModel"
                    obj=kssolv.analysis.matgenlab.core.SymmetryModel.from_dict(data);
                case "IsingModel"
                    obj=kssolv.analysis.matgenlab.core.IsingModel.from_dict(data);
                case "NsitesModel"
                    obj=kssolv.analysis.matgenlab.core.NsitesModel.from_dict(data);
                otherwise
                    error("KSSOLV:Matgenlab:EnergyModel:UnknownType", ...
                        "Unknown energy model '%s'.",cls);
            end
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.EnergyModel.from_dict(data);
        end
    end
end
