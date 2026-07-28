classdef JOutStructures
    %JOUTSTRUCTURES Ordered JDFTx geometry trajectory and final metadata.
    properties
        out_slice_start_flag string = ...
            "-------- Electronic minimization -----------"
        opt_type = []
        geom_converged (1, 1) logical = false
        geom_converged_reason = []
        elec_converged (1, 1) logical = false
        elec_converged_reason = []
        t_s = []
        slices cell = {}
        eopt_type = []
        etype = []
        emin_flag = []
        ecomponents = []
        elecmindata = []
        stress = []
        strain = []
        forces = []
        nstep = []
        e = []
        grad_k = []
        alpha = []
        linmin = []
        nelectrons = []
        abs_magneticmoment = []
        tot_magneticmoment = []
        mu = []
        elec_nstep = []
        elec_e = []
        elec_grad_k = []
        elec_alpha = []
        elec_linmin = []
        charges = []
        magnetic_moments = []
        selective_dynamics = []
        structure = []
        initial_structure = []
    end
    methods
        function obj = JOutStructures(varargin)
            obj = kssolv.analysis.matgenlab.io.jdftx.assign_options( ...
                obj, varargin{:});
            obj = obj.refresh();
        end

        function result = as_dict(obj)
            names = properties(obj);
            result = struct();
            for idx = 1:numel(names)
                name = names{idx};
                if strcmp(name, "slices")
                    result.slices = cellfun(@(x) x.as_dict(), ...
                        obj.slices, "UniformOutput", false);
                elseif isa(obj.(name), ...
                        "kssolv.analysis.matgenlab.io.jdftx.JElSteps")
                    result.(name) = obj.(name).as_dict();
                else
                    result.(name) = obj.(name);
                end
            end
        end

        function result = to_dict(obj)
            result = obj.as_dict();
        end

        function value = get(obj, key)
            if isnumeric(key)
                value = obj.slices{key + 1};
            else
                value = obj.(char(key));
            end
        end

        function text = string(obj)
            text = string(jsonencode(obj.as_dict()));
        end

        function text = char(obj)
            text = char(string(obj));
        end
    end

    methods (Static)
        function obj = from_out_slice(out_slice, options)
            arguments
                out_slice
                options.opt_type = "IonicMinimize" %#ok<INUSA>
                options.init_struc = []
            end
            data = kssolv.analysis.matgenlab.io.jdftx. ...
                parse_output_slice(out_slice);
            obj = data.jstrucs;
        end

    end

    methods (Access = private)
        function obj = refresh(obj)
            if isempty(obj.slices)
                return
            end
            first = obj.slices{1};
            last = obj.slices{end};
            obj.initial_structure = first.structure;
            names = ["opt_type", "eopt_type", "etype", "emin_flag", ...
                "ecomponents", "elecmindata", "stress", "strain", ...
                "forces", "nstep", "e", "grad_k", "alpha", "linmin", ...
                "t_s", "nelectrons", "abs_magneticmoment", ...
                "tot_magneticmoment", "mu", "elec_nstep", "elec_e", ...
                "elec_grad_k", "elec_alpha", "elec_linmin", ...
                "charges", "magnetic_moments", "selective_dynamics", ...
                "structure"];
            for name = names
                obj.(name) = last.(name);
            end
            obj.geom_converged = last.geom_converged;
            obj.geom_converged_reason = last.geom_converged_reason;
            if isa(last.elecmindata, ...
                    "kssolv.analysis.matgenlab.io.jdftx.JElSteps")
                obj.elec_converged = logical(last.elecmindata.converged);
                obj.elec_converged_reason = last.elecmindata.converged_reason;
            end
        end
    end
end
