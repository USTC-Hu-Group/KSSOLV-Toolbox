classdef QCOutput < kssolv.analysis.matgenlab.util.MSONable
    %#ok<*AGROW>
    %QCOUTPUT Native parser for Q-Chem text, gzip, and multi-job outputs.
    properties
        filename = ""
        data = struct()
        text = ""
    end
    methods
        function obj = QCOutput(filename)
            if nargin == 0, return; end
            obj.filename = string(filename);
            obj.text = string(kssolv.analysis.matgenlab.io.qchem.read_text(filename));
            if ~isempty(regexp(obj.text, "Job\s+\d+\s+of\s+([2-9]\d*)", "once"))
                error("KSSOLV:Matgenlab:QChem:MultipleOutputs", ...
                    "Multiple calculations found; use multiple_outputs_from_file.");
            end
            obj.data = obj.parse();
        end

        function value = as_dict(obj)
            value = struct("data", obj.data, "text", char(obj.text), ...
                "filename", char(obj.filename));
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Static)
        function outputs = multiple_outputs_from_file(filename, keepSubFiles)
            if nargin < 2, keepSubFiles = true; end
            text = kssolv.analysis.matgenlab.io.qchem.read_text(filename);
            pieces = regexp(text, "\s*(?:Running\s+)*Job\s+\d+\s+of\s+\d+\s+", "split");
            if ~isempty(pieces) && isempty(strtrim(pieces{1})), pieces(1) = []; end
            outputs = cell(1, numel(pieces));
            for index = 1:numel(pieces)
                subfile = sprintf("%s.%d", filename, index - 1);
                fid = fopen(subfile, "w", "n", "UTF-8");
                if fid < 0, error("KSSOLV:Matgenlab:QChem:Write", "Cannot write sub-output."); end
                cleanup = onCleanup(@() fclose(fid));
                fwrite(fid, pieces{index}, "char");
                clear cleanup
                outputs{index} = kssolv.analysis.matgenlab.io.qchem.QCOutput(subfile);
                if ~keepSubFiles, delete(subfile); end
            end
        end
    end

    methods (Access = private)
        function data = parse(obj)
            source = char(obj.text);
            sourceLines = splitlines(obj.text);
            data = struct("errors", {{}}, "warnings", struct(), ...
                "multiple_outputs", [], "completion", ...
                contains(source, "Thank you very much for using Q-Chem"), ...
                "version", "unknown");
            version = regexp(source, "A Quantum Leap Into The Future Of Chemistry\s+Q-Chem\s+([456])", ...
                "tokens", "once");
            if ~isempty(version), data.version = version{1}; end
            multiple = regexp(source, "Job\s+\d+\s+of\s+(\d+)", "tokens", "once");
            if ~isempty(multiple), data.multiple_outputs = multiple; end
            [data.charge, data.multiplicity] = obj.charge_spin(source);
            [species, geometries] = obj.geometries(sourceLines);
            data.species = species;
            data.geometries = geometries;
            data.initial_geometry = []; data.initial_molecule = [];
            data.last_geometry = []; data.molecule_from_last_geometry = [];
            if ~isempty(geometries)
                data.initial_geometry = geometries{1};
                data.last_geometry = geometries{end};
                if ~isempty(data.charge)
                    data.initial_molecule = obj.make_molecule(species, geometries{1}, ...
                        data.charge, data.multiplicity);
                    data.molecule_from_last_geometry = obj.make_molecule(species, ...
                        geometries{end}, data.charge, data.multiplicity);
                end
            end
            pointGroup = regexp(source, "Molecular Point Group\s+([A-Za-z\d*]+)", ...
                "tokens", "once");
            if isempty(pointGroup), data.point_group = [];
            else, data.point_group = pointGroup{1}; end
            data.unrestricted = ~isempty(regexpi(source, ...
                "(?:an?\s+unrestricted|unrestricted\s*=\s*true)", "once")) || ...
                data.multiplicity ~= 1;
            data.using_GEN_SCFMAN = contains(source, "GEN_SCFMAN") || ...
                contains(source, "General SCF calculation program by");
            data.scf_final_print = obj.first_number(source, ...
                "scf_final_print\s*=\s*(\d+)", 0);
            data.completion = logical(data.completion);
            timing = regexp(source, ...
                "Total job time:\s*([-+\d.]+)s\(wall\),\s*([-+\d.]+)s\(cpu\)", ...
                "tokens", "once");
            if isempty(timing), data.walltime = []; data.cputime = [];
            else
                data.walltime = str2double(timing{1});
                data.cputime = str2double(timing{2});
            end
            data.final_energy = obj.last_number(source, ...
                "(?:Final\s+energy\s+is|Total\s+energy in the final basis set\s*=|Total energy\s*=)\s*([-+\d.]+)");
            data.SCF_energy_in_the_final_basis_set = obj.all_numbers(source, ...
                "SCF\s+energy(?: in the final basis set)?\s*=\s*([-+\d.]+)");
            data.Total_energy_in_the_final_basis_set = obj.all_numbers(source, ...
                "Total energy(?: in the final basis set)?\s*=\s*([-+\d.]+)");
            data.SCF = obj.scf_cycles(source);
            if contains(source, "SCF failed to converge")
                data.errors{end + 1} = "SCF_failed_to_converge";
            end
            data.optimization = ~isempty(regexpi(source, ...
                "job(?:_)?type\s*=?\s*(?:opt|optimization)", "once"));
            data.transition_state = ~isempty(regexpi(source, ...
                "job(?:_)?type\s*=?\s*ts", "once"));
            data.frequency_job = ~isempty(regexpi(source, ...
                "job(?:_)?type\s*=?\s*(?:freq|frequency)", "once"));
            data.force_job = ~isempty(regexpi(source, ...
                "job(?:_)?type\s*=?\s*force", "once"));
            data.single_point_job = ~isempty(regexpi(source, ...
                "job(?:_)?type\s*=?\s*sp", "once"));
            data.scan_job = ~isempty(regexpi(source, ...
                "job(?:_)?type\s*=?\s*pes_scan", "once"));
            data.energy_trajectory = obj.all_numbers(source, ...
                "(?:\sEnergy\s+is|\sStep\s*\d+\s*:\s*Energy)\s*([-+\d.]+)");
            data.optimized_geometry = [];
            data.molecule_from_optimized_geometry = [];
            data.optimized_geometries = {};
            data.molecules_from_optimized_geometries = {};
            if (data.optimization || data.transition_state) && ~isempty(geometries)
                data.optimized_geometry = geometries{end};
                data.molecule_from_optimized_geometry = data.molecule_from_last_geometry;
                data.optimized_geometries = geometries(2:end);
                if ~isempty(data.initial_molecule)
                    data.molecules_from_optimized_geometries = cellfun(@(geometry) ...
                        obj.make_molecule(species, geometry, data.charge, data.multiplicity), ...
                        geometries(2:end), "UniformOutput", false);
                end
            end
            data.norm_of_stepsize = obj.all_numbers(source, ...
                "Norm of Stepsize\s*([-+\d.]+)");
            data.gradients = obj.gradient_blocks(sourceLines, "Gradient of SCF Energy");
            data.pcm_gradients = obj.gradient_blocks(sourceLines, ...
                "total gradient after adding PCM contribution");
            data.CDS_gradients = obj.gradient_blocks(sourceLines, "Gradient of CDS energy");
            data = obj.parse_frequency(source, data);
            data = obj.parse_scan(source, data);
            data = obj.parse_solvent(source, data);
            data = obj.parse_energies(source, data);
            data = obj.parse_gap(source, data);
            s2 = obj.all_numbers(source, "<S\^2>\s*=\s*([-+\d.]+)");
            if isempty(s2), data.S2 = []; else, data.S2 = s2; end
            data.nbo_data = [];
            if contains(source, "N A T U R A L   A T O M I C   O R B I T A L")
                data.nbo_data = kssolv.analysis.matgenlab.io.qchem.nbo_parser(obj.filename);
            end
            data.cdft_becke_excess_electrons = obj.all_numbers(source, ...
                "Excess Electrons\s*[:=]\s*([-+\d.]+)");
            data.direct_coupling_eV = obj.last_number(source, ...
                "(?:Direct coupling|Coupling)\s*(?:\(eV\))?\s*[:=]\s*([-+\d.Ee]+)");
            data.almo_coupling_eV = obj.last_number(source, ...
                "ALMO.*?coupling.*?([-+\d.]+)\s*eV");
            data.pod_coupling_eV = obj.last_number(source, ...
                "POD.*?coupling.*?([-+\d.]+)\s*eV");
            data.fodft_coupling_eV = obj.last_number(source, ...
                "FODFT.*?coupling.*?([-+\d.]+)\s*eV");
            data.mem_total = obj.first_number(source, "mem_total\s*=\s*(\d+)", []);
            if ~data.completion && isempty(data.errors)
                data.errors{end + 1} = "unknown_error";
            end
        end

        function [charge, spin] = charge_spin(~, source)
            token = regexp(source, "\$molecule\s+(-?\d+)\s+(\d+)", "tokens", "once");
            if isempty(token)
                charge = []; spin = 1;
                chargeToken = regexp(source, ...
                    "Sum of atomic charges\s*=\s*([-+\d.]+)", "tokens", "once");
                if ~isempty(chargeToken), charge = round(str2double(chargeToken{1})); end
                spinToken = regexp(source, ...
                    "Sum of spin\s+charges\s*=\s*([-+\d.]+)", "tokens", "once");
                if ~isempty(spinToken), spin = round(str2double(spinToken{1})) + 1; end
            else
                charge = str2double(token{1}); spin = str2double(token{2});
            end
        end

        function [species, geometries] = geometries(~, lines)
            starts = find(contains(lines, "Standard Nuclear Orientation (Angstroms)"));
            species = {}; geometries = {};
            for blockIndex = 1:numel(starts)
                cursor = starts(blockIndex) + 3;
                currentSpecies = {}; geometry = zeros(0, 3);
                while cursor <= numel(lines)
                    token = regexp(lines(cursor), ...
                        "^\s*\d+\s+([A-Za-z]+)\s+([-+\d.*]+)\s+([-+\d.*]+)\s+([-+\d.*]+)", ...
                        "tokens", "once");
                    if isempty(token), break; end
                    currentSpecies{end + 1} = token{1};
                    row = numel(currentSpecies);
                    geometry(row, 1:3) = 0;
                    for column = 1:3
                        if contains(token{column + 1}, "*"), geometry(row, column) = 1e10;
                        else, geometry(row, column) = str2double(token{column + 1}); end
                    end
                    cursor = cursor + 1;
                end
                if isempty(currentSpecies), continue; end
                if isempty(species), species = currentSpecies; end
                if isequal(currentSpecies, species), geometries{end + 1} = geometry; end
            end
        end

        function molecule = make_molecule(~, species, geometry, charge, spin)
            try
                molecule = kssolv.analysis.matgenlab.core.Molecule(species, geometry, ...
                    charge = charge, spin_multiplicity = spin);
            catch
                molecule = [];
            end
        end

        function values = scf_cycles(~, source)
            rows = regexp(source, ...
                "(?m)^\s*\d+\s+([-+\d.]+)\s+([-+\d.]+)[Ee]([-+\d.]+)", "tokens");
            table = zeros(numel(rows), 2);
            for row = 1:numel(rows)
                table(row, :) = [str2double(rows{row}{1}), ...
                    str2double(rows{row}{2}) * 10 ^ str2double(rows{row}{3})];
            end
            if isempty(table), values = {}; else, values = {table}; end
        end

        function blocks = gradient_blocks(~, lines, header)
            starts = find(contains(lower(lines), lower(string(header))));
            blocks = {};
            for startIndex = reshape(starts, 1, [])
                if contains(lower(string(header)), "scf energy")
                    cursor = startIndex + 1; matrix = zeros(0, 3);
                    while cursor + 3 <= numel(lines) && ...
                            ~contains(lines(cursor), "Max gradient")
                        atomIds = sscanf(lines(cursor), "%d").';
                        if isempty(atomIds), cursor = cursor + 1; continue; end
                        chunk = zeros(3, numel(atomIds));
                        valid = true;
                        for axis = 1:3
                            rowValues = sscanf(lines(cursor + axis), "%f").';
                            if numel(rowValues) < numel(atomIds) + 1
                                valid = false; break
                            end
                            chunk(axis, :) = rowValues(2:numel(atomIds) + 1);
                        end
                        if valid
                            matrix(atomIds, :) = chunk.';
                            cursor = cursor + 4;
                        else
                            cursor = cursor + 1;
                        end
                    end
                else
                    cursor = startIndex + 1; matrix = zeros(0, 3);
                    while cursor <= min(numel(lines), startIndex + 200)
                        token = regexp(lines(cursor), ...
                            "^\s*(\d+)\s+([-+\d.Ee]+)\s+([-+\d.Ee]+)\s+([-+\d.Ee]+)", ...
                            "tokens", "once");
                        if ~isempty(token)
                            atom = str2double(token{1});
                            matrix(atom, :) = str2double(token(2:4));
                        elseif ~isempty(matrix)
                            break
                        end
                        cursor = cursor + 1;
                    end
                end
                if ~isempty(matrix)
                    blocks{end + 1} = matrix;
                end
            end
        end

        function data = parse_frequency(obj, source, data)
            if ~contains(source, "Frequency:")
                emptyFields = {"frequencies", "IR_intens", "IR_active", ...
                    "raman_intens", "raman_active", "depolar", "trans_dip", ...
                    "frequency_mode_vectors", "ZPE", "trans_enthalpy", ...
                    "rot_enthalpy", "vib_enthalpy", "gas_constant", ...
                    "trans_entropy", "rot_entropy", "vib_entropy", ...
                    "total_enthalpy", "total_entropy"};
                for fieldIndex = 1:numel(emptyFields)
                    data.(emptyFields{fieldIndex}) = [];
                end
                data.cpscf_nseg = 0;
                return
            end
            data.frequencies = obj.labeled_values(source, "Frequency:");
            data.IR_intens = obj.labeled_values(source, "IR Intens:");
            data.IR_active = obj.labeled_strings(source, "IR Active:");
            data.raman_intens = obj.labeled_values(source, "Raman Intens:");
            data.raman_active = obj.labeled_strings(source, "Raman Active:");
            data.depolar = obj.labeled_values(source, "Depolar:");
            data.trans_dip = obj.labeled_values(source, "TransDip");
            data.frequency_mode_vectors = [];
            names = {"ZPE", "trans_enthalpy", "rot_enthalpy", "vib_enthalpy", ...
                "gas_constant", "trans_entropy", "rot_entropy", "vib_entropy", ...
                "total_enthalpy", "total_entropy"};
            patterns = {"Zero point vibrational energy:", "Translational Enthalpy:", ...
                "Rotational Enthalpy:", "Vibrational Enthalpy:", "gas constant \(RT\):", ...
                "Translational Entropy:", "Rotational Entropy:", ...
                "Vibrational Entropy:", "Total Enthalpy:", "Total Entropy:"};
            for index = 1:numel(names)
                data.(names{index}) = obj.first_number(source, ...
                    [patterns{index} '\s+([-+\d.]+)'], []);
            end
            data.cpscf_nseg = obj.first_number(source, ...
                "CPSCF will be done in\s*(\d+)\s*segments", 0);
        end

        function data = parse_scan(~, source, data)
            data.scan_energies = {};
            lines = splitlines(string(source));
            summaries = find(contains(lines, "Summary of potential scan:"));
            if ~isempty(summaries)
                cursor = summaries(end) + 1;
                while cursor <= numel(lines) && ~startsWith(strip(lines(cursor)), "-")
                    values = sscanf(lines(cursor), "%f").';
                    if numel(values) == 2
                        data.scan_energies{end + 1} = ...
                            struct("params", values(1), "energy", values(2));
                    elseif numel(values) == 3
                        data.scan_energies{end + 1} = ...
                            struct("params", values(1:2), "energy", values(3));
                    end
                    cursor = cursor + 1;
                end
            end
            data.scan_variables = struct("stre", {{}}, "bend", {{}}, "tors", {{}});
            scan = regexp(source, "(?ms)\$scan\s*(.*?)\$end", "tokens", "once", ...
                "ignorecase");
            if ~isempty(scan)
                rows = regexp(scan{1}, ...
                    "(?mi)^\s*(stre|bend|tors)\s+((?:\d+\s+)+)([-+\d.]+)\s+([-+\d.]+)\s+([-+\d.]+)", ...
                    "tokens");
                for index = 1:numel(rows)
                    key = lower(rows{index}{1});
                    atoms = sscanf(rows{index}{2}, "%d").';
                    data.scan_variables.(key){end + 1} = struct("atoms", atoms, ...
                        "start", str2double(rows{index}{3}), ...
                        "end", str2double(rows{index}{4}), ...
                        "increment", str2double(rows{index}{5}));
                end
            end
            data.scan_constraint_sets = struct("stre", {{}}, "bend", {{}}, "tors", {{}});
        end

        function data = parse_solvent(obj, source, data)
            data.solvent_method = [];
            if ~isempty(regexpi(source, "solvent_method\s*=?\s*pcm", "once"))
                data.solvent_method = "PCM";
            elseif ~isempty(regexpi(source, "solvent_method\s*=?\s*smd", "once"))
                data.solvent_method = "SMD";
            elseif ~isempty(regexpi(source, "solvent_method\s*=?\s*isosvp", "once"))
                data.solvent_method = "ISOSVP";
            end
            data.solvent_data = [];
            if isempty(data.solvent_method), return; end
            iso = struct("isosvp_dielectric", obj.first_number(source, ...
                "DIELST=\s*([-+\d.]+)", []), ...
                "final_soln_phase_e", obj.first_number(source, ...
                "The Final Solution-Phase Energy\s*=\s*([-+\d.]+)", []), ...
                "solute_internal_e", obj.first_number(source, ...
                "The Solute Internal Energy\s*=\s*([-+\d.]+)", []), ...
                "total_solvation_free_e", obj.first_number(source, ...
                "The Total Solvation Free Energy\s*=\s*([-+\d.]+)", []), ...
                "change_solute_internal_e", obj.first_number(source, ...
                "The Change in Solute Internal Energy\s*=\s*([-+\d.]+)", []), ...
                "reaction_field_free_e", obj.first_number(source, ...
                "The Reaction Field Free Energy\s*=\s*([-+\d.]+)", []));
            cmirs = struct("CMIRS_enabled", ...
                contains(source, "DEFESR calculation with single-center isodensity surface"), ...
                "dispersion_e", obj.first_number(source, ...
                "The Dispersion Energy\s*=\s*([-+\d.]+)", []), ...
                "exchange_e", obj.first_number(source, ...
                "The Exchange Energy\s*=\s*([-+\d.]+)", []), ...
                "min_neg_field_e", obj.first_number(source, ...
                "Min. Negative Field Energy\s*=\s*([-+\d.]+)", []), ...
                "max_pos_field_e", obj.first_number(source, ...
                "Max. Positive Field Energy\s*=\s*([-+\d.]+)", []));
            data.solvent_data = struct("PCM_dielectric", obj.first_number(source, ...
                "dielectric\s+([-+\d.]+)", []), ...
                "g_electrostatic", obj.first_number(source, "G_electrostatic\s+=\s+([-+\d.]+)", []), ...
                "g_cavitation", obj.first_number(source, "G_cavitation\s+=\s+([-+\d.]+)", []), ...
                "g_dispersion", obj.first_number(source, "G_dispersion\s+=\s+([-+\d.]+)", []), ...
                "g_repulsion", obj.first_number(source, "G_repulsion\s+=\s+([-+\d.]+)", []), ...
                "total_contribution_pcm", [], "SMD_solvent", [], ...
                "smd0", obj.first_number(source, "E-EN\\(g\\).*?([-+\\d.]+) a\\.u\\.", []), ...
                "smd3", obj.first_number(source, "G-ENP\\(liq\\).*?([-+\\d.]+) a\\.u\\.", []), ...
                "smd4", obj.first_number(source, "G-CDS\\(liq\\).*?([-+\\d.]+) kcal", []), ...
                "smd6", obj.first_number(source, "G-S\\(liq\\).*?([-+\\d.]+) a\\.u\\.", []), ...
                "smd9", obj.first_number(source, "DeltaG-S\\(liq\\).*?([-+\\d.]+) kcal", []), ...
                "isosvp", iso, "cmirs", cmirs);
            solvent = regexp(source, "\s[Ss]olvent:?\s+([A-Za-z]+)", "tokens", "once");
            if ~isempty(solvent), data.solvent_data.SMD_solvent = solvent{1}; end
        end

        function data = parse_energies(obj, source, data)
            data.hf_scf_energy = obj.last_number(source, ...
                "(?:HF|SCF) energy\s*=\s*([-+\d.]+)");
            data.mp2_energy = obj.last_number(source, ...
                "(?:MP2 total energy|MP2 energy)\s*=\s*([-+\d.]+)");
            data.ccsd_correlation_energy = obj.last_number(source, ...
                "CCSD correlation energy\s*=\s*([-+\d.]+)");
            data.ccsd_total_energy = obj.last_number(source, ...
                "CCSD total energy\s*=\s*([-+\d.]+)");
            data.using_dft_d3 = ~isempty(regexpi(source, "dft_d\s*=\s*d3", "once"));
            data.dft_d3 = obj.last_number(source, ...
                "-D3 energy without 3body term\s*=\s*([-+\d.]+)");
        end

        function data = parse_gap(obj, source, data)
            if ~contains(source, "Generalized Kohn-Sham gap")
                data.gap_info = [];
                return
            end
            data.gap_info = struct("HOMO", obj.first_number(source, ...
                "HOMO Eigenvalue\s*=\s*([-+\d.]+)", []), ...
                "LUMO", obj.first_number(source, "LUMO Eigenvalue\s*=\s*([-+\d.]+)", []), ...
                "KSgap", obj.first_number(source, "KS gap\s*=\s*([-+\d.]+)", []));
        end

        function value = first_number(~, source, pattern, fallback)
            token = regexp(source, pattern, "tokens", "once");
            if isempty(token), value = fallback; else, value = str2double(token{1}); end
        end
        function value = last_number(obj, source, pattern)
            values = obj.all_numbers(source, pattern);
            if isempty(values), value = []; else, value = values(end); end
        end
        function values = all_numbers(~, source, pattern)
            tokens = regexp(source, pattern, "tokens");
            values = cellfun(@(token) str2double(replace(string(token{1}), ...
                ["D", "d"], ["E", "e"])), tokens);
        end
        function values = labeled_values(~, source, label)
            pattern = ['(?m)^.*' regexptranslate('escape', char(label)) ...
                '\s*(.*?)\s*$'];
            lines = regexp(source, pattern, "tokens");
            values = [];
            for index = 1:numel(lines)
                tokens = regexp(lines{index}{1}, "[-+]?(?:\d+\.?\d*|\.\d+|\*+)", "match");
                current = zeros(1, numel(tokens));
                for tokenIndex = 1:numel(tokens)
                    if contains(tokens{tokenIndex}, "*"), current(tokenIndex) = Inf;
                    else, current(tokenIndex) = str2double(tokens{tokenIndex}); end
                end
                values = [values, current];
            end
        end
        function values = labeled_strings(~, source, label)
            pattern = ['(?m)^.*' regexptranslate('escape', char(label)) ...
                '\s*(.*?)\s*$'];
            lines = regexp(source, pattern, "tokens");
            values = {};
            for index = 1:numel(lines)
                tokens = regexp(lines{index}{1}, "\b(?:YES|NO)\b", "match");
                values = [values, tokens];
            end
        end
    end
end
