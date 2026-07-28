classdef EwaldElectrostaticModel < kssolv.analysis.matgenlab.core.EnergyModel
    properties
        real_space_cut=[]
        recip_space_cut=[]
        eta=[]
        acc_factor (1,1) double=8
    end
    methods
        function obj=EwaldElectrostaticModel(real_space_cut,recip_space_cut,eta,acc_factor)
            if nargin>=1,obj.real_space_cut=real_space_cut;end
            if nargin>=2,obj.recip_space_cut=recip_space_cut;end
            if nargin>=3,obj.eta=eta;end
            if nargin>=4,obj.acc_factor=acc_factor;end
        end
        function value=get_energy(obj,structure)
            summation=kssolv.analysis.matgenlab.core.EwaldSummation( ...
                structure,obj.real_space_cut,obj.recip_space_cut,obj.eta, ...
                obj.acc_factor);
            value=summation.total_energy;
        end
        function data=as_dict(obj)
            args=struct(real_space_cut=obj.real_space_cut, ...
                recip_space_cut=obj.recip_space_cut,eta=obj.eta, ...
                acc_factor=obj.acc_factor);
            data=struct(version="0.1",x_module="pymatgen.core.energy_models", ...
                x_class="EwaldElectrostaticModel",init_args=args);
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            a=data.init_args;
            obj=kssolv.analysis.matgenlab.core.EwaldElectrostaticModel( ...
                a.real_space_cut,a.recip_space_cut,a.eta,a.acc_factor);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.EwaldElectrostaticModel.from_dict(data);
        end
    end
end
