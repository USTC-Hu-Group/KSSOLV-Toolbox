function data = parse_output_slice(text)
%PARSE_OUTPUT_SLICE Parse one JDFTx invocation into a MATLAB data model.
lines = string(text);
ha_to_ev = 27.21138624598059;
bohr_to_ang = 0.529177210544;
data = empty_data();
data.raw_text = lines;

data.spintype = first_command_value(lines, "spintype", "no-spin");
if any(strcmpi(data.spintype, ["z-spin", "vector-spin"]))
    data.nspin = 2;
else
    data.nspin = 1;
end
smearing = first_command_tokens(lines, "elec-smearing");
if ~isempty(smearing)
    data.broadening_type = smearing(1);
    if numel(smearing) > 1
        data.broadening = str2double(smearing(2));
    end
end
cutoff = first_command_numbers(lines, "elec-cutoff");
if ~isempty(cutoff)
    data.pwcut = cutoff(1) * ha_to_ev;
    if numel(cutoff) > 1
        data.rhocut = cutoff(2) * ha_to_ev;
    else
        data.rhocut = 4 * cutoff(1) * ha_to_ev;
    end
end
data.kgrid = first_command_numbers(lines, "kpoint-folding");
data.nbands = first_command_number(lines, "elec-n-bands");
truncation = first_command_tokens(lines, "coulomb-interaction");
if isempty(truncation)
    data.truncation_type = "periodic";
else
    data.truncation_type = lower(truncation(1));
    if data.truncation_type == "spherical" && numel(truncation) > 1
        data.truncation_radius = str2double(truncation(2));
    end
end
fluid = first_command_tokens(lines, "fluid");
if ~isempty(fluid) && ~strcmpi(fluid(1), "none")
    data.fluid = fluid(1);
    data.has_solvation = true;
end
dump_name = first_command_value(lines, "dump-name", "$VAR");
if endsWith(dump_name, ".$VAR")
    data.prefix = extractBefore(dump_name, strlength(dump_name) - 4);
else
    data.prefix = dump_name;
end
fft_hit = find(contains(lines, "Chosen fftbox size, S = ["), 1);
if ~isempty(fft_hit)
    data.fftgrid = bracket_numbers(lines(fft_hit));
end

ionic_iterations = setting_iterations(lines, "ionic-minimize");
lattice_iterations = setting_iterations(lines, "lattice-minimize");
if lattice_iterations > 0
    data.geom_opt = true;
    data.geom_opt_type = "lattice";
elseif ionic_iterations > 0
    data.geom_opt = true;
    data.geom_opt_type = "ionic";
else
    data.geom_opt = false;
    data.geom_opt_type = "single point";
end

[lattice, lattice_initial] = parse_lattices(lines);
data.lattice = lattice;
data.lattice_final = lattice;
data.lattice_initial = lattice_initial;
if ~isempty(lattice)
    data.a = norm(lattice(1, :));
    data.b = norm(lattice(2, :));
    data.c = norm(lattice(3, :));
end
[species, coords, move_scale] = parse_last_ions(lines, lattice);
data.atom_elements = species;
data.atom_types = unique(species, "stable");
data.atom_elements_int = atomic_numbers(species);
data.atom_coords = coords;
data.atom_coords_final = coords;
data.atom_coords_initial = parse_first_ions(lines, lattice);
data.nat = numel(species);
data.selective_dynamics = move_scale;
data.structure = struct("lattice", lattice, "species", species, ...
    "coords", coords, "coords_are_cartesian", true);

data.forces = parse_vector_block(lines, "# Forces", "force", ...
    ha_to_ev / bohr_to_ang);
data.ecomponents = parse_energy_components(lines, ha_to_ev);
data.electronic_output = kssolv.analysis.matgenlab.io.jdftx. ...
    JElSteps.from_text_slice(lines, opt_type = "ElecMinimize", ...
    etype = infer_energy_type(lines));
data.elecmindata = data.electronic_output;
data.eopt_type = "ElecMinimize";
data.etype = infer_energy_type(lines);

last_step = parse_last_iteration(lines, data.etype);
step_names = fieldnames(last_step);
for idx = 1:numel(step_names)
    data.(step_names{idx}) = last_step.(step_names{idx});
