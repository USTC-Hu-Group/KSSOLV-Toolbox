classdef QCInput < kssolv.analysis.matgenlab.util.MSONable
    %#ok<*AGROW,*ISCL,*ALIGN>
    %QCINPUT Native MATLAB representation of a Q-Chem input job.
    properties
        molecule
        rem
        opt = []
        pcm = []
        solvent = []
        smx = []
        scan = []
        van_der_waals = []
        vdw_mode = "atomic"
        plots = []
        nbo = []
        geom_opt = []
        cdft = []
        almo_coupling = []
        svp = []
        pcm_nonels = []
    end

    methods
        function obj = QCInput(molecule, rem, varargin)
            if nargin == 0, return; end
            obj.molecule = molecule;
            obj.rem = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(rem);
            names = ["opt", "pcm", "solvent", "smx", "scan", ...
                "van_der_waals", "vdw_mode", "plots", "nbo", "geom_opt", ...
                "cdft", "almo_coupling", "svp", "pcm_nonels"];
            position = 1;
            while position <= numel(varargin)
                keyMatches = false(size(names));
                if ischar(varargin{position}) || isstring(varargin{position})
                    keyMatches = strcmpi(string(varargin{position}), names);
                end
                if position < numel(varargin) && any(keyMatches)
                    name = char(names(find(keyMatches, 1)));
                    value = varargin{position + 1};
                    position = position + 2;
                else
                    name = char(names(position));
                    value = varargin{position};
                    position = position + 1;
                end
                if any(string(name) == ["opt", "cdft", "almo_coupling", "vdw_mode"])
                    obj.(name) = value;
                else
                    obj.(name) = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(value);
                end
            end
            required = {"basis", "job_type"};
            for index = 1:numel(required)
                if ~isfield(obj.rem, required{index})
                    error("KSSOLV:Matgenlab:QChem:REM", ...
                        "The rem dictionary must contain a '%s' entry.", required{index});
                end
            end
            if ~isfield(obj.rem, "method") && ~isfield(obj.rem, "exchange")
                error("KSSOLV:Matgenlab:QChem:REM", ...
                    "The rem dictionary must contain either a 'method' or 'exchange' entry.");
            end
            valid = ["opt", "optimization", "sp", "freq", "frequency", ...
                "force", "nmr", "ts", "pes_scan"];
            if ~any(lower(string(obj.rem.job_type)) == valid)
                error("KSSOLV:Matgenlab:QChem:REM", ...
                    "The rem dictionary must contain a valid 'job_type' entry.");
            end
        end

        function text = get_str(obj)
            parts = {obj.molecule_template(obj.molecule), obj.rem_template(obj.rem)};
            sections = {"opt", "pcm", "solvent", "smx", "scan", ...
                "van_der_waals", "plots", "nbo", "geom_opt", "cdft", ...
                "almo_coupling", "svp", "pcm_nonels"};
            methods = {"opt_template", "pcm_template", "solvent_template", ...
                "smx_template", "scan_template", "van_der_waals_template", ...
                "plots_template", "nbo_template", "geom_opt_template", ...
                "cdft_template", "almo_template", "svp_template", ...
                "pcm_nonels_template"};
            for index = 1:numel(sections)
                value = obj.(sections{index});
                include = ~isempty(value);
                if any(string(sections{index}) == ["nbo", "geom_opt", "cdft", "almo_coupling"])
                    include = ~isequal(value, []);
                end
                if include
                    if sections{index} == "van_der_waals"
                        parts{end + 1} = obj.van_der_waals_template(value, obj.vdw_mode);
                    else
                        parts{end + 1} = obj.(methods{index})(value);
                    end
                end
            end
            text = char(strjoin(string(parts), sprintf("\n\n")));
        end

        function text = char(obj), text = obj.get_str(); end
        function text = string(obj), text = string(obj.get_str()); end

        function write_file(obj, filename)
            fid = fopen(filename, "w", "n", "UTF-8");
            if fid < 0
                error("KSSOLV:Matgenlab:QChem:Write", "Cannot write '%s'.", filename);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, obj.get_str(), "char");
            clear cleanup
        end

        function value = as_dict(obj)
            moleculeValue = obj.molecule;
            if iscell(moleculeValue)
                moleculeValue = cellfun(@(item) item.as_dict(), moleculeValue, ...
                    "UniformOutput", false);
            elseif isobject(moleculeValue) && ismethod(moleculeValue, "as_dict")
                moleculeValue = moleculeValue.as_dict();
            end
            properties = struct("molecule", moleculeValue, "rem", obj.rem, ...
                "opt", obj.opt, "pcm", obj.pcm, "solvent", obj.solvent, ...
                "smx", obj.smx, "scan", obj.scan, ...
                "van_der_waals", obj.van_der_waals, ...
                "vdw_mode", char(obj.vdw_mode), "plots", obj.plots, ...
                "nbo", obj.nbo, "geom_opt", obj.geom_opt, "cdft", obj.cdft, ...
                "almo_coupling", obj.almo_coupling, "svp", obj.svp, ...
                "pcm_nonels", obj.pcm_nonels);
            value = kssolv.analysis.matgenlab.util.msonDict( ...
                "pymatgen.io.qchem.inputs", "QCInput", properties);
        end
        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Static)
        function text = multi_job_string(jobs)
            if ~iscell(jobs), jobs = num2cell(jobs); end
            strings = cellfun(@(job) job.get_str(), jobs, "UniformOutput", false);
            text = char(strjoin(string(strings), sprintf("\n@@@\n\n")));
        end

        function write_multi_job_file(jobs, filename)
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.multi_job_string(jobs);
            fid = fopen(filename, "w", "n", "UTF-8");
            if fid < 0, error("KSSOLV:Matgenlab:QChem:Write", "Cannot write '%s'.", filename); end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, text, "char");
            clear cleanup
        end

        function obj = from_file(filename)
            text = kssolv.analysis.matgenlab.io.qchem.read_text(filename);
            obj = kssolv.analysis.matgenlab.io.qchem.QCInput.from_str(text);
        end

        function jobs = from_multi_jobs_file(filename)
            text = kssolv.analysis.matgenlab.io.qchem.read_text(filename);
            pieces = regexp(text, "\s*@@@\s*", "split");
            jobs = cellfun(@(piece) ...
                kssolv.analysis.matgenlab.io.qchem.QCInput.from_str(piece), ...
                pieces, "UniformOutput", false);
        end

        function obj = from_str(text)
            cls = kssolv.analysis.matgenlab.io.qchem.QCInput;
            sections = cls.find_sections(text);
            values = struct();
            simple = {"opt", "pcm", "solvent", "smx", "scan", ...
                "plots", "nbo", "geom_opt", "cdft", "svp", "pcm_nonels"};
            for index = 1:numel(simple)
                name = simple{index};
                if any(strcmp(sections, name))
                    switch name
                        case "opt", values.opt = cls.read_opt(text);
                        case "pcm", values.pcm = cls.read_pcm(text);
                        case "solvent", values.solvent = cls.read_solvent(text);
                        case "smx", values.smx = cls.read_smx(text);
                        case "scan", values.scan = cls.read_scan(text);
                        case "plots", values.plots = cls.read_plots(text);
                        case "nbo", values.nbo = cls.read_nbo(text);
                        case "geom_opt", values.geom_opt = cls.read_geom_opt(text);
                        case "cdft", values.cdft = cls.read_cdft(text);
                        case "svp", values.svp = cls.read_svp(text);
                        case "pcm_nonels", values.pcm_nonels = cls.read_pcm_nonels(text);
                    end
                end
            end
            if any(strcmp(sections, "van_der_waals"))
                [values.vdw_mode, values.van_der_waals] = cls.read_vdw(text);
            end
            if any(strcmp(sections, "almo_coupling"))
                values.almo_coupling = cls.read_almo(text);
            end
            args = {};
            names = fieldnames(values);
            for index = 1:numel(names)
                args(end + 1:end + 2) = {names{index}, values.(names{index})};
            end
            obj = kssolv.analysis.matgenlab.io.qchem.QCInput( ...
                cls.read_molecule(text), cls.read_rem(text), args{:});
        end

        function obj = from_dict(value)
            fields = {"opt", "pcm", "solvent", "smx", "scan", ...
                "van_der_waals", "vdw_mode", "plots", "nbo", "geom_opt", ...
                "cdft", "almo_coupling", "svp", "pcm_nonels"};
            molecule = value.molecule;
            if isstruct(molecule) && isfield(molecule, "sites")
                molecule = kssolv.analysis.matgenlab.core.Molecule.from_dict(molecule);
            elseif iscell(molecule)
                for index = 1:numel(molecule)
                    if isstruct(molecule{index})
                        molecule{index} = ...
                            kssolv.analysis.matgenlab.core.Molecule.from_dict(molecule{index});
                    end
                end
            end
            args = {};
            for index = 1:numel(fields)
                if isfield(value, fields{index})
                    args(end + 1:end + 2) = {fields{index}, value.(fields{index})};
                end
            end
            obj = kssolv.analysis.matgenlab.io.qchem.QCInput( ...
                molecule, value.rem, args{:});
        end
        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.qchem.QCInput.from_dict(value);
        end

        function text = molecule_template(molecule)
            lines = {"$molecule"};
            if isstring(molecule) || ischar(molecule)
                if lower(string(molecule)) ~= "read"
                    error("KSSOLV:Matgenlab:QChem:Molecule", ...
                        "The only acceptable text value for molecule is 'read'.");
                end
                lines{end + 1} = " read";
            else
                if ~iscell(molecule), fragments = {molecule}; else, fragments = molecule; end
                if numel(fragments) == 1
                    mol = fragments{1};
                    lines{end + 1} = sprintf(" %d %d", round(mol.charge), mol.spin_multiplicity);
                    lines = [lines, kssolv.analysis.matgenlab.io.qchem.QCInput.site_lines(mol)];
                else
                    charge = sum(cellfun(@(item) item.charge, fragments));
                    spin = sum(cellfun(@(item) item.spin_multiplicity - 1, fragments)) + 1;
                    lines{end + 1} = sprintf(" %d %d", round(charge), round(spin));
                    for index = 1:numel(fragments)
                        mol = fragments{index};
                        lines{end + 1} = "--";
                        lines{end + 1} = sprintf(" %d %d", round(mol.charge), mol.spin_multiplicity);
                        lines = [lines, kssolv.analysis.matgenlab.io.qchem.QCInput.site_lines(mol)];
                    end
                end
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function text = rem_template(value)
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.key_value_template( ...
                "rem", value, " = ");
        end
        function text = pcm_template(value)
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.key_value_template("pcm", value, " ");
        end
        function text = solvent_template(value)
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.key_value_template("solvent", value, " ");
        end
        function text = plots_template(value)
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.key_value_template("plots", value, " ");
        end
        function text = nbo_template(value)
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.key_value_template("nbo", value, " = ");
        end
        function text = geom_opt_template(value)
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.key_value_template("geom_opt", value, " = ");
        end

        function text = smx_template(value)
            [keys, values] = kssolv.analysis.matgenlab.io.qchem.QCInput.pairs(value);
            for index = 1:numel(values)
                if lower(string(values{index})) == "tetrahydrofuran", values{index} = "thf"; end
                if lower(string(values{index})) == "dimethyl sulfoxide", values{index} = "dmso"; end
            end
            text = kssolv.analysis.matgenlab.io.qchem.QCInput.key_value_template( ...
                "smx", containers.Map(keys, values), " ");
        end

        function text = opt_template(value)
            [keys, values] = kssolv.analysis.matgenlab.io.qchem.QCInput.pairs(value);
            lines = {"$opt"};
            for index = 1:numel(keys)
                key = char(string(keys{index}));
                lines{end + 1} = key;
                entries = string(values{index});
                for item = reshape(entries, 1, [])
                    lines{end + 1} = ['   ' char(item)];
                end
                lines{end + 1} = ['END' key];
                if index < numel(keys), lines{end + 1} = ""; end
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function text = scan_template(value)
            [keys, values] = kssolv.analysis.matgenlab.io.qchem.QCInput.pairs(value);
            count = sum(cellfun(@numel, values));
            if count > 2
                error("KSSOLV:Matgenlab:QChem:Scan", ...
                    "Q-Chem only supports PES_SCAN with two or less variables.");
            end
            lines = {"$scan"};
            for index = 1:numel(keys)
                entries = string(values{index});
                for entry = reshape(entries, 1, [])
                    lines{end + 1} = sprintf("   %s %s", keys{index}, entry);
                end
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function text = van_der_waals_template(value, mode)
            if nargin < 2, mode = "atomic"; end
            if lower(string(mode)) == "atomic", modeLine = "1";
            elseif lower(string(mode)) == "sequential", modeLine = "2";
            else
                error("KSSOLV:Matgenlab:QChem:VDWMode", ...
                    "Invalid mode '%s'; expected 'atomic' or 'sequential'.", mode);
            end
            [keys, values] = kssolv.analysis.matgenlab.io.qchem.QCInput.pairs(value);
            lines = {"$van_der_waals", modeLine};
            for index = 1:numel(keys)
                lines{end + 1} = sprintf("   %s %s", keys{index}, ...
                    kssolv.analysis.matgenlab.io.qchem.QCInput.scalar_text(values{index}));
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function text = svp_template(value)
            [keys, values] = kssolv.analysis.matgenlab.io.qchem.QCInput.pairs(value);
            params = cell(1, numel(keys));
            for index = 1:numel(keys)
                params{index} = [keys{index} '=' ...
                    kssolv.analysis.matgenlab.io.qchem.QCInput.scalar_text(values{index})];
            end
            text = char(strjoin(["$svp", strjoin(string(params), ", "), "$end"], newline));
        end

        function text = pcm_nonels_template(value)
            [keys, values] = kssolv.analysis.matgenlab.io.qchem.QCInput.pairs(value);
            lines = {"$pcm_nonels"};
            for index = 1:numel(keys)
                if isempty(values{index}), continue; end
                lines{end + 1} = sprintf("   %s %s", keys{index}, ...
                    kssolv.analysis.matgenlab.io.qchem.QCInput.scalar_text(values{index}));
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function text = cdft_template(states)
            if ~iscell(states), states = num2cell(states); end
            lines = {"$cdft"};
            for stateIndex = 1:numel(states)
                constraints = states{stateIndex};
                if ~iscell(constraints), constraints = num2cell(constraints); end
                for index = 1:numel(constraints)
                    constraint = constraints{index};
                    lines{end + 1} = ['   ' ...
                        kssolv.analysis.matgenlab.io.qchem.QCInput.scalar_text(constraint.value)];
                    for term = 1:numel(constraint.coefficients)
                        suffix = "";
                        if isfield(constraint, "types") && numel(constraint.types) >= term
                            types = constraint.types;
                            if iscell(types), kind = types{term}; else, kind = types(term); end
                            if ~isempty(kind) && any(lower(string(kind)) == ["s", "spin"])
                                suffix = " s";
                            elseif ~isempty(kind) && ~any(lower(string(kind)) == ["c", "charge"])
                                error("KSSOLV:Matgenlab:QChem:CDFTType", ...
                                    "Invalid CDFT constraint type.");
                            end
                        end
                        lines{end + 1} = sprintf("   %s %d %d%s", ...
                            kssolv.analysis.matgenlab.io.qchem.QCInput.scalar_text( ...
                            constraint.coefficients(term)), ...
                            constraint.first_atoms(term), constraint.last_atoms(term), suffix);
                    end
                end
                if stateIndex < numel(states), lines{end + 1} = "--------------"; end
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function text = almo_template(states)
            if ~iscell(states), states = {states(1, :), states(2, :)}; end
            if numel(states) ~= 2
                error("KSSOLV:Matgenlab:QChem:ALMO", ...
                    "ALMO coupling calculations require exactly two states.");
            end
            lines = {"$almo_coupling"};
            for stateIndex = 1:2
                state = states{stateIndex};
                if iscell(state), state = vertcat(state{:}); end
                for index = 1:size(state, 1)
                    lines{end + 1} = sprintf("   %d %d", state(index, 1), state(index, 2));
                end
                if stateIndex == 1, lines{end + 1} = "   --"; end
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function sections = find_sections(text)
            if contains(text, "@@@")
                error("KSSOLV:Matgenlab:QChem:MultipleJobs", ...
                    "Input file contains multiple Q-Chem jobs; parse separately.");
            end
            tokens = regexp(char(text), "(?m)^\s*\$([A-Za-z_]+)", "tokens");
            sections = cellfun(@(item) lower(item{1}), tokens, "UniformOutput", false);
            sections(strcmp(sections, "end")) = [];
            if ~any(strcmp(sections, "molecule"))
                error("KSSOLV:Matgenlab:QChem:MissingMolecule", ...
                    "Input file does not contain a molecule section.");
            end
            if ~any(strcmp(sections, "rem"))
                error("KSSOLV:Matgenlab:QChem:MissingREM", ...
                    "Input file does not contain a REM section.");
            end
        end

        function molecule = read_molecule(text)
            body = kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, "molecule");
            lines = strip(splitlines(string(body)));
            lines(lines == "") = [];
            if lower(lines(1)) == "read", molecule = "read"; return; end
            if any(lines == "--")
                separators = find(lines == "--");
                molecule = cell(1, numel(separators));
                for index = 1:numel(separators)
                    first = separators(index) + 1;
                    if index < numel(separators), last = separators(index + 1) - 1;
                    else, last = numel(lines); end
                    molecule{index} = kssolv.analysis.matgenlab.io.qchem.QCInput.parse_molecule_lines( ...
                        lines(first:last));
                end
            else
                molecule = kssolv.analysis.matgenlab.io.qchem.QCInput.parse_molecule_lines(lines);
            end
        end

        function value = read_rem(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "rem", true); end
        function value = read_pcm(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "pcm", false); end
        function value = read_solvent(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "solvent", false); end
        function value = read_smx(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "smx", false); end
        function value = read_plots(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "plots", false); end
        function value = read_nbo(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "nbo", true); end
        function value = read_geom_opt(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "geom_opt", true); end
        function value = read_pcm_nonels(text), value = kssolv.analysis.matgenlab.io.qchem.QCInput.read_key_values(text, "pcm_nonels", false); end

        function value = read_opt(text)
            body = kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, "opt");
            value = struct();
            for name = ["CONSTRAINT", "FIXED", "DUMMY", "CONNECT"]
                token = regexp(body, ['(?ms)^\s*' char(name) '\s*\n(.*?)^\s*END' char(name)], ...
                    "tokens", "once");
                if ~isempty(token)
                    entries = strip(splitlines(string(token{1})));
                    entries(entries == "") = [];
                    value.(char(name)) = cellstr(entries);
                end
            end
        end

        function value = read_scan(text)
            body = kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, "scan");
            value = struct("stre", {{}}, "bend", {{}}, "tors", {{}});
            lines = strip(splitlines(string(body)));
            for line = reshape(lines, 1, [])
                token = regexp(line, "^(stre|bend|tors)\s+(.+)$", "tokens", "once", ...
                    "ignorecase");
                if ~isempty(token)
                    key = lower(token{1});
                    value.(key){end + 1} = char(strip(token{2}));
                end
            end
            if sum(structfun(@numel, value)) > 2
                error("KSSOLV:Matgenlab:QChem:Scan", ...
                    "No more than two variables are allowed in the scan section.");
            end
        end

        function [mode, value] = read_vdw(text)
            body = kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, "van_der_waals");
            lines = strip(splitlines(string(body))); lines(lines == "") = [];
            if lines(1) == "2", mode = "sequential"; else, mode = "atomic"; end
            value = containers.Map("KeyType", "char", "ValueType", "double");
            for index = 2:numel(lines)
                token = split(lines(index));
                value(char(token(1))) = str2double(token(2));
            end
        end

        function value = read_svp(text)
            body = strip(string(kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, "svp")));
            entries = split(body, ",");
            value = struct();
            for entry = reshape(entries, 1, [])
                pair = split(strip(entry), "=");
                value.(matlab.lang.makeValidName(char(strip(pair(1))))) = char(strip(pair(2)));
            end
        end

        function states = read_cdft(text)
            body = kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, "cdft");
            stateText = regexp(body, "\s*-{2,}\s*", "split");
            states = cell(1, numel(stateText));
            for stateIndex = 1:numel(stateText)
                lines = strip(splitlines(string(stateText{stateIndex})));
                lines(lines == "") = [];
                constraints = {};
                index = 1;
                while index <= numel(lines)
                    target = str2double(lines(index));
                    if isnan(target), index = index + 1; continue; end
                    constraint = struct("value", target, "coefficients", [], ...
                        "first_atoms", [], "last_atoms", [], "types", {{}});
                    index = index + 1;
                    while index <= numel(lines)
                        terms = split(lines(index));
                        if numel(terms) < 3, break; end
                        constraint.coefficients(end + 1) = str2double(terms(1));
                        constraint.first_atoms(end + 1) = str2double(terms(2));
                        constraint.last_atoms(end + 1) = str2double(terms(3));
                        if numel(terms) > 3, constraint.types{end + 1} = char(terms(4));
                        else, constraint.types{end + 1} = []; end
                        index = index + 1;
                    end
                    constraints{end + 1} = constraint;
                end
                states{stateIndex} = constraints;
            end
        end

        function states = read_almo(text)
            body = kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, "almo_coupling");
            pieces = regexp(body, "\s*--\s*", "split");
            states = cell(1, numel(pieces));
            for stateIndex = 1:numel(pieces)
                values = sscanf(pieces{stateIndex}, "%d");
                states{stateIndex} = reshape(values, 2, []).';
            end
        end
    end

    methods (Static, Access = private)
        function lines = site_lines(molecule)
            lines = cell(1, molecule.num_sites);
            for index = 1:molecule.num_sites
                site = molecule.sites{index};
                lines{index} = sprintf(" %s     % .10f     % .10f     % .10f", ...
                    site.species_string, site.x, site.y, site.z);
            end
        end

        function molecule = parse_molecule_lines(lines)
            header = sscanf(lines(1), "%f");
            if numel(header) < 2
                error("KSSOLV:Matgenlab:QChem:Molecule", ...
                    "Molecule charge and spin multiplicity are missing.");
            end
            species = cell(numel(lines) - 1, 1);
            coordinates = zeros(numel(lines) - 1, 3);
            for index = 2:numel(lines)
                token = split(lines(index));
                species{index - 1} = char(token(1));
                coordinates(index - 1, :) = str2double(token(2:4));
            end
            molecule = kssolv.analysis.matgenlab.core.Molecule(species, coordinates, ...
                charge = header(1), spin_multiplicity = header(2));
        end

        function body = section(text, name)
            token = regexp(char(text), ['(?ms)^\s*\$' char(name) '\s*\n(.*?)^\s*\$end'], ...
                "tokens", "once");
            if isempty(token), body = ""; else, body = token{1}; end
        end

        function value = read_key_values(text, sectionName, equalsAllowed)
            body = kssolv.analysis.matgenlab.io.qchem.QCInput.section(text, sectionName);
            lines = strip(splitlines(string(body))); lines(lines == "") = [];
            value = struct();
            for line = reshape(lines, 1, [])
                if equalsAllowed, token = regexp(line, "^([A-Za-z0-9_]+)\s*=?\s*(\S+)", "tokens", "once");
                else, token = regexp(line, "^([A-Za-z0-9_]+)\s+(\S.*)$", "tokens", "once"); end
                if ~isempty(token)
                    value.(matlab.lang.makeValidName(char(token{1}))) = char(strip(token{2}));
                end
            end
        end

        function text = key_value_template(name, value, separator)
            [keys, values] = kssolv.analysis.matgenlab.io.qchem.QCInput.pairs(value);
            separator = char(separator);
            lines = {['$' char(name)]};
            for index = 1:numel(keys)
                lines{end + 1} = ['   ' keys{index} separator ...
                    kssolv.analysis.matgenlab.io.qchem.QCInput.scalar_text(values{index})];
            end
            lines{end + 1} = "$end";
            text = char(strjoin(string(lines), newline));
        end

        function [keys, values] = pairs(value)
            if isa(value, "containers.Map")
                keys = value.keys; values = value.values;
            elseif isstruct(value)
                keys = fieldnames(value).'; values = struct2cell(value).';
            else
                error("KSSOLV:Matgenlab:QChem:Dictionary", ...
                    "Expected a structure or containers.Map.");
            end
            keys = cellfun(@char, cellfun(@string, keys, "UniformOutput", false), ...
                "UniformOutput", false);
        end

        function text = scalar_text(value)
            if islogical(value), text = char(lower(string(value)));
            elseif isnumeric(value) && isscalar(value), text = char(string(value));
            else, text = char(string(value)); end
        end
    end
end
