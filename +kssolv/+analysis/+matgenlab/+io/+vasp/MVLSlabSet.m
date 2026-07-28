classdef MVLSlabSet < kssolv.analysis.matgenlab.io.vasp.VaspInputSet
    %MVLSLABSET Surface slab relaxation inputs.
    methods
        function obj = MVLSlabSet(structure, varargin)
            if nargin < 1, structure = []; end
            obj@kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, "MPRelaxSet", varargin{:});
            obj.set_name = "MVLSlabSet";
            obj.extra_incar_updates = struct("EDIFF",1e-5, ...
                "EDIFFG",-0.05,"ENAUG",4000,"IBRION",1,"POTIM",1, ...
                "LDAU",false,"ENCUT",400,"ISMEAR",0,"SIGMA",0.05, ...
                "ISIF",2,"ISYM",0,"LVTOT",true,"NELMIN",8, ...
                "AMIN",0.01,"AMIX",0.2,"BMIX",0.001);
            obj.extra_kpoints_updates = struct( ...
                "reciprocal_density",obj.k_product);
        end

        function output = as_dict(obj, verbosity)
            if nargin < 2, verbosity = 2; end
            output = as_dict@kssolv.analysis.matgenlab.io.vasp. ...
                VaspInputSet(obj, verbosity);
            output.k_product = obj.k_product;
            output.bulk = obj.bulk;
            output.auto_dipole = obj.auto_dipole;
            output.set_mix = obj.set_mix;
        end
    end
end