end
data.elec_nstep = data.electronic_output.nstep;
data.elec_e = data.electronic_output.e;
data.elec_grad_k = data.electronic_output.grad_k;
data.elec_alpha = data.electronic_output.alpha;
data.elec_linmin = data.electronic_output.linmin;

fillings = find(contains(lines, "FillingsUpdate:"), 1, "last");
if ~isempty(fillings)
    mu = kssolv.analysis.matgenlab.io.jdftx.get_colon_val( ...
        lines(fillings), "mu:");
    if ~isempty(mu)
        data.mu = mu * ha_to_ev;
    end
    data.total_electrons = kssolv.analysis.matgenlab.io.jdftx. ...
        get_colon_val(lines(fillings), "nElectrons:");
    data.nelectrons = data.total_electrons;
    data.abs_magneticmoment = kssolv.analysis.matgenlab.io.jdftx. ...
        get_colon_val(lines(fillings), "Abs:");
    data.tot_magneticmoment = kssolv.analysis.matgenlab.io.jdftx. ...
        get_colon_val(lines(fillings), "Tot:");
end
[data, has_eigstats] = parse_eigstats(data, lines, ha_to_ev);
data.has_eigstats = has_eigstats;
if isempty(data.efermi)
    data.efermi = data.mu;
end
if ~isempty(data.egap) && ~isempty(data.broadening)
    data.is_metal = data.egap <= data.broadening * ha_to_ev;
end
data.converged = any(contains(lines, "ElecMinimize: Converged"));
if data.geom_opt
    if data.geom_opt_type == "lattice"
        data.converged = data.converged && ...
            any(contains(lines, "LatticeMinimize: Converged"));
    else
        data.converged = data.converged && ...
            any(contains(lines, "IonicMinimize: Converged"));
    end
end
data.is_gc = data.etype == "G";
data.jstrucs = kssolv.analysis.matgenlab.io.jdftx.JOutStructures( ...
    "slices", {make_joutstructure(data)});
data.initial_structure = data.structure;
data.trajectory = {data.structure};
data.infile = parse_internal_infile(lines);
[data.vibrational_modes, data.vibrational_energy_components] = ...
    parse_vibrations(lines, ha_to_ev, bohr_to_ang);
end

function data = empty_data()
names = ["prefix", "jstrucs", "jsettings_fluid", ...
    "jsettings_electronic", "jsettings_lattice", "jsettings_ionic", ...
    "xc_func", "lattice_initial", "lattice_final", "lattice", ...
    "a", "b", "c", "fftgrid", "geom_opt", "geom_opt_type", ...
    "electronic_output", "efermi", "egap", "optical_egap", ...
    "emin", "emax", "homo", "lumo", "homo_filling", "lumo_filling", ...
    "is_metal", "etype", "broadening_type", "broadening", "kgrid", ...
    "truncation_type", "truncation_radius", "pwcut", "rhocut", ...
    "pp_type", "semicore_electrons", "valence_electrons", ...
    "total_electrons_uncharged", "semicore_electrons_uncharged", ...
    "valence_electrons_uncharged", "nbands", "atom_elements", ...
    "atom_elements_int", "atom_types", "spintype", "nspin", "nat", ...
    "atom_coords_initial", "atom_coords_final", "atom_coords", ...
    "has_solvation", "fluid", "is_gc", "has_eigstats", ...
    "parsable_pseudos", "has_parsable_pseudo", "total_electrons", ...
    "t_s", "converged", "structure", "initial_structure", ...
    "trajectory", "eopt_type", "elecmindata", "stress", "strain", ...
    "forces", "nstep", "e", "grad_k", "alpha", "linmin", ...
    "abs_magneticmoment", "tot_magneticmoment", "mu", "nelectrons", ...
    "elec_nstep", "elec_e", "elec_grad_k", "elec_alpha", ...
    "elec_linmin", "infile", "vibrational_modes", ...
    "vibrational_energy_components", "selective_dynamics", "raw_text"];
data = struct();
for name = names
    data.(name) = [];
