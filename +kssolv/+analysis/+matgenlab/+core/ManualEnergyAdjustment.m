classdef ManualEnergyAdjustment < kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment
    methods
        function obj = ManualEnergyAdjustment(value)
            obj@kssolv.analysis.matgenlab.core.ConstantEnergyAdjustment( ...
                value, NaN, "Manual energy adjustment", struct(), ...
                "Manual energy adjustment");
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.core.entries", ...
                x_class="ManualEnergyAdjustment",x_version=NaN, ...
                value=obj.value);
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj = from_dict(data)
            obj = kssolv.analysis.matgenlab.core.ManualEnergyAdjustment(data.value);
        end
        function obj = fromDict(data)
            obj = kssolv.analysis.matgenlab.core.ManualEnergyAdjustment.from_dict(data);
        end
    end
end
