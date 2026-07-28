classdef JDFTXOutfileSlice
    %JDFTXOUTFILESLICE Parsed model for one JDFTx invocation.
    properties
        prefix = []
        jstrucs = []
        jsettings_fluid = []
        jsettings_electronic = []
        jsettings_lattice = []
        jsettings_ionic = []
        xc_func = []
        lattice_initial = []
        lattice_final = []
        lattice = []
        a = []
        b = []
        c = []
        fftgrid = []
        geom_opt = []
        geom_opt_type = []
        electronic_output = []
        efermi = []
        egap = []
        optical_egap = []
        emin = []
        emax = []
        homo = []
        lumo = []
        homo_filling = []
        lumo_filling = []
        is_metal = []
        etype = []
        broadening_type = []
        broadening = []
        kgrid = []
        truncation_type = []
        truncation_radius = []
        pwcut = []
        rhocut = []
        pp_type = []
        semicore_electrons = []
        valence_electrons = []
        total_electrons_uncharged = []
        semicore_electrons_uncharged = []
        valence_electrons_uncharged = []
        nbands = []
        atom_elements = []
        atom_elements_int = []
        atom_types = []
        spintype = []
        nspin = []
        nat = []
        atom_coords_initial = []
        atom_coords_final = []
        atom_coords = []
        has_solvation = []
        fluid = []
        is_gc = []
        has_eigstats = []
        parsable_pseudos = []
        has_parsable_pseudo = []
        total_electrons = []
        t_s = []
        converged = []
        structure = []
        initial_structure = []
        trajectory = []
        eopt_type = []
        elecmindata = []
        ecomponents = []
        stress = []
        strain = []
        forces = []
        nstep = []
        e = []
        grad_k = []
        alpha = []
        linmin = []
        abs_magneticmoment = []
        tot_magneticmoment = []
        mu = []
        nelectrons = []
        elec_nstep = []
        elec_e = []
        elec_grad_k = []
        elec_alpha = []
        elec_linmin = []
        infile = []
        vibrational_modes = []
        vibrational_energy_components = []
        selective_dynamics = []
        raw_text = []
    end
    methods
        function obj = JDFTXOutfileSlice(data)
            if nargin > 0 && ~isempty(data)
                names = fieldnames(data);
                for idx = 1:numel(names)
                    if isprop(obj, names{idx})
                        obj.(names{idx}) = data.(names{idx});
                    end
                end
            end
        end

        function value = determine_is_metal(obj)
            if ~isempty(obj.is_metal)
                value = obj.is_metal;
            elseif isempty(obj.homo_filling) || isempty(obj.lumo_filling)
                value = [];
            else
                value = abs(obj.homo_filling - 1) > 0.01 || ...
                    abs(obj.lumo_filling) > 0.01;
            end
        end

        function result = to_jdftxinfile(obj)
            result = obj.infile.copy();
            result.strip_structure_tags();
            if ~isempty(obj.structure)
                structural = kssolv.analysis.matgenlab.io.jdftx. ...
                    JDFTXInfile.from_structure(obj.structure);
                result = structural + result;
            end
        end

        function write(~)
            error("KSSOLV:Matgenlab:JDFTX:OutputWriteUnsupported", ...
                "There is no need to write a JDFTx output file.");
        end

        function result = as_dict(obj)
            names = properties(obj);
            result = struct();
            for idx = 1:numel(names)
                name = names{idx};
                value = obj.(name);
                if any(strcmp(methods(value), "as_dict"))
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

    methods (Static)
        function obj = from_out_slice(text, options)
            arguments
                text
                options.is_bgw (1, 1) logical = false
                options.none_on_error (1, 1) logical = false
            end
            try
                data = kssolv.analysis.matgenlab.io.jdftx. ...
                    parse_output_slice(text);
                obj = kssolv.analysis.matgenlab.io.jdftx. ...
                    JDFTXOutfileSlice(data);
            catch exception
                if options.none_on_error
                    obj = [];
                else
                    rethrow(exception);
                end
            end
        end

    end
end