end
data.has_solvation = false;
data.geom_opt = false;
data.converged = false;
data.is_gc = false;
data.has_eigstats = false;
data.parsable_pseudos = false;
data.has_parsable_pseudo = false;
data.jsettings_fluid = kssolv.analysis.matgenlab.io.jdftx.JMinSettingsFluid();
data.jsettings_electronic = kssolv.analysis.matgenlab.io.jdftx. ...
    JMinSettingsElectronic();
data.jsettings_lattice = kssolv.analysis.matgenlab.io.jdftx.JMinSettingsLattice();
data.jsettings_ionic = kssolv.analysis.matgenlab.io.jdftx.JMinSettingsIonic();
end

function value = first_command_value(lines, command, default)
tokens = first_command_tokens(lines, command);
if isempty(tokens)
    value = string(default);
else
    value = join(tokens, " ");
end
end

function tokens = first_command_tokens(lines, command)
pattern = "^\s*" + regexptranslate("escape", string(command)) + "(?:\s+|$)";
hit = find(~cellfun("isempty", regexp(cellstr(lines), pattern, "once")), 1);
if isempty(hit)
    tokens = strings(0, 1);
    return
end
tail = strtrim(regexprep(lines(hit), pattern, ""));
tokens = regexp(tail, "\s+", "split");
tokens = reshape(tokens(strlength(tokens) > 0), 1, []);
end

function values = first_command_numbers(lines, command)
tokens = first_command_tokens(lines, command);
values = str2double(tokens);
values = values(~isnan(values));
end

function value = first_command_number(lines, command)
values = first_command_numbers(lines, command);
if isempty(values)
    value = [];
else
    value = values(1);
end
end

function values = bracket_numbers(line)
token = regexp(line, "\[(.*?)\]", "tokens", "once");
if isempty(token)
    values = [];
else
    values = sscanf(token{1}, "%f").';
end
end

function value = setting_iterations(lines, command)
value = 0;
hit = find(startsWith(strtrim(lines), command + " "), 1);
if isempty(hit)
    return
