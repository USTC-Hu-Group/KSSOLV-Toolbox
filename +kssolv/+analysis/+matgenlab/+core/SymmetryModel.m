classdef SymmetryModel < kssolv.analysis.matgenlab.core.EnergyModel
    properties
        symprec (1,1) double=.1
        angle_tolerance (1,1) double=5
    end
    methods
        function obj=SymmetryModel(symprec,angle_tolerance)
            if nargin>=1,obj.symprec=symprec;end
            if nargin>=2,obj.angle_tolerance=angle_tolerance;end
        end
        function value=get_energy(obj,structure)
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(structure,obj.symprec,obj.angle_tolerance);
            value=-analyzer.get_space_group_number();
        end
        function data=as_dict(obj)
            data=struct(version="0.1",x_module="pymatgen.core.energy_models", ...
                x_class="SymmetryModel",init_args=struct( ...
                symprec=obj.symprec,angle_tolerance=obj.angle_tolerance));
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            a=data.init_args;
            obj=kssolv.analysis.matgenlab.core.SymmetryModel( ...
                a.symprec,a.angle_tolerance);
        end
        function obj=fromDict(data)
            obj=kssolv.analysis.matgenlab.core.SymmetryModel.from_dict(data);
        end
    end
end
