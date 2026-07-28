classdef VaspInputSet
    %VASPINPUTSET Generate a coherent set of VASP inputs.
    %
    % Native MATLAB port of pymatgen-core v2026.7.24
    % pymatgen.io.vasp.sets.VaspInputSet.  The bundled configuration is a
    % frozen, merged representation of the upstream YAML data.  Reading
    % licensed POTCAR data is disabled unless allow_potcar is explicitly set.

    properties
        config_dict = struct()
        files_to_transfer = struct()
        user_incar_settings = struct()
        user_kpoints_settings = struct()
        user_potcar_settings = struct()
        constrain_total_magmom (1,1) logical = false
        sort_structure (1,1) logical = true
        user_potcar_functional = []
        force_gamma (1,1) logical = false
        reduce_structure = []
        vdw = []
        use_structure_charge (1,1) logical = false
        standardize (1,1) logical = false
        sym_prec (1,1) double = 0.1
        international_monoclinic (1,1) logical = true
        validate_magmom (1,1) logical = true
        inherit_incar = false
        auto_kspacing (1,1) logical = false
        auto_ismear (1,1) logical = false
        auto_ispin (1,1) logical = false
        auto_lreal (1,1) logical = false
        auto_metal_kpoints (1,1) logical = false
        bandgap_tol (1,1) double = 1.0e-4
        bandgap = []
        prev_incar = []
        prev_kpoints = []
        allow_potcar (1,1) logical = false
        extra_incar_updates = struct()
        extra_kpoints_updates = struct()
        xc_functional (1,1) string = "r2SCAN"
        dispersion = []
        lepsilon (1,1) logical = false
        lcalcpol (1,1) logical = false
        reciprocal_density (1,1) double = 100
        small_gap_multiply = []
        mode (1,1) string = ""
        copy_chgcar (1,1) logical = false
        copy_wavecar (1,1) logical = false
        nbands_factor (1,1) double = 1.2
        nbands = []
        ncores (1,1) double = 16
        nedos (1,1) double = 2001
        dedos (1,1) double = 0.005
        kpoints_line_density (1,1) double = 20
        zero_weighted_reciprocal_density (1,1) double = 100
        optics (1,1) logical = false
        added_kpoints = []
        saxis (1,3) double = [0,0,1]
        magmom = []
        isotopes = []
        k_product (1,1) double = 50
        bulk (1,1) logical = false
        auto_dipole (1,1) logical = false
        set_mix (1,1) logical = true
        slab_mode (1,1) logical = false
        is_metal (1,1) logical = true
        start_temp (1,1) double = 0
        end_temp (1,1) double = 300
        nsteps (1,1) double = 1000
        time_step = 2
        spin_polarized (1,1) logical = false
    end

    properties (Dependent)
        structure
    end

    properties (Dependent, SetAccess = private)
        incar_updates
        kpoints_updates
        incar
        poscar
        potcar_functional
        nelect
        kpoints
        potcar
        potcar_symbols
    end

    properties (Access = protected)
        structure_ = []
        set_name (1,1) string = "VaspInputSet"
    end

    methods
        function obj = VaspInputSet(structure, config, varargin)
            if nargin < 1, structure = []; end
            if nargin < 2 || isempty(config), config = struct(); end
            if ischar(config) || (isstring(config) && isscalar(config))
                obj.set_name = string(config);
                config = obj.load_config(config);
            end
            obj.config_dict = config;
            obj = obj.apply_options(varargin);
            if isempty(obj.user_potcar_functional)
                if isfield(config, "POTCAR_FUNCTIONAL")
                    obj.user_potcar_functional = ...
                        string(config.POTCAR_FUNCTIONAL);
                else
                    obj.user_potcar_functional = "PBE";
                end
            end
            obj.structure = structure;
        end

        function value = get.structure(obj), value = obj.structure_; end

        function obj = set.structure(obj, value)
            if isempty(value), obj.structure_ = []; return; end
            if ~isa(value, "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:VaspInputSet:StructureType", ...
                    "structure must be a matgenlab Structure or IStructure.");
            end
            if obj.sort_structure
                try
                    value = value.get_sorted_structure();
                catch exception
                    if exception.identifier ~= "MATLAB:TooManyInputs"
                        rethrow(exception);
                    end
                    % Compatibility with Structure implementations that do
                    % not yet accept the optional charge forwarding keyword.
                end
            end
            if ~isempty(obj.reduce_structure)
                value = value.get_reduced_structure(obj.reduce_structure);
            end
            if obj.standardize
                value = kssolv.analysis.matgenlab.io.vasp. ...
                    standardize_structure(value, obj.sym_prec, ...
                    obj.international_monoclinic);
            end
            if obj.validate_magmom
                value = kssolv.analysis.matgenlab.io.vasp. ...
                    get_valid_magmom_struct(value, "auto");
            end
            obj.structure_ = value;
        end

        function value = get.incar_updates(obj)
            value = obj.extra_incar_updates;
        end

        function value = get.kpoints_updates(obj)
            value = obj.extra_kpoints_updates;
        end

        function value = get.poscar(obj)
            obj.require_structure();
            value = kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                obj.structure_, sort_structure = false);
        end

        function value = get.potcar_functional(obj)
            value = string(obj.user_potcar_functional);
        end

        function value = get.potcar_symbols(obj)
            symbols = obj.poscar.site_symbols;
            value = strings(1, numel(symbols));
            settings = struct();
            if isfield(obj.config_dict, "POTCAR")
                settings = obj.config_dict.POTCAR;
            end
            settings = obj.merge_struct(settings, obj.user_potcar_settings);
            for index = 1:numel(symbols)
                key = char(symbols(index));
                if isfield(settings, key)
                    selected = settings.(key);
                    if isstruct(selected) && isfield(selected, "symbol")
                        selected = selected.symbol;
                    end
                    value(index) = string(selected);
                else
                    value(index) = symbols(index);
                end
            end
        end

        function value = get.potcar(obj)
            if ~obj.allow_potcar
                error("KSSOLV:Matgenlab:VaspInputSet:PotcarAuthorization", ...
                    "Licensed POTCAR access is disabled. Set allow_potcar=true " + ...
                    "explicitly, or request get_input_set(...,potcar_spec=true).");
            end
            value = kssolv.analysis.matgenlab.io.vasp.Potcar( ...
                obj.potcar_symbols, obj.potcar_functional);
        end

        function value = get.nelect(obj)
            if ~obj.allow_potcar
                error("KSSOLV:Matgenlab:VaspInputSet:PotcarAuthorization", ...
                    "nelect requires explicitly authorized POTCAR access.");
            end
            datasets = obj.potcar;
            value = 0;
            counts = obj.poscar.natoms;
            for index = 1:datasets.count
                value = value + counts(index) * datasets(index).nelectrons;
            end
            if isprop(obj.structure_, "charge")
                value = value - obj.structure_.charge;
            end
        end

        function value = get.incar(obj)
            obj.require_structure();
            settings = struct();
            if isfield(obj.config_dict, "INCAR")
                settings = obj.config_dict.INCAR;
            end
            settings = obj.merge_struct(settings, obj.incar_updates);
            settings = obj.merge_struct(settings, obj.user_incar_settings);
            value = kssolv.analysis.matgenlab.io.vasp.Incar();
            names = string(fieldnames(settings)).';
            for name = names
                setting = settings.(char(name));
                if isempty(setting), continue; end
                if name == "EDIFF_PER_ATOM"
                    if ~isfield(settings, "EDIFF")
                        value = value.set("EDIFF", ...
                            double(setting) * obj.structure_.num_sites);
                    end
                    continue
                end
                if name == "MAGMOM" && isstruct(setting)
                    setting = obj.site_magmoms(setting);
                elseif any(name == ["LDAUU","LDAUJ","LDAUL"]) && ...
                        isstruct(setting)
                    setting = obj.hubbard_values(setting);
                end
                value = value.set(name, setting);
            end
            if value.contains("LDAU")
                enabled = logical(value.get("LDAU"));
                if enabled
                    values = value.get("LDAUU", 0);
                    enabled = any(values ~= 0);
                end
                if ~enabled
                    for name = ["LDAU","LDAUU","LDAUJ","LDAUL", ...
                            "LDAUTYPE","LDAUPRINT"]
                        value = value.remove(name);
                    end
                end
            end
            if obj.auto_ismear
                if isempty(obj.bandgap)
                    value = value.set("ISMEAR", 0);
                    value = value.set("SIGMA", 0.2);
                elseif obj.bandgap <= obj.bandgap_tol
                    value = value.set("ISMEAR", 2);
                    value = value.set("SIGMA", 0.2);
                else
                    value = value.set("ISMEAR", -5);
                    value = value.set("SIGMA", 0.05);
                end
            end
            if obj.auto_kspacing && ...
                    (~value.contains("KSPACING") || ...
                    string(value.get("KSPACING")) == "auto")
                value = value.set("KSPACING", ...
                    kssolv.analysis.matgenlab.io.vasp.auto_kspacing( ...
                    obj.bandgap, obj.bandgap_tol));
            end
            if obj.constrain_total_magmom && value.contains("MAGMOM")
                moments = value.get("MAGMOM");
                value = value.set("NUPDOWN", ...
                    sum(moments(abs(moments) > 0.6)));
            end
            if obj.use_structure_charge
                value = value.set("NELECT", obj.nelect);
            end
            % Calculation-specific updates take precedence over automatic
            % defaults, matching pymatgen's final update phase.
            for name = string(fieldnames(obj.incar_updates)).'
                update = obj.incar_updates.(char(name));
                if isempty(update), value = value.remove(name);
                else, value = value.set(name, update);
                end
            end
            for name = string(fieldnames(obj.user_incar_settings)).'
                update = obj.user_incar_settings.(char(name));
                if isempty(update), value = value.remove(name);
                elseif ~isstruct(update), value = value.set(name, update);
                end
            end
        end

        function value = get.kpoints(obj)
            obj.require_structure();
            if isa(obj.user_kpoints_settings, ...
                    "kssolv.analysis.matgenlab.io.vasp.Kpoints")
                value = obj.user_kpoints_settings.copy();
                return
            end
            if obj.incar.contains("KSPACING") && ...
                    isempty(fieldnames(obj.user_kpoints_settings))
                value = [];
                return
            end
            settings = struct();
            if isfield(obj.config_dict, "KPOINTS")
                settings = obj.config_dict.KPOINTS;
            end
            updates = obj.kpoints_updates;
            if isa(updates, "kssolv.analysis.matgenlab.io.vasp.Kpoints")
                value = updates.copy();
                return
            end
            settings = obj.merge_struct(settings, updates);
            settings = obj.merge_struct(settings, ...
                obj.user_kpoints_settings);
            if isfield(settings, "grid_density")
                value = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    automatic_density(obj.structure_, settings.grid_density, ...
                    force_gamma = obj.force_gamma);
            elseif isfield(settings, "reciprocal_density")
                value = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    automatic_density_by_vol(obj.structure_, ...
                    settings.reciprocal_density, ...
                    force_gamma = obj.force_gamma);
            elseif isfield(settings, "length")
                value = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    automatic(settings.length);
            elseif isfield(settings, "grid")
                value = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    gamma_automatic(settings.grid);
            else
                value = kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    gamma_automatic([1,1,1]);
            end
        end

        function output = get_input_set(obj, varargin)
            options = obj.parse_get_options(varargin);
            if ~isempty(options.prev_dir)
                obj = obj.override_from_prev_calc(options.prev_dir);
            end
            if ~isempty(options.structure), obj.structure = options.structure; end
            obj.require_structure();
            if options.potcar_spec
                pseudo = strjoin(obj.potcar_symbols, newline) + newline;
            else
                pseudo = obj.potcar;
            end
            output = kssolv.analysis.matgenlab.io.vasp.VaspInput( ...
                obj.incar, obj.kpoints, obj.poscar, pseudo, ...
                potcar_spec = options.potcar_spec);
        end

        function output = get_vasp_input(obj, varargin)
            output = obj.get_input_set(varargin{:});
        end

        function write_input(obj, output_dir, varargin)
            options = obj.parse_write_options(varargin);
            inputs = obj.get_input_set( ...
                potcar_spec = options.potcar_spec);
            cifName = [];
            if ~isequal(options.include_cif, false)
                if ischar(options.include_cif) || isstring(options.include_cif)
                    cifName = string(options.include_cif);
                else
                    cifName = replace(obj.structure_.formula, " ", "") + ".cif";
                end
            end
            zipName = [];
            if ~isequal(options.zip_output, false)
                if ischar(options.zip_output) || isstring(options.zip_output)
                    zipName = string(options.zip_output);
                else
                    zipName = obj.set_name + ".zip";
                end
            end
            inputs.write_input(output_dir = string(output_dir), ...
                make_dir_if_not_present = ...
                options.make_dir_if_not_present, cif_name = cifName, ...
                zip_name = zipName, ...
                files_to_transfer = obj.files_to_transfer);
        end

        function output = as_dict(obj, verbosity)
            if nargin < 2, verbosity = 2; end
            output = struct();
            output.x_module = "pymatgen.io.vasp.sets";
            output.x_class = obj.set_name;
            if verbosity ~= 1 && ~isempty(obj.structure_)
                output.structure = obj.structure_.as_dict();
            end
            names = ["config_dict","files_to_transfer", ...
                "user_incar_settings","user_kpoints_settings", ...
                "user_potcar_settings","constrain_total_magmom", ...
                "sort_structure","user_potcar_functional","force_gamma", ...
                "reduce_structure","vdw","use_structure_charge", ...
                "standardize","sym_prec","international_monoclinic", ...
                "validate_magmom","inherit_incar","auto_kspacing", ...
                "auto_ismear","auto_ispin","auto_lreal", ...
                "auto_metal_kpoints","bandgap_tol","bandgap", ...
                "allow_potcar"];
            for name = names, output.(char(name)) = obj.(name); end
        end

        function value = estimate_nbands(obj)
            obj.require_structure();
            electrons = obj.nelect;
            inputIncar = obj.incar;
            if inputIncar.get("ISPIN", 2) == 1
                magnetic = 0;
            else
                magnetic = floor((sum(inputIncar.get("MAGMOM", 0)) + 1) / 2);
            end
            value = max(floor((electrons + 2) / 2) + ...
                max(floor(obj.structure_.num_sites / 2), 3), ...
                floor(electrons * 0.6)) + magnetic;
            if inputIncar.get("LNONCOLLINEAR", false), value = 2 * value; end
            parallel = inputIncar.get("NPAR", 0);
            if parallel, value = floor((value + parallel - 1) / parallel) * parallel; end
        end

        function obj = override_from_prev_calc(obj, prev_calc_dir)
            base = string(prev_calc_dir);
            if isfile(fullfile(base, "CONTCAR"))
                obj.structure = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    from_file(fullfile(base, "CONTCAR")).structure;
            elseif isfile(fullfile(base, "POSCAR"))
                obj.structure = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    from_file(fullfile(base, "POSCAR")).structure;
            else
                error("KSSOLV:Matgenlab:VaspInputSet:PreviousStructure", ...
                    "No CONTCAR or POSCAR exists in '%s'.", base);
            end
            if isfile(fullfile(base, "INCAR"))
                obj.prev_incar = kssolv.analysis.matgenlab.io.vasp.Incar. ...
                    from_file(fullfile(base, "INCAR"));
            end
            if isfile(fullfile(base, "KPOINTS"))
                obj.prev_kpoints = ...
                    kssolv.analysis.matgenlab.io.vasp.Kpoints. ...
                    from_file(fullfile(base, "KPOINTS"));
            end
            for name = ["CHGCAR","WAVECAR","WAVEDER","WFULL"]
                source = fullfile(base, name);
                if isfile(source)
                    obj.files_to_transfer.(char(name)) = source;
                end
            end
        end

        function [coarse, fine] = calculate_ng(obj, varargin)
            options = struct("max_prime_factor", 7, "must_inc_2", true, ...
                "custom_encut", [], "custom_prec", []);
            options = obj.option_struct(options, varargin);
            encut = options.custom_encut;
            if isempty(encut), encut = obj.incar.get("ENCUT", []); end
            if isempty(encut)
                error("KSSOLV:Matgenlab:VaspInputSet:EncToGrid", ...
                    "ENCUT is required when POTCAR access is unavailable.");
            end
            precision = options.custom_prec;
            if isempty(precision), precision = obj.incar.get("PREC", "Normal"); end
            lengths = obj.structure_.lattice.abc;
            cutoff = sqrt(encut / 13.605693122994) ./ ...
                (2 * pi ./ (lengths / 0.529177210903));
            if startsWith(lower(string(precision)), ["a","s"])
                factor = 4;
            else
                factor = 3;
            end
            coarse = zeros(1, 3);
            for index = 1:3
                guess = floor(factor * cutoff(index) + 0.5);
                coarse(index) = kssolv.analysis.matgenlab.io.vasp. ...
                    next_num_with_prime_factors(guess, ...
                    options.max_prime_factor, options.must_inc_2);
            end
            if startsWith(lower(string(precision)), ["a","n"])
                fine = 2 * coarse;
            else
                fine = coarse;
            end
        end
    end

    methods (Static)
        function obj = from_prev_calc(prev_calc_dir, varargin)
            obj = kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                [], struct(), varargin{:});
            obj = obj.override_from_prev_calc(prev_calc_dir);
        end

        function output = from_directory(directory, optional_files)
            if nargin < 2, optional_files = struct(); end
            output = kssolv.analysis.matgenlab.io.vasp.VaspInput. ...
                from_directory(directory, optional_files);
        end

        function obj = from_dict(input)
            structure = [];
            if isfield(input, "structure") && ~isempty(input.structure)
                structure = kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(input.structure);
            end
            config = struct();
            if isfield(input, "config_dict"), config = input.config_dict; end
            options = {};
            excluded = ["x_module","x_class","structure","config_dict"];
            for name = string(fieldnames(input)).'
                if any(name == excluded), continue; end
                options(end + 1:end + 2) = {char(name), input.(char(name))};
            end
            obj = kssolv.analysis.matgenlab.io.vasp.VaspInputSet( ...
                structure, config, options{:});
        end
    end

    methods (Access = protected)
        function require_structure(obj)
            if isempty(obj.structure_)
                error("KSSOLV:Matgenlab:VaspInputSet:NoStructure", ...
                    "No structure is associated with the input set.");
            end
        end

        function obj = apply_options(obj, input)
            if isempty(input), return; end
            if isscalar(input) && isstruct(input{1})
                names = string(fieldnames(input{1})).';
                values = struct2cell(input{1}).';
            else
                if mod(numel(input), 2) ~= 0
                    error("KSSOLV:Matgenlab:VaspInputSet:Options", ...
                        "Options must be name/value pairs.");
                end
                names = string(input(1:2:end));
                values = input(2:2:end);
            end
            for index = 1:numel(names)
                name = char(names(index));
                if ~isprop(obj, name)
                    error("KSSOLV:Matgenlab:VaspInputSet:Option", ...
                        "Unknown option '%s'.", name);
                end
                obj.(name) = values{index};
            end
        end

        function output = site_magmoms(obj, mapping)
            output = zeros(1, obj.structure_.num_sites);
            for index = 1:obj.structure_.num_sites
                symbol = char(obj.structure_(index).specie.symbol);
                if isfield(mapping, symbol)
                    output(index) = mapping.(symbol);
                else
                    output(index) = 0.6;
                end
            end
        end

        function output = hubbard_values(obj, mapping)
            symbols = obj.poscar.site_symbols;
            if isempty(fieldnames(mapping))
                output = zeros(1, numel(symbols));
                return
            end
            selected = mapping;
            outer = string(fieldnames(mapping)).';
            structureSymbols = strings(1, obj.structure_.num_sites);
            for index = 1:obj.structure_.num_sites
                structureSymbols(index) = ...
                    obj.structure_(index).specie.symbol;
            end
            match = outer(ismember(outer, structureSymbols));
            for name = match
                if isstruct(mapping.(char(name)))
                    selected = mapping.(char(name));
                    break
                end
            end
            output = zeros(1, numel(symbols));
            for index = 1:numel(symbols)
                name = char(symbols(index));
                if isfield(selected, name) && isnumeric(selected.(name))
                    output(index) = selected.(name);
                end
            end
        end
    end

    methods (Static, Access = protected)
        function output = load_config(name)
            root = fileparts(mfilename("fullpath"));
            filename = fullfile(root, "+sets_data", string(name) + ".json");
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:VaspInputSet:Config", ...
                    "Unknown frozen VASP set configuration '%s'.", name);
            end
            output = jsondecode(fileread(filename));
        end

        function output = merge_struct(base, updates)
            output = base;
            if isempty(updates), return; end
            if ~isstruct(updates)
                error("KSSOLV:Matgenlab:VaspInputSet:Mapping", ...
                    "Settings updates must be a struct.");
            end
            for name = string(fieldnames(updates)).'
                value = updates.(char(name));
                if isempty(value)
                    if isfield(output, char(name))
                        output = rmfield(output, char(name));
                    end
                else
                    output.(char(name)) = value;
                end
            end
        end

        function output = option_struct(defaults, input)
            output = defaults;
            if isscalar(input) && isstruct(input{1})
                for name = string(fieldnames(input{1})).'
                    output.(char(name)) = input{1}.(char(name));
                end
                return
            end
            for index = 1:2:numel(input)
                output.(char(string(input{index}))) = input{index + 1};
            end
        end

        function output = parse_get_options(input)
            defaults = struct("structure", [], "prev_dir", [], ...
                "potcar_spec", false);
            output = kssolv.analysis.matgenlab.io.vasp.VaspInputSet. ...
                option_struct(defaults, input);
        end

        function output = parse_write_options(input)
            defaults = struct("make_dir_if_not_present", true, ...
                "include_cif", false, "potcar_spec", false, ...
                "zip_output", false);
            output = kssolv.analysis.matgenlab.io.vasp.VaspInputSet. ...
                option_struct(defaults, input);
        end
    end
end