end
stop = min(numel(lines), hit + 30);
for idx = hit:stop
    token = regexp(lines(idx), "nIterations\s+([-+]?\d+)", ...
        "tokens", "once");
    if ~isempty(token)
        value = str2double(token{1});
        return
    end
    if idx > hit && ~endsWith(strtrim(lines(idx - 1)), "\")
        break
    end
end
end

function [last, first] = parse_lattices(lines)
hits = find(startsWith(strtrim(lines), "lattice "));
matrices = {};
for idx = reshape(hits, 1, [])
    values = [];
    inline = regexprep(strtrim(lines(idx)), "^lattice\s*", "");
    inline = erase(inline, "\");
    values = [values, sscanf(inline, "%f").']; %#ok<AGROW>
    cursor = idx + 1;
    while numel(values) < 9 && cursor <= numel(lines)
        values = [values, sscanf(erase(lines(cursor), "\"), "%f").']; %#ok<AGROW>
        cursor = cursor + 1;
    end
    if numel(values) >= 9
        matrices{end + 1} = reshape(values(1:9), 3, 3) ...
            * 0.529177210544; %#ok<AGROW>
    end
end
if isempty(matrices)
    last = [];
    first = [];
else
    first = matrices{1};
    last = matrices{end};
end
end

function [species, coords, move] = parse_last_ions(lines, lattice)
[blocks, headers] = ion_blocks(lines);
if isempty(blocks)
    species = strings(0, 1);
    coords = zeros(0, 3);
    move = zeros(0, 1);
    return
end
[species, coords, move] = parse_ion_block(lines(blocks{end}), ...
    headers(end), lattice);
end

function coords = parse_first_ions(lines, lattice)
[blocks, headers] = ion_blocks(lines);
if isempty(blocks)
    coords = zeros(0, 3);
else
    [~, coords] = parse_ion_block(lines(blocks{1}), headers(1), lattice);
end
end

function [blocks, headers] = ion_blocks(lines)
is_ion = startsWith(strtrim(lines), "ion ");
starts = find(is_ion & [true; ~is_ion(1:end - 1)]);
blocks = cell(1, numel(starts));
headers = strings(1, numel(starts));
for idx = 1:numel(starts)
    stop = starts(idx);
    while stop < numel(lines) && is_ion(stop + 1)
        stop = stop + 1;
    end
    blocks{idx} = starts(idx):stop;
    if starts(idx) > 1
        headers(idx) = lines(starts(idx) - 1);
    end
end
end

function [species, coords, move] = parse_ion_block(lines, header, lattice)
species = strings(numel(lines), 1);
coords = zeros(numel(lines), 3);
move = ones(numel(lines), 1);
for idx = 1:numel(lines)
    tokens = regexp(strtrim(lines(idx)), "\s+", "split");
    species(idx) = tokens(2);
    coords(idx, :) = str2double(tokens(3:5));
    value = str2double(tokens(end));
    if isfinite(value)
        move(idx) = value;
    end
end
cartesian = contains(lower(header), "cartesian");
if cartesian
    coords = coords * 0.529177210544;
elseif ~isempty(lattice)
    coords = coords * lattice;
end
end

function values = atomic_numbers(species)
symbols = ["H","He","Li","Be","B","C","N","O","F","Ne","Na","Mg", ...
    "Al","Si","P","S","Cl","Ar","K","Ca","Sc","Ti","V","Cr","Mn", ...
    "Fe","Co","Ni","Cu","Zn","Ga","Ge","As","Se","Br","Kr","Rb", ...
    "Sr","Y","Zr","Nb","Mo","Tc","Ru","Rh","Pd","Ag","Cd","In", ...
    "Sn","Sb","Te","I","Xe","Cs","Ba","La","Ce","Pr","Nd","Pm", ...
    "Sm","Eu","Gd","Tb","Dy","Ho","Er","Tm","Yb","Lu","Hf","Ta", ...
    "W","Re","Os","Ir","Pt","Au","Hg","Tl","Pb","Bi","Po","At","Rn"];
values = zeros(numel(species), 1);
for idx = 1:numel(species)
    hit = find(symbols == species(idx), 1);
    if ~isempty(hit)
        values(idx) = hit;
    end
end
end

function vectors = parse_vector_block(lines, header_key, row_key, scale)
hit = find(contains(lines, header_key), 1, "last");
vectors = [];
if isempty(hit)
    return
end
cursor = hit + 1;
while cursor <= numel(lines) && ...
        startsWith(strtrim(lines(cursor)), row_key + " ")
    tokens = regexp(strtrim(lines(cursor)), "\s+", "split");
    vectors(end + 1, :) = str2double(tokens(3:5)) * scale; %#ok<AGROW>
    cursor = cursor + 1;
end
end

function components = parse_energy_components(lines, scale)
hit = find(contains(lines, "# Energy components:"), 1, "last");
components = struct();
if isempty(hit)
    return
end
for idx = hit + 1:min(numel(lines), hit + 30)
    token = regexp(lines(idx), ...
        "^\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*([-+0-9.Ee]+)", ...
        "tokens", "once");
    if ~isempty(token)
        components.(matlab.lang.makeValidName(token{1})) = ...
            str2double(token{2}) * scale;
    elseif idx > hit + 1 && strlength(strtrim(lines(idx))) == 0
        break
    end
end
end

function etype = infer_energy_type(lines)
etype = "F";
matches = regexp(lines, ...
    "(?:Elec|Ionic|Lattice)Minimize:\s*Iter:\s*\d+\s+([A-Za-z]+):", ...
    "tokens", "once");
for idx = numel(matches):-1:1
    if ~isempty(matches{idx})
        etype = string(matches{idx}{1});
        return
    end
end
end

function step = parse_last_iteration(lines, etype)
step = struct("nstep", [], "e", [], "grad_k", [], "alpha", [], ...
    "linmin", [], "t_s", []);
hits = find(contains(lines, "Minimize: Iter:"));
if isempty(hits)
    return
end
line = lines(hits(end));
step.nstep = kssolv.analysis.matgenlab.io.jdftx.get_colon_val(line, "Iter:");
energy = kssolv.analysis.matgenlab.io.jdftx.get_colon_val( ...
    line, etype + ":");
if ~isempty(energy)
    step.e = energy * 27.21138624598059;
end
step.grad_k = kssolv.analysis.matgenlab.io.jdftx.get_colon_val( ...
    line, "|grad|_K:");
step.alpha = kssolv.analysis.matgenlab.io.jdftx.get_colon_val( ...
    line, "alpha:");
step.linmin = kssolv.analysis.matgenlab.io.jdftx.get_colon_val( ...
    line, "linmin:");
step.t_s = kssolv.analysis.matgenlab.io.jdftx.get_colon_val( ...
    line, "t[s]:");
end

function [data, found] = parse_eigstats(data, lines, scale)
keys = ["eMin:", "HOMO:", "mu  :", "LUMO:", "eMax:", ...
    "HOMO-LUMO gap:", "Optical gap  :"];
fields = ["emin", "homo", "efermi", "lumo", "emax", ...
    "egap", "optical_egap"];
found = false;
for idx = 1:numel(keys)
    hit = find(contains(lines, keys(idx)), 1, "last");
    if ~isempty(hit)
        token = regexp(extractAfter(lines(hit), keys(idx)), ...
            "[-+]?(?:\d*\.?\d+)(?:[Ee][-+]?\d+)?", "match", "once");
        if ~isempty(token)
            data.(fields(idx)) = str2double(token) * scale;
            found = true;
        end
    end
end
end

function infile = parse_internal_infile(lines)
start = find(contains(lines, ...
    "Input parsed successfully to the following command list"), 1);
if isempty(start)
    infile = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile();
    return
end
stop = find(contains(lines(start + 1:end), ...
    "Initializing the Grid"), 1);
if isempty(stop)
    stop = min(numel(lines), start + 250);
else
    stop = start + stop - 1;
end
try
    infile = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile. ...
        from_str(join(lines(start + 1:stop), newline), ...
        dont_require_structure = true, ...
        validate_value_boundaries = false);
catch
    infile = kssolv.analysis.matgenlab.io.jdftx.JDFTXInfile();
end
end

function object = make_joutstructure(data)
object = kssolv.analysis.matgenlab.io.jdftx.JOutStructure( ...
    data.lattice, data.atom_elements, data.atom_coords, ...
    site_properties = struct("selective_dynamics", ...
    data.selective_dynamics));
names = ["etype", "eopt_type", "ecomponents", "elecmindata", ...
    "forces", "nstep", "e", "grad_k", "alpha", "linmin", "t_s", ...
    "mu", "nelectrons", "abs_magneticmoment", "tot_magneticmoment"];
for name = names
    object.(name) = data.(name);
end
end

function [modes, components] = parse_vibrations(lines, energy_scale, length_scale)
modes = {};
components = struct();
for idx = 1:numel(lines)
    token = regexp(lines(idx), ...
        "^\s*(T|ZPE|Evib|TSvib|Avib)\s*[:=]\s*([-+0-9.Ee]+)", ...
        "tokens", "once");
    if ~isempty(token)
        value = str2double(token{2});
        if ~strcmp(token{1}, "T")
            value = value * energy_scale;
        end
        components.(token{1}) = value;
    end
    mode_token = regexp(lines(idx), ...
        "^\s*(Imaginary|Zero|Real) mode\s+(\d+)", "tokens", "once");
    if ~isempty(mode_token)
        mode = struct("Type", string(mode_token{1}), ...
            "Type_index", str2double(mode_token{2}), ...
            "Frequency", [], "Degeneracy", [], "IR_intensity", [], ...
            "Displacements", []);
        for cursor = idx:min(numel(lines), idx + 12)
            freq = regexp(lines(cursor), "Frequency.*?([-+0-9.Ee]+)", ...
                "tokens", "once");
            if ~isempty(freq)
                mode.Frequency = str2double(freq{1}) * energy_scale;
                if mode.Type == "Imaginary"
                    mode.Frequency = 1i * mode.Frequency;
                end
            end
            deg = regexp(lines(cursor), "Degeneracy.*?(\d+)", ...
                "tokens", "once");
            if ~isempty(deg)
                mode.Degeneracy = str2double(deg{1});
            end
            intensity = regexp(lines(cursor), ...
                "IR intensity.*?([-+0-9.Ee]+)", "tokens", "once");
            if ~isempty(intensity)
                mode.IR_intensity = str2double(intensity{1});
            end
        end
        mode.Displacements = mode.Displacements * length_scale;
        modes{end + 1} = mode; %#ok<AGROW>
    end
end
if isempty(fieldnames(components))
    components = [];
end
end
