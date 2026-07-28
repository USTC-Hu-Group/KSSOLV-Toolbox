classdef JOutStructure
    %JOUTSTRUCTURE Structure plus one JDFTx optimization-step metadata set.
    properties
        lattice double = zeros(3)
        species string = strings(0, 1)
        coords double = zeros(0, 3)
        site_properties struct = struct()
        opt_type = []
        etype = []
        eopt_type = []
        emin_flag = []
        ecomponents = []
        elecmindata = []
        stress = []
        kinetic_stress = []
        strain = []
        forces = []
        nstep = []
        e = []
        grad_k = []
        alpha = []
        linmin = []
        t_s = []
        geom_converged (1, 1) logical = false
        geom_converged_reason = []
        mu = []
        nelectrons = []
        abs_magneticmoment = []
        tot_magneticmoment = []
        elec_nstep = []
        elec_e = []
        elec_grad_k = []
        elec_alpha = []
        elec_linmin = []
        structure = []
        is_md (1, 1) logical = false
        thermostat_velocity = []
    end
    properties (Dependent)
        charges
        magnetic_moments
        selective_dynamics
        velocities
        constraint_types
        constraint_vectors
        group_names
    end

    methods
        function obj = JOutStructure(lattice, species, coords, options)
            arguments
                lattice = zeros(3)
                species = strings(0, 1)
                coords = zeros(0, 3)
                options.site_properties struct = struct()
            end
            obj.lattice = double(lattice);
            obj.species = string(species(:));
            obj.coords = double(coords);
            obj.site_properties = options.site_properties;
            obj.structure = struct("lattice", obj.lattice, ...
                "species", obj.species, "coords", obj.coords, ...
                "coords_are_cartesian", true);
        end

        function value = get.charges(obj)
            value = obj.site_value("charges");
        end
        function obj = set.charges(obj, value)
            obj = obj.set_site_value("charges", value);
        end
        function value = get.magnetic_moments(obj)
            value = obj.site_value("magmom");
        end
        function obj = set.magnetic_moments(obj, value)
            obj = obj.set_site_value("magmom", value);
        end
        function value = get.selective_dynamics(obj)
            value = obj.site_value("selective_dynamics");
        end
        function obj = set.selective_dynamics(obj, value)
            obj = obj.set_site_value("selective_dynamics", value);
        end
        function value = get.velocities(obj)
            value = obj.site_value("velocities");
        end
        function obj = set.velocities(obj, value)
            obj = obj.set_site_value("velocities", value);
        end
        function value = get.constraint_types(obj)
            value = obj.site_value("constraint_types");
        end
        function obj = set.constraint_types(obj, value)
            obj = obj.set_site_value("constraint_types", value);
        end
        function value = get.constraint_vectors(obj)
            value = obj.site_value("constraint_vectors");
        end
        function obj = set.constraint_vectors(obj, value)
            obj = obj.set_site_value("constraint_vectors", value);
        end
        function value = get.group_names(obj)
            value = obj.site_value("group_names");
        end
        function obj = set.group_names(obj, value)
            obj = obj.set_site_value("group_names", value);
        end

        function result = as_dict(obj)
            names = properties(obj);
            result = struct();
            for idx = 1:numel(names)
                name = names{idx};
                value = obj.(name);
                if isa(value, "kssolv.analysis.matgenlab.io.jdftx.JElSteps")
                    value = value.as_dict();
                end
                result.(name) = value;
            end
        end

        function result = to_dict(obj)
            result = obj.as_dict();
        end

        function text = string(obj)
            text = string(jsonencode(obj.as_dict()));
        end

        function text = char(obj)
            text = char(string(obj));
        end
    end

    methods (Access = private)
        function value = site_value(obj, name)
            if isfield(obj.site_properties, name)
                value = obj.site_properties.(name);
            else
                value = [];
            end
        end

        function obj = set_site_value(obj, name, value)
            if isempty(value)
                if isfield(obj.site_properties, name)
                    obj.site_properties = rmfield(obj.site_properties, name);
                end
            else
                obj.site_properties.(name) = value;
            end
        end
    end
end
