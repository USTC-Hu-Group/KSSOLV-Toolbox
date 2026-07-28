classdef Vasprun < handle
    %VASPRUN Parse VASP vasprun.xml output without a Python dependency.
    %
    % This is a native MATLAB port of pymatgen.io.vasp.outputs.Vasprun.
    % Python dictionaries whose keys are Spin.up/Spin.down are represented
    % by structs with fields ``up`` and ``down``.  Lists of heterogeneous
    % dictionaries are represented by cell arrays of structs.

    properties
        filename (1,1) string = ""
        ionic_step_skip = []
        ionic_step_offset (1,1) double = 0
        occu_tol (1,1) double = 1e-8
        separate_spins (1,1) logical = false
        exception_on_bad_xml (1,1) logical = true

        generator = []
        incar = []
        parameters = []
        kpoints = []
        actual_kpoints = []
        actual_kpoints_weights = []
        atomic_symbols cell = cell(1, 0)
        potcar_symbols cell = cell(1, 0)
        potcar_spec cell = cell(1, 0)
        initial_structure = []
        final_structure = []
        ionic_steps cell = cell(1, 0)
        md_data cell = cell(1, 0)
        nionic_steps (1,1) double = 0
        vasp_version = []

        tdos = []
        idos = []
        pdos cell = cell(1, 0)
        efermi = []
        dos_has_errors = []
        eigenvalues = []
        projected_eigenvalues = []
        projected_magnetization = []
        dielectric_data (1,1) struct = struct()
        kpoints_opt_props = []

        force_constants = []
        normalmode_eigenvals = []
        normalmode_eigenvecs = []
    end

    properties (Dependent)
        projected_magnetisation
        structures
        epsilon_static
        epsilon_static_wolfe
        epsilon_ionic
        dielectric
        optical_absorption_coeff
        converged_electronic
        converged_ionic
        converged
        final_energy
        complete_dos
        complete_dos_normalized
        hubbards
        run_type
        is_hubbard
        is_spin
        md_n_steps
        eigenvalue_band_properties
    end

    methods
        function obj = Vasprun(filename, varargin)
            if nargin == 0, return; end
            defaults = struct( ...
                "ionic_step_skip", [], "ionic_step_offset", 0, ...
                "parse_dos", true, "parse_eigen", true, ...
                "parse_projected_eigen", false, ...
                "parse_potcar_file", true, "occu_tol", 1e-8, ...
                "separate_spins", false, ...
                "exception_on_bad_xml", true);
            options = obj.parseOptions(defaults, varargin);
            obj.filename = string(filename);
            obj.ionic_step_skip = options.ionic_step_skip;
            obj.ionic_step_offset = options.ionic_step_offset;
            obj.occu_tol = options.occu_tol;
            obj.separate_spins = logical(options.separate_spins);
            obj.exception_on_bad_xml = logical(options.exception_on_bad_xml);

            text = kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename);
            obj.parseDocument(text, logical(options.parse_dos), ...
                logical(options.parse_eigen), ...
                logical(options.parse_projected_eigen));

            if ~isequal(options.parse_potcar_file, false)
                obj.update_potcar_spec(options.parse_potcar_file);
                obj.update_charge_from_potcar(options.parse_potcar_file);
            end
            algo = upper(string(obj.incar.get("ALGO", "")));
            if ~any(algo == ["CHI", "BSE"]) && ~obj.converged && ...
                    obj.parameters.get("IBRION", -1) ~= 0
                warning("KSSOLV:Matgenlab:UnconvergedVASPWarning", ...
                    "%s is an unconverged VASP run. Electronic " + ...
                    "convergence: %d. Ionic convergence: %d.", ...
                    obj.filename, obj.converged_electronic, ...
                    obj.converged_ionic);
            end
        end

        function value = get.projected_magnetisation(obj)
            warning("KSSOLV:Matgenlab:Vasprun:DeprecatedSpelling", ...
                "projected_magnetisation is deprecated; use " + ...
                "projected_magnetization.");
            value = obj.projected_magnetization;
        end

        function set.projected_magnetisation(obj, value)
            warning("KSSOLV:Matgenlab:Vasprun:DeprecatedSpelling", ...
                "projected_magnetisation is deprecated; use " + ...
                "projected_magnetization.");
            obj.projected_magnetization = value;
        end

        function value = get.structures(obj)
            value = cellfun(@(step) step.structure, obj.ionic_steps, ...
                "UniformOutput", false);
        end

        function value = get.epsilon_static(obj)
            value = obj.lastStepField("epsilon", []);
        end

        function value = get.epsilon_static_wolfe(obj)
            value = obj.lastStepField("epsilon_rpa", []);
        end

        function value = get.epsilon_ionic(obj)
            value = obj.lastStepField("epsilon_ion", []);
        end

        function value = get.dielectric(obj)
            if isfield(obj.dielectric_data, "density")
                value = obj.dielectric_data.density;
                return
            end
            longName = matlab.lang.makeValidName( ...
                "INVERSE MACROSCOPIC DIELECTRIC TENSOR " + ...
                "(including local field effects in RPA (Hartree))");
            if isfield(obj.dielectric_data, longName)
                value = obj.dielectric_data.(longName);
            else
                value = {[], [], []};
            end
        end

        function value = get.optical_absorption_coeff(obj)
            if isfield(obj.dielectric_data, "freq_dependent")
                data = obj.dielectric_data.freq_dependent;
            elseif isfield(obj.dielectric_data, "density")
                data = obj.dielectric_data.density;
            else
                value = [];
                return
            end
            if isempty(data) || isempty(data{1})
                value = [];
                return
            end
            realAverage = mean(data{2}(:, 1:3), 2);
            imagAverage = mean(data{3}(:, 1:3), 2);
            % h*c/e in eV*m, converted to eV*cm.
            hc = 6.62607015e-34 * 299792458 / ...
                1.602176634e-19 * 100;
            value = 2 * pi * sqrt(2) / hc .* data{1}(:) .* ...
                sqrt(sqrt(realAverage.^2 + imagAverage.^2) - ...
                realAverage);
            value = reshape(value, 1, []);
        end

        function value = get.converged_electronic(obj)
            if isempty(obj.ionic_steps)
                value = upper(string(obj.incar.get("ALGO", ""))) == "CHI";
                return
            end
            steps = obj.ionic_steps{end}.electronic_steps;
            if obj.incar.get("LEPSILON", false) && numel(steps) > 1
                index = 2;
                expected = sort(["e_wo_entrp", "e_fr_energy", "e_0_energy"]);
                while index <= numel(steps)
                    names = sort(string(fieldnames(steps{index})));
                    if ~isequal(names(:), expected(:)), break; end
                    index = index + 1;
                end
                value = index ~= obj.parameters.get("NELM", 60);
                return
            end
            if upper(string(obj.incar.get("ALGO", ""))) == "EXACT" && ...
                    obj.incar.get("NELM", []) == 1
                value = true;
                return
            end
            value = numel(steps) < obj.parameters.get("NELM", 60);
        end

        function value = get.converged_ionic(obj)
            nsw = obj.parameters.get("NSW", 0);
            defaultIbrion = 0;
            if any(nsw == [-1, 0]), defaultIbrion = -1; end
            ibrion = obj.parameters.get("IBRION", defaultIbrion);
            if ibrion == 0
                value = nsw <= 1 || obj.md_n_steps == nsw;
                return
            end
            ediffg = obj.parameters.get("EDIFFG", 1);
            if any(ibrion == [1, 2]) && ediffg == 0
                value = nsw <= 1 || nsw == numel(obj.ionic_steps);
                return
            end
            value = nsw <= 1 || numel(obj.ionic_steps) < nsw;
        end

        function value = get.converged(obj)
            value = obj.converged_electronic && obj.converged_ionic;
        end

        function value = get.final_energy(obj)
            value = inf;
            if isempty(obj.ionic_steps), return; end
            step = obj.ionic_steps{end};
            if ~isfield(step, "e_0_energy"), return; end
            value = step.e_0_energy;
            if isempty(step.electronic_steps), return; end
            electronic = step.electronic_steps{end};
            if isfield(electronic, "e_0_energy") && ...
                    isfield(electronic, "e_fr_energy") && ...
                    isfield(step, "e_fr_energy")
                corrected = round(electronic.e_0_energy - ...
                    electronic.e_fr_energy + step.e_fr_energy, 8);
                if abs(value - corrected) > 1e-7, value = corrected; end
            end
        end

        function value = get.complete_dos(obj)
            if isempty(obj.tdos)
                error("KSSOLV:Matgenlab:Vasprun:MissingDos", ...
                    "No DOS data were parsed.");
            end
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos(obj.final_structure, obj.tdos, obj.pdos);
        end

        function value = get.complete_dos_normalized(obj)
            if isempty(obj.tdos)
                error("KSSOLV:Matgenlab:Vasprun:MissingDos", ...
                    "No DOS data were parsed.");
            end
            value = kssolv.analysis.matgenlab.electronic_structure. ...
                CompleteDos(obj.final_structure, obj.tdos, obj.pdos, true);
        end

        function value = get.hubbards(obj)
            value = struct();
            if ~obj.incar.get("LDAU", false), return; end
            symbols = strings(1, numel(obj.potcar_symbols));
            for index = 1:numel(symbols)
                tokens = split(strtrim(string(obj.potcar_symbols{index})));
                if numel(tokens) >= 2, symbol = tokens(2);
                else, symbol = tokens(1);
                end
                symbols(index) = extractBefore(symbol + "_", "_");
            end
            us = obj.incar.get("LDAUU", obj.parameters.get("LDAUU", []));
            js = obj.incar.get("LDAUJ", obj.parameters.get("LDAUJ", []));
            if isempty(js) || numel(js) ~= numel(us), js = zeros(size(us)); end
            if numel(us) == numel(symbols)
                for index = 1:numel(symbols)
                    key = matlab.lang.makeValidName(char(symbols(index)));
                    value.(key) = us(index) - js(index);
                end
            elseif ~(isempty(us) || (sum(us) == 0 && sum(js) == 0))
                error("KSSOLV:Matgenlab:VaspParseError", ...
                    "Length of U parameters and atomic symbols is mismatched.");
            end
        end

        function value = get.run_type(obj)
            ggaKeys = ["RE","PE","PS","RP","AM","OR","BO","MK","--"];
            ggaValues = ["revPBE","PBE","PBEsol","revPBE+Padé", ...
                "AM05","optPBE","optB88","optB86b","GGA"];
            metaKeys = ["TPSS","RTPSS","M06L","MBJ","SCAN","R2SCAN", ...
                "RSCAN","MS0","MS1","MS2"];
            metaValues = ["TPSS","revTPSS","M06-L", ...
                "modified Becke-Johnson","SCAN","R2SCAN","RSCAN", ...
                "MadeSimple0","MadeSimple1","MadeSimple2"];
            if obj.nearly(obj.parameters.get("AEXX", NaN), 1)
                value = "HF";
            elseif obj.nearly(obj.parameters.get("HFSCREEN", NaN), 0.3)
                value = "HSE03";
            elseif obj.parameters.get("HFSCREEN", -inf) >= 0.2 && ...
                    obj.parameters.get("HFSCREEN", inf) <= 0.21
                value = "HSE06";
            elseif obj.nearly(obj.parameters.get("AEXX", NaN), 0.2)
                value = "B3LYP";
            elseif obj.parameters.get("LHFCALC", false)
                value = "PBEO or other Hybrid Functional";
            elseif obj.incar.contains("METAGGA") && ...
                    ~any(string(obj.incar.get("METAGGA")) == ["--","None"])
                tag = upper(string(obj.incar.get("METAGGA")));
                found = find(metaKeys == tag, 1);
                if isempty(found), value = tag; else, value = metaValues(found); end
            elseif obj.parameters.contains("GGA")
                tag = upper(string(obj.parameters.get("GGA")));
                found = find(ggaKeys == tag, 1);
                if isempty(found), value = tag; else, value = ggaValues(found); end
            elseif ~isempty(obj.potcar_symbols) && ...
                    startsWith(string(obj.potcar_symbols{1}), "PAW")
                value = "LDA";
            else
                value = "unknown";
            end
            if obj.is_hubbard || obj.parameters.get("LDAU", false)
                value = value + "+U";
            end
            if obj.parameters.get("LUSE_VDW", false)
                value = value + "+rVV10";
            else
                ivdw = obj.incar.get("IVDW", 0);
                keys = [0,1,10,11,12,2,20,21,202,4];
                names = ["no-correction","DFT-D2","DFT-D2","DFT-D3", ...
                    "DFT-D3-BJ","TS","TS","TS-H","MBD","dDsC"];
                found = find(keys == ivdw, 1);
                if ~isempty(found) && ivdw ~= 0
                    value = value + "+vdW-" + names(found);
                elseif ~isequal(ivdw, 0)
                    value = value + "+vdW-unknown";
                end
            end
        end

        function value = get.is_hubbard(obj)
            data = obj.hubbards;
            fields = fieldnames(data);
            value = ~isempty(fields) && ...
                sum(cellfun(@(name) data.(name), fields)) > 1e-8;
        end

        function value = get.is_spin(obj)
            value = obj.parameters.get("ISPIN", 1) == 2;
        end

        function value = get.md_n_steps(obj)
            if isempty(obj.md_data), value = obj.nionic_steps;
            else, value = numel(obj.md_data);
            end
        end

        function value = get.eigenvalue_band_properties(obj)
            if isempty(obj.eigenvalues)
                error("KSSOLV:Matgenlab:Vasprun:MissingEigenvalues", ...
                    "eigenvalues is empty.");
            end
            spins = fieldnames(obj.eigenvalues);
            if obj.separate_spins && numel(spins) ~= 2
                error("KSSOLV:Matgenlab:Vasprun:SeparateSpins", ...
                    "separate_spins requires ISPIN=2 eigenvalues.");
            end
            vbms = -inf(1, numel(spins)); cbms = inf(1, numel(spins));
            vIndices = nan(1, numel(spins)); cIndices = nan(1, numel(spins));
            for spinIndex = 1:numel(spins)
                array = obj.eigenvalues.(spins{spinIndex});
                for point = 1:size(array, 1)
                    for band = 1:size(array, 2)
                        energy = array(point, band, 1);
                        occupation = array(point, band, 2);
                        if occupation > obj.occu_tol && ...
                                energy > vbms(spinIndex)
                            vbms(spinIndex) = energy; vIndices(spinIndex) = point;
                        elseif occupation <= obj.occu_tol && ...
                                energy < cbms(spinIndex)
                            cbms(spinIndex) = energy; cIndices(spinIndex) = point;
                        end
                    end
                end
            end
            if obj.separate_spins
                value = {max(cbms - vbms, 0), cbms, vbms, ...
                    vIndices == cIndices};
            else
                [vbm, vSpin] = max(vbms);
                [cbm, cSpin] = min(cbms);
                value = {max(cbm - vbm, 0), cbm, vbm, ...
                    vIndices(vSpin) == cIndices(cSpin)};
            end
        end

        function value = calculate_efermi(obj, tolerance)
            if nargin < 2 || isempty(tolerance), tolerance = 0.001; end
            if isempty(obj.eigenvalues) || isempty(obj.efermi)
                error("KSSOLV:Matgenlab:Vasprun:MissingEigenvalues", ...
                    "eigenvalues and efermi are required.");
            end
            names = fieldnames(obj.eigenvalues);
            allBands = [];
            for index = 1:numel(names)
                array = obj.eigenvalues.(names{index});
                allBands = [allBands; permute(array(:, :, 1), [2, 1])]; %#ok<AGROW>
            end
            value = obj.efermi;
            if ~obj.crossesBand(allBands, value), return; end
            for shifted = [value + tolerance, value - tolerance]
                if ~obj.crossesBand(allBands, shifted)
                    below = allBands(allBands < shifted);
                    above = allBands(allBands > shifted);
                    if ~isempty(below) && ~isempty(above)
                        value = (max(below) + min(above)) / 2;
                    end
                    return
                end
            end
        end

        function entry = get_computed_entry(obj, varargin)
            defaults = struct("inc_structure", true, "parameters", {{}}, ...
                "data", {{}}, "entry_id", []);
            options = obj.parseOptions(defaults, varargin);
            incStructure = options.inc_structure;
            requestedParameters = options.parameters;
            data = options.data;
            entryId = options.entry_id;
            if isempty(entryId)
                date = regexprep(string(obj.generator.get("DATE", "")), ...
                    "\\s", "");
                time = string(obj.generator.get("TIME", ""));
                digest = obj.structureDigest(obj.final_structure);
                entryId = "vasprun-" + date + "-" + time + "-" + digest;
            end
            defaults = ["is_hubbard","hubbards","potcar_symbols", ...
                "potcar_spec","run_type"];
            requested = unique([defaults, ...
                reshape(string(requestedParameters), 1, [])]);
            paramValues = struct();
            for name = requested
                paramValues.(matlab.lang.makeValidName(name)) = obj.(name);
            end
            dataValues = struct();
            for name = reshape(string(data), 1, [])
                dataValues.(matlab.lang.makeValidName(name)) = obj.(name);
            end
            if incStructure
                entry = kssolv.analysis.matgenlab.core. ...
                    ComputedStructureEntry(obj.final_structure, ...
                    obj.final_energy, "parameters", paramValues, ...
                    "data", dataValues, "entry_id", entryId);
            else
                entry = kssolv.analysis.matgenlab.core.ComputedEntry( ...
                    obj.final_structure.composition, obj.final_energy, ...
                    "parameters", paramValues, "data", dataValues, ...
                    "entry_id", entryId);
            end
        end

        function result = get_band_structure(obj, varargin)
            defaults = struct("kpoints_filename", [], "efermi", [], ...
                "line_mode", false, "force_hybrid_mode", false, ...
                "ignore_kpoints_opt", false);
            options = obj.parseOptions(defaults, varargin);
            kpointsFilename = options.kpoints_filename;
            efermiValue = options.efermi;
            lineMode = options.line_mode;
            forceHybridMode = options.force_hybrid_mode; %#ok<NASGU>
            ignoreKpointsOpt = options.ignore_kpoints_opt;
            if isempty(efermiValue), efermiValue = obj.efermi; end
            if string(efermiValue) == "smart"
                efermiValue = obj.calculate_efermi();
            end
            eigen = obj.eigenvalues;
            projections = obj.projected_eigenvalues;
            points = obj.actual_kpoints;
            kpointsObject = obj.kpoints;
            if ~ignoreKpointsOpt && ~isempty(obj.kpoints_opt_props) && ...
                    ~isempty(obj.kpoints_opt_props.eigenvalues)
                eigen = obj.kpoints_opt_props.eigenvalues;
                projections = obj.kpoints_opt_props.projected_eigenvalues;
                points = obj.kpoints_opt_props.actual_kpoints;
                kpointsObject = obj.kpoints_opt_props.kpoints;
            end
            if isempty(eigen)
                error("KSSOLV:Matgenlab:Vasprun:MissingEigenvalues", ...
                    "Eigenvalues were not parsed.");
            end
            names = fieldnames(eigen);
            bands = struct();
            for index = 1:numel(names)
                bands.(names{index}) = permute( ...
                    eigen.(names{index})(:, :, 1), [2, 1]);
            end
            projected = struct();
            if ~isempty(projections)
                for index = 1:numel(names)
                    if isfield(projections, names{index})
                        projected.(names{index}) = permute( ...
                            projections.(names{index}), [2,1,4,3]);
                    end
                end
            end
            labels = containers.Map("KeyType", "char", "ValueType", "any");
            if isempty(kpointsFilename)
                kpointsFilename = obj.defaultKpointsFilename();
            end
            if ~isempty(kpointsFilename) && isfile(kpointsFilename)
                kpointsObject = kssolv.analysis.matgenlab.io.vasp. ...
                    Kpoints.from_file(kpointsFilename);
                if string(kpointsObject.style) == "Line_mode"
                    lineMode = true;
                end
            end
            if lineMode
                if ~isempty(kpointsObject.labels)
                    for index = 1:min(numel(kpointsObject.labels), ...
                            size(kpointsObject.kpts, 1))
                        label = string(kpointsObject.labels(index));
                        if strlength(label) > 0 && ~ismissing(label)
                            labels(char(label)) = kpointsObject.kpts(index, :);
                        end
                    end
                end
            end
            reciprocal = obj.final_structure.lattice.reciprocal_lattice;
            if lineMode
                result = kssolv.analysis.matgenlab.electronic_structure. ...
                    BandStructureSymmLine(points, bands, reciprocal, ...
                    efermiValue, labels, false, obj.final_structure, projected);
            else
                result = kssolv.analysis.matgenlab.electronic_structure. ...
                    BandStructure(points, bands, reciprocal, efermiValue, ...
                    labels, false, obj.final_structure, projected);
            end
        end

        function potcar = get_potcars(obj, path)
            if nargin < 2 || isequal(path, false) || isempty(path)
                potcar = [];
                return
            end
            path = string(path);
            if isequal(path, true)
                path = string(fileparts(obj.filename));
                if strlength(path) == 0, path = "."; end
            end
            candidates = strings(1, 0);
            if contains(path, "POTCAR") && isfile(path)
                candidates = path;
            elseif isfolder(path)
                listing = dir(fullfile(path, "POTCAR*"));
                listing = listing(~contains({listing.name}, ".spec"));
                candidates = string(fullfile({listing.folder}, {listing.name}));
            end
            potcar = [];
            for candidate = candidates
                try
                    current = kssolv.analysis.matgenlab.io.vasp. ...
                        Potcar.from_file(candidate);
                    headers = strings(1,current.count);
                    for headerIndex=1:current.count
                        headers(headerIndex)=current(headerIndex).header;
                    end
                    if isequal(sort(unique(headers)), ...
                            sort(unique(string(obj.potcar_symbols))))
                        potcar = current;
                        return
                    end
                catch
                    % A non-POTCAR file matching the filename glob is ignored.
                end
            end
        end

        function trajectory = get_trajectory(obj)
            steps = obj.ionic_steps;
            if ~isempty(obj.md_data), steps = obj.md_data; end
            trajectoryStructures = cell(1, numel(steps));
            for index = 1:numel(steps)
                properties = steps{index}.structure.site_properties;
                if isfield(steps{index}, "forces")
                    properties.forces = num2cell(steps{index}.forces, 2);
                end
                trajectoryStructures{index} = ...
                    steps{index}.structure.copy(properties);
            end
            trajectory = kssolv.analysis.matgenlab.core.Trajectory. ...
                from_structures(trajectoryStructures, false);
        end

        function update_potcar_spec(obj, path)
            potcar = obj.get_potcars(path);
            if isempty(potcar), return; end
            specs = cell(1, numel(obj.potcar_symbols));
            for index = 1:numel(obj.potcar_symbols)
                tokens = split(string(obj.potcar_symbols{index}));
                symbol = tokens(min(2, numel(tokens)));
                for psIndex = 1:potcar.count
                    if string(potcar(psIndex).symbol) == symbol
                        specs{index} = potcar(psIndex).spec();
                        break
                    end
                end
            end
            obj.potcar_spec = specs;
        end

        function update_charge_from_potcar(obj, path)
            potcar = obj.get_potcars(path);
            if isempty(potcar), return; end
            blocked = ["GW0","G0W0","GW","BSE","CHI","QPGW", ...
                "QPGW0","EVGW","EVGW0","GWR","GW0R"];
            if any(upper(string(obj.incar.get("ALGO", ""))) == blocked), return; end
            counts = [];
            if ~isempty(obj.atomic_symbols)
                [~, ~, groups] = unique(string(obj.atomic_symbols), "stable");
                counts = accumarray(groups(:), 1).';
            end
            if numel(counts) ~= potcar.count
                counts = ones(1, potcar.count);
            end
            zvals=zeros(1,potcar.count);
            for potcarIndex=1:potcar.count
                zvals(potcarIndex)=potcar(potcarIndex).ZVAL;
            end
            neutral = sum(zvals .* counts);
            charge = neutral - obj.parameters.get("NELECT", neutral);
            for index = 1:numel(obj.ionic_steps)
                if ~isempty(obj.ionic_steps{index}.structure)
                    obj.ionic_steps{index}.structure = ...
                        obj.ionic_steps{index}.structure.set_charge(charge);
                end
            end
            if ~isempty(obj.initial_structure)
                obj.initial_structure = obj.initial_structure.set_charge(charge);
            end
            if ~isempty(obj.final_structure)
                obj.final_structure = obj.final_structure.set_charge(charge);
            end
        end

        function output = as_dict(obj)
            symbols = unique(string(obj.atomic_symbols), "sorted");
            output = struct( ...
                "vasp_version", obj.vasp_version, ...
                "has_vasp_completed", obj.converged, ...
                "nsites", obj.final_structure.num_sites, ...
                "unit_cell_formula", obj.final_structure.composition.as_dict(), ...
                "pretty_formula", obj.final_structure.composition.reduced_formula, ...
                "is_hubbard", obj.is_hubbard, "hubbards", obj.hubbards, ...
                "elements", symbols, "nelements", numel(symbols), ...
                "run_type", obj.run_type);
            input = struct("incar", obj.incar.as_dict(), ...
                "crystal", obj.initial_structure.as_dict(), ...
                "kpoints", obj.kpoints.as_dict(), ...
                "nkpoints", size(obj.actual_kpoints, 1), ...
                "potcar", {obj.potcarElementNames()}, ...
                "potcar_spec", {obj.potcar_spec}, ...
                "parameters", obj.parameters.as_dict(), ...
                "lattice_rec", ...
                obj.final_structure.lattice.reciprocal_lattice.as_dict());
            actual = cell(1, size(obj.actual_kpoints, 1));
            for index = 1:numel(actual)
                actual{index} = struct("abc", obj.actual_kpoints(index, :), ...
                    "weight", obj.actual_kpoints_weights(index));
            end
            input.kpoints.actual_points = actual;
            output.input = input;
            result = struct("ionic_steps", {obj.ionic_steps}, ...
                "final_energy", obj.final_energy, ...
                "final_energy_per_atom", ...
                obj.final_energy / obj.final_structure.num_sites, ...
                "crystal", obj.final_structure.as_dict(), ...
                "efermi", obj.efermi, ...
                "epsilon_static", obj.epsilon_static, ...
                "epsilon_static_wolfe", obj.epsilon_static_wolfe, ...
                "epsilon_ionic", obj.epsilon_ionic);
            if ~isempty(obj.eigenvalues)
                result.eigenvalues = obj.eigenvalues;
                props = obj.eigenvalue_band_properties;
                result.bandgap = props{1}; result.cbm = props{2};
                result.vbm = props{3}; result.is_gap_direct = props{4};
            end
            if ~isempty(obj.projected_eigenvalues)
                result.projected_eigenvalues = obj.projected_eigenvalues;
            end
            if ~isempty(obj.projected_magnetization)
                result.projected_magnetization = obj.projected_magnetization;
            end
            output.output = result;
        end

        function output = asDict(obj), output = obj.as_dict(); end
    end

    methods (Access = protected)
        function parseDocument(obj, text, parseDos, parseEigen, parseProjected)
            obj.incar = kssolv.analysis.matgenlab.io.vasp.Incar();
            obj.parameters = kssolv.analysis.matgenlab.io.vasp.Incar();
            try
                parser = matlab.io.xml.dom.Parser;
                document = parser.parseString(char(text));
            catch exception
                if obj.exception_on_bad_xml, rethrow(exception); end
                closing = regexp(text, "</calculation>", "end");
                if isempty(closing)
                    error("KSSOLV:Matgenlab:VaspParseError", ...
                        "Malformed XML has no complete calculation block.");
                end
                repaired = text(1:closing(end)) + "</modeling>";
                parser = matlab.io.xml.dom.Parser;
                document = parser.parseString(char(repaired));
                warning("KSSOLV:Matgenlab:Vasprun:MalformedXML", ...
                    "XML is malformed; only complete data were parsed.");
            end
            root = document.getDocumentElement();
            obj.parseHeader(root);
            calculations = obj.nodes(root, "calculation");
            obj.nionic_steps = numel(calculations);
            skip = obj.ionic_step_skip;
            if isempty(skip), skip = 1; end
            selected = (obj.ionic_step_offset + 1):skip:numel(calculations);
            for index = selected
                obj.ionic_steps{end + 1} = obj.parseIonicStep( ...
                    calculations{index});
            end
            if ~isempty(obj.ionic_steps) && ...
                    ~isempty(obj.ionic_steps{end}.structure)
                obj.final_structure = obj.ionic_steps{end}.structure;
            end
            finalNodes = obj.nodes(root, "structure");
            for index = 1:numel(finalNodes)
                if obj.attr(finalNodes{index}, "name") == "finalpos"
                    obj.final_structure = obj.parseStructure(finalNodes{index});
                end
            end
            if isempty(obj.final_structure), obj.final_structure = obj.initial_structure; end

            obj.parseMlData(root);
            obj.parseDynamicalMatrix(root);
            obj.parseDielectric(root);
            obj.parseKpointsOpt(root, parseDos, parseEigen, parseProjected);
            obj.parseFermiLevel(root);
            if parseDos, obj.parseFinalDos(root); end
            if parseEigen, obj.parseFinalEigen(root); end
            if parseProjected, obj.parseFinalProjected(root); end
            obj.vasp_version = obj.generator.get("version", ...
                obj.generator.get("VERSION", ""));
        end

        function parseHeader(obj, root)
            generators = obj.nodes(root, "generator");
            if ~isempty(generators), obj.generator = obj.parseParams(generators{1});
            else, obj.generator = kssolv.analysis.matgenlab.io.vasp.Incar();
            end
            incars = obj.nodes(root, "incar");
            if ~isempty(incars), obj.incar = obj.parseParams(incars{1}); end
            params = obj.nodes(root, "parameters");
            if ~isempty(params), obj.parameters = obj.parseParams(params{1}); end
            atomInfos = obj.nodes(root, "atominfo");
            if ~isempty(atomInfos), obj.parseAtominfo(atomInfos{1}); end
            kpointNodes = obj.nodes(root, "kpoints");
            if ~isempty(kpointNodes)
                [obj.kpoints, obj.actual_kpoints, ...
                    obj.actual_kpoints_weights] = ...
                    obj.parseKpoints(kpointNodes{1});
            else
                obj.kpoints = kssolv.analysis.matgenlab.io.vasp.Kpoints();
            end
            structureNodes = obj.nodes(root, "structure");
            for index = 1:numel(structureNodes)
                if obj.attr(structureNodes{index}, "name") == "initialpos"
                    obj.initial_structure = ...
                        obj.parseStructure(structureNodes{index});
                    obj.final_structure = obj.initial_structure;
                    break
                end
            end
        end

        function params = parseParams(obj, node)
            values = struct();
            descendants = [obj.nodes(node, "i"), obj.nodes(node, "v")];
            for index = 1:numel(descendants)
                current = descendants{index};
                name = strtrim(obj.attr(current, "name"));
                if strlength(name) == 0, continue; end
                key = matlab.lang.makeValidName(char(upper(name)));
                type = lower(obj.attr(current, "type"));
                raw = strtrim(string(current.getTextContent()));
                try
                    if obj.nodeName(current) == "v"
                        tokens = split(raw);
                        parsed = cell(1, numel(tokens));
                        for tokenIndex = 1:numel(tokens)
                            parsed{tokenIndex} = obj.parseScalar( ...
                                tokens(tokenIndex), type);
                        end
                        if all(cellfun(@isnumeric, parsed))
                            parsed = cell2mat(parsed);
                        elseif all(cellfun(@islogical, parsed))
                            parsed = cell2mat(parsed);
                        else
                            parsed = string(parsed);
                        end
                    else
                        parsed = obj.parseScalar(raw, type);
                    end
                    values.(key) = parsed;
                catch exception
                    if upper(name) == "RANDOM_SEED"
                        values.(key) = [];
                    else
                        rethrow(exception)
                    end
                end
            end
            params = kssolv.analysis.matgenlab.io.vasp.Incar(values);
        end

        function parseAtominfo(obj, node)
            arrays = obj.childNodes(node, "array");
            for index = 1:numel(arrays)
                name = obj.attr(arrays{index}, "name");
                sets = obj.childNodes(arrays{index}, "set");
                if isempty(sets), continue; end
                records = obj.childNodes(sets{1}, "rc");
                if name == "atoms"
                    obj.atomic_symbols = cell(1, numel(records));
                    for record = 1:numel(records)
                        cells = obj.childNodes(records{record}, "c");
                        symbol = strtrim(string(cells{1}.getTextContent()));
                        if symbol == "X", symbol = "Xe";
                        elseif symbol == "r", symbol = "Zr";
                        end
                        obj.atomic_symbols{record} = char(symbol);
                    end
                elseif name == "atomtypes"
                    obj.potcar_symbols = cell(1, numel(records));
                    obj.potcar_spec = cell(1, numel(records));
                    for record = 1:numel(records)
                        cells = obj.childNodes(records{record}, "c");
                        title = strtrim(string(cells{min(5, numel(cells))}. ...
                            getTextContent()));
                        obj.potcar_symbols{record} = char(title);
                        obj.potcar_spec{record} = struct("titel", title, ...
                            "hash", [], "summary_stats", struct());
                    end
                end
            end
        end

        function [kpoints, points, weights] = parseKpoints(obj, node)
            points = []; weights = [];
            generation = obj.childNodes(node, "generation");
            style = "Reciprocal";
            shift = [0, 0, 0];
            divisions = [];
            if ~isempty(generation)
                style = obj.attr(generation{1}, "param");
                vectors = obj.childNodes(generation{1}, "v");
                for index = 1:numel(vectors)
                    name = obj.attr(vectors{index}, "name");
                    value = obj.parseNumbers(vectors{index}.getTextContent());
                    if name == "divisions", divisions = value;
                    elseif name == "usershift", shift = value;
                    end
                end
            end
            arrays = obj.childNodes(node, "varray");
            for index = 1:numel(arrays)
                name = obj.attr(arrays{index}, "name");
                if name == "kpointlist", points = obj.parseVarray(arrays{index});
                elseif name == "weights"
                    weights = reshape(obj.parseVarray(arrays{index}), 1, []);
                end
            end
            if lower(style) == "reciprocal" || ~isempty(points)
                kpoints = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                    comment = "Kpoints from vasprun.xml", ...
                    style = "Reciprocal", num_kpts = size(points, 1), ...
                    kpts = points, kpts_weights = weights);
            else
                if isempty(divisions), divisions = [1, 1, 1]; end
                kpoints = kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                    comment = "Kpoints from vasprun.xml", style = style, ...
                    kpts = divisions, kpts_shift = shift);
            end
        end

        function structure = parseStructure(obj, node)
            crystal = obj.childNodes(node, "crystal");
            lattice = [];
            if ~isempty(crystal)
                arrays = obj.childNodes(crystal{1}, "varray");
                if ~isempty(arrays), lattice = obj.parseVarray(arrays{1}); end
            end
            arrays = obj.childNodes(node, "varray");
            positions = []; selective = [];
            for index = 1:numel(arrays)
                name = obj.attr(arrays{index}, "name");
                if name == "positions", positions = obj.parseVarray(arrays{index});
                elseif name == "selective"
                    selective = obj.parseLogicalVarray(arrays{index});
                end
            end
            properties = struct();
            if ~isempty(selective)
                properties.selective_dynamics = num2cell(selective, 2);
            end
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, obj.atomic_symbols, positions, ...
                site_properties = properties);
        end

        function step = parseIonicStep(obj, node)
            step = struct();
            energies = obj.childNodes(node, "energy");
            if ~isempty(energies)
                step = obj.parseEnergy(energies{end});
            end
            scsteps = obj.childNodes(node, "scstep");
            electronic = cell(1, numel(scsteps));
            for index = 1:numel(scsteps)
                energyNodes = obj.childNodes(scsteps{index}, "energy");
                if isempty(energyNodes), electronic{index} = struct();
                else, electronic{index} = obj.parseEnergy(energyNodes{1});
                end
            end
            step.electronic_steps = electronic;
            structureNodes = obj.childNodes(node, "structure");
            if isempty(structureNodes), step.structure = [];
            else, step.structure = obj.parseStructure(structureNodes{1});
            end
            arrays = obj.childNodes(node, "varray");
            for index = 1:numel(arrays)
                name = matlab.lang.makeValidName(char(obj.attr(arrays{index}, "name")));
                step.(name) = obj.parseVarray(arrays{index});
            end
        end

        function parseFinalDos(obj, root)
            nodes_ = obj.nodes(root, "dos");
            for index = 1:numel(nodes_)
                if obj.attr(nodes_{index}, "comment") == "kpoints_opt", continue; end
                try
                    [obj.tdos, obj.idos, obj.pdos] = obj.parseDos(nodes_{index});
                    obj.efermi = obj.tdos.efermi;
                    obj.dos_has_errors = false;
                catch
                    obj.dos_has_errors = true;
                end
            end
        end

        function parseFermiLevel(obj, root)
            entries = obj.nodes(root, "i");
            for index = 1:numel(entries)
                if obj.attr(entries{index}, "name") ~= "efermi", continue; end
                current = entries{index}.getParentNode();
                isOpt = false;
                while ~isempty(current)
                    if obj.nodeName(current) == "dos" && ...
                            obj.attr(current, "comment") == "kpoints_opt"
                        isOpt = true;
                        break
                    end
                    if obj.nodeName(current) == "modeling", break; end
                    current = current.getParentNode();
                end
                if ~isOpt
                    obj.efermi = obj.parseVaspFloat( ...
                        entries{index}.getTextContent());
                end
            end
        end

        function [tdos, idos, pdos] = parseDos(obj, node)
            entries = obj.nodes(node, "i");
            efermiValue = [];
            for index = 1:numel(entries)
                if obj.attr(entries{index}, "name") == "efermi"
                    efermiValue = str2double(entries{index}.getTextContent());
                    break
                end
            end
            totals = obj.childNodes(node, "total");
            array = obj.childNodes(totals{1}, "array");
            rootSet = obj.childNodes(array{1}, "set");
            spinSets = obj.childNodes(rootSet{1}, "set");
            densities = struct(); integrated = struct(); energies = [];
            soc = numel(spinSets) > 2;
            for index = 1:numel(spinSets)
                spin = obj.spinName(spinSets{index});
                if soc && spin ~= "up", continue; end
                rows = obj.parseRows(spinSets{index});
                energies = rows(:, 1).';
                densities.(spin) = rows(:, 2).';
                integrated.(spin) = rows(:, 3).';
            end
            tdos = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                efermiValue, energies, densities);
            idos = kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                efermiValue, energies, integrated);
            pdos = cell(1, 0);
            partial = obj.childNodes(node, "partial");
            if isempty(partial), return; end
            arrays = obj.childNodes(partial{1}, "array");
            fields = obj.childNodes(arrays{1}, "field");
            orbitalNames = strings(1, max(0, numel(fields) - 1));
            for index = 2:numel(fields)
                orbitalNames(index - 1) = obj.orbitalField( ...
                    string(fields{index}.getTextContent()), index - 1);
            end
            rootSets = obj.childNodes(arrays{1}, "set");
            ionSets = obj.childNodes(rootSets{1}, "set");
            pdos = cell(1, numel(ionSets));
            for ion = 1:numel(ionSets)
                projected = struct();
                spinSets = obj.childNodes(ionSets{ion}, "set");
                for spinIndex = 1:numel(spinSets)
                    spin = obj.spinName(spinSets{spinIndex});
                    if soc && spin ~= "up", continue; end
                    rows = obj.parseRows(spinSets{spinIndex});
                    for orbital = 1:numel(orbitalNames)
                        field = char(orbitalNames(orbital));
                        if ~isfield(projected, field)
                            projected.(field) = struct();
                        end
                        projected.(field).(spin) = rows(:, orbital + 1).';
                    end
                end
                pdos{ion} = projected;
            end
        end

        function parseFinalEigen(obj, root)
            nodes_ = obj.nodes(root, "eigenvalues");
            for index = 1:numel(nodes_)
                parent = nodes_{index}.getParentNode();
                parentName = obj.nodeName(parent);
                if any(parentName == ["projected","eigenvalues_kpoints_opt", ...
                        "projected_kpoints_opt"])
                    continue
                end
                obj.eigenvalues = obj.parseEigen(nodes_{index});
            end
        end

        function eigen = parseEigen(obj, node)
            eigen = struct();
            arrays = obj.childNodes(node, "array");
            if isempty(arrays), return; end
            roots = obj.childNodes(arrays{1}, "set");
            if isempty(roots), return; end
            spinSets = obj.childNodes(roots{1}, "set");
            for index = 1:numel(spinSets)
                spin = obj.spinName(spinSets{index});
                pointSets = obj.childNodes(spinSets{index}, "set");
                data = [];
                for point = 1:numel(pointSets)
                    rows = obj.parseRows(pointSets{point});
                    if isempty(data)
                        data = zeros(numel(pointSets), size(rows, 1), ...
                            size(rows, 2));
                    end
                    data(point, :, :) = rows; %#ok<AGROW>
                end
                eigen.(spin) = data;
            end
        end

        function parseFinalProjected(obj, root)
            nodes_ = obj.nodes(root, "projected");
            for index = 1:numel(nodes_)
                parent = obj.nodeName(nodes_{index}.getParentNode());
                if parent == "projected_kpoints_opt", continue; end
                [obj.projected_eigenvalues, ...
                    obj.projected_magnetization] = ...
                    obj.parseProjected(nodes_{index});
            end
        end

        function [projected, magnetization] = parseProjected(obj, node)
            projected = struct(); magnetization = [];
            arrays = obj.childNodes(node, "array");
            if isempty(arrays), return; end
            roots = obj.childNodes(arrays{1}, "set");
            if isempty(roots), return; end
            spinSets = obj.childNodes(roots{1}, "set");
            raw = cell(1, numel(spinSets));
            for spinIndex = 1:numel(spinSets)
                pointSets = obj.childNodes(spinSets{spinIndex}, "set");
                data = [];
                for point = 1:numel(pointSets)
                    bandSets = obj.childNodes(pointSets{point}, "set");
                    for band = 1:numel(bandSets)
                        rows = obj.parseRows(bandSets{band});
                        if isempty(data)
                            data = zeros(numel(pointSets), ...
                                numel(bandSets), size(rows, 1), size(rows, 2));
                        end
                        data(point, band, :, :) = rows; %#ok<AGROW>
                    end
                end
                raw{spinIndex} = data;
            end
            if numel(raw) > 2
                projected.up = raw{1};
                magnetization = cat(5, raw{2}, raw{3}, raw{4});
            elseif ~isempty(raw)
                projected.up = raw{1};
                if numel(raw) == 2, projected.down = raw{2}; end
            end
        end

        function parseDielectric(obj, root)
            nodes_ = obj.nodes(root, "dielectricfunction");
            unlabelled = 0;
            for index = 1:numel(nodes_)
                label = obj.attr(nodes_{index}, "comment");
                if strlength(label) == 0
                    unlabelled = unlabelled + 1;
                    if upper(string(obj.incar.get("ALGO", ""))) == "BSE"
                        label = "freq_dependent";
                    elseif unlabelled == 1, label = "density";
                    elseif unlabelled == 2, label = "velocity";
                    else, label = "unlabelled";
                    end
                elseif label == "density-density"
                    label = "density";
                elseif label == "current-current"
                    label = "velocity";
                end
                realNodes = obj.childNodes(nodes_{index}, "real");
                imagNodes = obj.childNodes(nodes_{index}, "imag");
                if isempty(realNodes) || isempty(imagNodes), continue; end
                realRows = obj.rowsInArray(realNodes{1});
                imagRows = obj.rowsInArray(imagNodes{1});
                key = matlab.lang.makeValidName(char(label));
                obj.dielectric_data.(key) = {imagRows(:,1).', ...
                    realRows(:,2:end), imagRows(:,2:end)};
            end
        end

        function parseDynamicalMatrix(obj, root)
            nodes_ = obj.nodes(root, "dynmat");
            if isempty(nodes_), return; end
            node = nodes_{end};
            vectors = obj.childNodes(node, "v");
            modeEigenvalues = [];
            for index = 1:numel(vectors)
                if obj.attr(vectors{index}, "name") == "eigenvalues"
                    modeEigenvalues = ...
                        obj.parseNumbers(vectors{index}.getTextContent());
                end
            end
            arrays = obj.childNodes(node, "varray");
            hessian = []; eigenvectors = [];
            for index = 1:numel(arrays)
                name = obj.attr(arrays{index}, "name");
                if name == "hessian", hessian = obj.parseVarray(arrays{index});
                elseif name == "eigenvectors"
                    eigenvectors = obj.parseVarray(arrays{index});
                end
            end
            if ~isempty(hessian)
                atoms = size(hessian, 1) / 3;
                obj.force_constants = permute(reshape(hessian, ...
                    3, atoms, 3, atoms), [2,4,1,3]);
            end
            obj.normalmode_eigenvals = modeEigenvalues;
            if ~isempty(eigenvectors)
                atoms = size(eigenvectors, 2) / 3;
                obj.normalmode_eigenvecs = reshape(eigenvectors, ...
                    size(eigenvectors, 1), atoms, 3);
            end
        end

        function parseMlData(obj, root)
            if ~obj.incar.get("ML_LMLFF", false), return; end
            structureNodes = obj.nodes(root, "structure");
            for structureIndex = 1:numel(structureNodes)
                if strlength(obj.attr( ...
                        structureNodes{structureIndex}, "name")) > 0
                    continue
                end
                step = struct("structure", ...
                    obj.parseStructure(structureNodes{structureIndex}));
                sibling = structureNodes{structureIndex}.getNextSibling();
                while ~isempty(sibling)
                    name = obj.nodeName(sibling);
                    if name == "structure", break; end
                    if name == "varray"
                        field = matlab.lang.makeValidName( ...
                            char(obj.attr(sibling, "name")));
                        step.(field) = obj.parseVarray(sibling);
                    elseif name == "energy"
                        energy = obj.parseEnergy(sibling);
                        if isfield(energy, "kinetic"), step.energy = energy; end
                    end
                    sibling = sibling.getNextSibling();
                end
                if isfield(step, "forces") && isfield(step, "energy")
                    obj.md_data{end + 1} = step;
                end
            end
        end

        function parseKpointsOpt(obj, root, parseDos, parseEigen, parseProjected)
            optEigen = obj.nodes(root, "eigenvalues_kpoints_opt");
            optProjected = obj.nodes(root, "projected_kpoints_opt");
            optDos = obj.nodes(root, "dos");
            hasOptDos = false;
            for index = 1:numel(optDos)
                hasOptDos = hasOptDos || ...
                    obj.attr(optDos{index}, "comment") == "kpoints_opt";
            end
            if isempty(optEigen) && isempty(optProjected) && ~hasOptDos, return; end
            props = kssolv.analysis.matgenlab.io.vasp.KpointOptProps();
            if ~isempty(optEigen)
                kp = obj.childNodes(optEigen{end}, "kpoints");
                if ~isempty(kp)
                    [props.kpoints, props.actual_kpoints, ...
                        props.actual_kpoints_weights] = obj.parseKpoints(kp{1});
                end
                ev = obj.childNodes(optEigen{end}, "eigenvalues");
                if parseEigen && ~isempty(ev), props.eigenvalues = obj.parseEigen(ev{1}); end
            end
            if ~isempty(optProjected)
                ev = obj.childNodes(optProjected{end}, "eigenvalues");
                if parseEigen && ~isempty(ev), props.eigenvalues = obj.parseEigen(ev{1}); end
                if parseProjected
                    [props.projected_eigenvalues, ...
                        props.projected_magnetization] = ...
                        obj.parseProjected(optProjected{end});
                end
            end
            if parseDos
                for index = 1:numel(optDos)
                    if obj.attr(optDos{index}, "comment") ~= "kpoints_opt", continue; end
                    try
                        [props.tdos, props.idos, props.pdos] = ...
                            obj.parseDos(optDos{index});
                        props.efermi = props.tdos.efermi;
                        props.dos_has_errors = false;
                    catch
                        props.dos_has_errors = true;
                    end
                end
            end
            obj.kpoints_opt_props = props;
        end
    end

    methods (Access = private)
        function value = lastStepField(obj, name, default)
            if isempty(obj.ionic_steps), value = default; return; end
            step = obj.ionic_steps{end};
            if isfield(step, name), value = step.(name);
            else, value = default;
            end
        end

        function energy = parseEnergy(obj, node)
            energy = struct();
            entries = obj.childNodes(node, "i");
            for index = 1:numel(entries)
                key = matlab.lang.makeValidName(char(obj.attr(entries{index}, "name")));
                energy.(key) = obj.parseVaspFloat(entries{index}.getTextContent());
            end
        end

        function value = parseVarray(obj, node)
            rows = [obj.childNodes(node, "v"), obj.childNodes(node, "r")];
            value = obj.numericRows(rows);
        end

        function value = parseLogicalVarray(obj, node)
            rows = obj.childNodes(node, "v");
            value = false(numel(rows), 0);
            for index = 1:numel(rows)
                tokens = split(strtrim(string(rows{index}.getTextContent())));
                if index == 1, value = false(numel(rows), numel(tokens)); end
                value(index, :) = upper(tokens) == "T" | upper(tokens) == ".TRUE.";
            end
        end

        function value = parseRows(obj, setNode)
            rows = [obj.childNodes(setNode, "r"), ...
                obj.childNodes(setNode, "v")];
            value = obj.numericRows(rows);
        end

        function value = rowsInArray(obj, node)
            arrays = obj.childNodes(node, "array");
            sets = obj.childNodes(arrays{1}, "set");
            value = obj.parseRows(sets{1});
        end

        function value = numericRows(obj, rows)
            value = [];
            for index = 1:numel(rows)
                row = obj.parseNumbers(rows{index}.getTextContent());
                if isempty(value), value = zeros(numel(rows), numel(row)); end
                value(index, :) = row; %#ok<AGROW>
            end
        end

        function value = parseNumbers(obj, text)
            tokens = split(strtrim(string(text)));
            tokens(tokens == "") = [];
            value = zeros(1, numel(tokens));
            for index = 1:numel(tokens)
                value(index) = obj.parseVaspFloat(tokens(index));
            end
        end

        function value = parseVaspFloat(~, text)
            token = strtrim(string(text));
            value = str2double(replace(token, ["D","d"], ["E","e"]));
            if isnan(value) && contains(token, "*")
                value = NaN;
            end
        end

        function value = parseScalar(obj, raw, type)
            type = lower(string(type));
            if any(type == ["logical","bool","boolean"])
                value = any(upper(raw) == ["T",".TRUE.","TRUE"]);
            elseif any(type == ["int","integer"])
                value = str2double(raw);
            elseif any(type == ["string","char"])
                value = char(strtrim(raw));
            else
                value = obj.parseVaspFloat(raw);
                if isnan(value) && strlength(raw) > 0, value = char(raw); end
            end
        end

        function name = spinName(obj, node)
            comment = lower(obj.attr(node, "comment"));
            if contains(comment, "spin 1") || contains(comment, "spin1")
                name = "up";
            else
                name = "down";
            end
        end

        function field = orbitalField(~, source, index)
            source = lower(strtrim(string(source)));
            source = replace(source, ["x2-y2","x^2-y^2","dx2-y2"], "dx2");
            source = replace(source, ["z2-r2","z^2-r^2","dz2-r2"], "dz2");
            field = string(matlab.lang.makeValidName(char(source)));
            if strlength(field) == 0 || startsWith(field, "x")
                names = ["s","py","pz","px","dxy","dyz","dz2", ...
                    "dxz","dx2","f_3","f_2","f_1","f0","f1","f2","f3"];
                field = names(min(index, numel(names)));
            end
        end

        function value = defaultKpointsFilename(obj)
            directory = fileparts(obj.filename);
            candidates = string(fullfile(directory, ...
                ["KPOINTS_OPT","KPOINTS","KPOINTS.gz","KPOINTS.bz2"]));
            found = find(arrayfun(@isfile, candidates), 1);
            if isempty(found), value = []; else, value = candidates(found); end
        end

        function names = potcarElementNames(obj)
            names = cell(1, numel(obj.potcar_symbols));
            for index = 1:numel(names)
                tokens = split(string(obj.potcar_symbols{index}));
                names{index} = char(tokens(min(2, numel(tokens))));
            end
        end
    end

    methods (Static, Access = private)
        function options = parseOptions(defaults, arguments_)
            options = defaults;
            names = fieldnames(defaults);
            positional = 1; index = 1;
            while index <= numel(arguments_)
                current = arguments_{index};
                if (ischar(current) || (isstring(current) && isscalar(current))) ...
                        && any(strcmpi(string(current), string(names)))
                    match = find(strcmpi(string(current), string(names)), 1);
                    if index == numel(arguments_)
                        error("KSSOLV:Matgenlab:Vasprun:Arguments", ...
                            "Name-value arguments must occur in pairs.");
                    end
                    options.(names{match}) = arguments_{index + 1};
                    index = index + 2;
                else
                    if positional > numel(names)
                        error("KSSOLV:Matgenlab:Vasprun:Arguments", ...
                            "Too many positional arguments.");
                    end
                    options.(names{positional}) = current;
                    positional = positional + 1;
                    index = index + 1;
                end
            end
        end

        function nodes_ = nodes(node, tag)
            list = node.getElementsByTagName(char(tag));
            nodes_ = cell(1, list.getLength());
            for index = 1:numel(nodes_), nodes_{index} = list.item(index - 1); end
        end

        function nodes_ = childNodes(node, tag)
            list = node.getChildNodes();
            nodes_ = cell(1, 0);
            for index = 0:list.getLength() - 1
                current = list.item(index);
                if string(current.getNodeName()) == string(tag)
                    nodes_{end + 1} = current; %#ok<AGROW>
                end
            end
        end

        function value = attr(node, name)
            value = string(node.getAttribute(char(name)));
        end

        function value = nodeName(node)
            value = string(node.getNodeName());
        end

        function value = nearly(first, second)
            value = isfinite(first) && abs(first - second) <= ...
                1e-9 * max([1, abs(first), abs(second)]);
        end

        function value = crossesBand(bands, fermi)
            value = any(any(bands < fermi, 2) & any(bands > fermi, 2));
        end

        function digest = structureDigest(structure)
            bytes = uint8(char(jsonencode(structure.as_dict())));
            engine = java.security.MessageDigest.getInstance("MD5");
            engine.update(bytes);
            digest = lower(reshape(dec2hex(typecast(engine.digest(), ...
                "uint8"), 2).', 1, []));
        end
    end
end
