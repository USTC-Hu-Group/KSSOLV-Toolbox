classdef ChargemolAnalysis < handle
    %CHARGEMOLANALYSIS Native parser for Chargemol DDEC/CM5 output.
    %
    % Parsing is implemented entirely in MATLAB. External Chargemol
    % execution is isolated behind an explicitly supplied executor; this
    % class never searches PATH or starts a shell process on its own.

    properties (SetAccess = private)
        ddec_charges (1,:) double = zeros(1, 0)
        dipoles (:,3) double = zeros(0, 3)
        bond_order_sums (1,:) double = zeros(1, 0)
        bond_order_dict (1,:) cell = cell(1, 0)
        ddec_spin_moments (1,:) double = zeros(1, 0)
        ddec_rsquared_moments (1,:) double = zeros(1, 0)
        ddec_rcubed_moments (1,:) double = zeros(1, 0)
        ddec_rfourth_moments (1,:) double = zeros(1, 0)
        cm5_charges (1,:) double = zeros(1, 0)
        chgcar = []
        structure = []
        natoms (1,:) double = zeros(1, 0)
        nelect (1,:) double = zeros(1, 0)
        aeccar0 = []
        aeccar2 = []
        net_charge (1,1) double = 0
        periodicity (1,3) logical = [true, true, true]
        method (1,1) string = "ddec6"
        command (1,1) string = "chargemol"
        executor = []
    end

    properties (Access = private)
        vasp_dir (1,1) string = ""
        run_dir (1,1) string = ""
        atomic_densities_path (1,1) string = missing
        chgcar_path (1,1) string = ""
        potcar_path (1,1) string = ""
        aeccar0_path (1,1) string = ""
        aeccar2_path (1,1) string = ""
    end

    properties (Dependent, SetAccess = private)
        summary
    end

    methods
        function obj = ChargemolAnalysis(path, atomic_densities_path, ...
                run_chargemol, run_dir, options)
            arguments
                path (1,1) string = ""
                atomic_densities_path (1,1) string = missing
                run_chargemol (1,1) logical = true
                run_dir (1,1) string = ""
                options.executor = []
                options.command (1,1) string = "chargemol"
                options.net_charge (1,1) double = 0
                options.periodicity (1,3) logical = [true, true, true]
                options.method (1,1) string = "ddec6"
                options.compute_bond_orders (1,1) logical = true
            end
            if strlength(path) == 0, path = string(pwd); end
            obj.vasp_dir = absolutePath(path);
            obj.run_dir = run_dir;
            obj.atomic_densities_path = atomic_densities_path;
            obj.executor = options.executor;
            obj.command = options.command;
            obj.net_charge = options.net_charge;
            obj.periodicity = options.periodicity;
            obj.method = lower(options.method);
            if ~isempty(obj.executor) && ~isa(obj.executor, "function_handle")
                error("KSSOLV:Matgenlab:Chargemol:ExecutorType", ...
                    "executor must be a MATLAB function handle.");
            end
            if run_chargemol && isempty(obj.executor)
                error("KSSOLV:Matgenlab:Chargemol:ExecutorRequired", ...
                    "External Chargemol execution requires an explicitly " + ...
                    "supplied executor function handle.");
            end

            obj.chgcar_path = obj.get_filepath(path, "CHGCAR");
            obj.potcar_path = obj.get_filepath(path, "POTCAR");
            obj.aeccar0_path = obj.get_filepath(path, "AECCAR0");
            obj.aeccar2_path = obj.get_filepath(path, "AECCAR2");
            if run_chargemol && any(strlength([obj.chgcar_path, ...
                    obj.potcar_path, obj.aeccar0_path, ...
                    obj.aeccar2_path]) == 0)
                error("KSSOLV:Matgenlab:Chargemol:MissingInputs", ...
                    "CHGCAR, AECCAR0, AECCAR2, and POTCAR are all " + ...
                    "needed for Chargemol.");
            end

            obj.readVaspInputs();
            if run_chargemol
                outputPath = obj.executeChargemol( ...
                    options.compute_bond_orders);
                obj.parseOutputDirectory(outputPath);
            else
                obj.parseOutputDirectory(path);
            end
        end

        function value = get_charge_transfer(obj, atom_index, charge_type)
            if nargin < 3, charge_type = "ddec"; end
            value = -obj.get_partial_charge(atom_index, charge_type);
        end

        function value = get_charge(obj, atom_index, nelect, charge_type)
            if nargin < 3, nelect = []; end
            if nargin < 4, charge_type = "ddec"; end
            obj.validateAtomIndex(atom_index);
            if ~isempty(nelect)
                electronCount = double(nelect);
            elseif ~isempty(obj.nelect) && ~isempty(obj.natoms)
                speciesIndices = repelem(1:numel(obj.natoms), obj.natoms);
                electronCount = obj.nelect(speciesIndices(atom_index));
            else
                value = [];
                return;
            end
            value = electronCount + ...
                obj.get_charge_transfer(atom_index, charge_type);
        end

        function value = get_partial_charge(obj, atom_index, charge_type)
            if nargin < 3, charge_type = "ddec"; end
            obj.validateAtomIndex(atom_index);
            switch lower(string(charge_type))
                case "ddec"
                    value = obj.ddec_charges(atom_index);
                case "cm5"
                    if isempty(obj.cm5_charges)
                        error("KSSOLV:Matgenlab:Chargemol:MissingCM5", ...
                            "No CM5 charges were parsed.");
                    end
                    value = obj.cm5_charges(atom_index);
                otherwise
                    error("KSSOLV:Matgenlab:Chargemol:ChargeType", ...
                        "Invalid charge_type: %s", string(charge_type));
            end
        end

        function value = get_bond_order(obj, index_from, index_to)
            obj.validateAtomIndex(index_from);
            obj.validateAtomIndex(index_to);
            if isempty(obj.bond_order_dict) || ...
                    index_from > numel(obj.bond_order_dict) || ...
                    isempty(obj.bond_order_dict{index_from})
                value = 0;
                return;
            end
            bonded = obj.bond_order_dict{index_from}.bonded_to;
            if isempty(bonded)
                value = 0;
                return;
            end
            matches = [bonded.index] == index_to;
            value = sum([bonded(matches).bond_order]);
        end

        function result = get_property_decorated_structure(obj)
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:Chargemol:MissingStructure", ...
                    "A CHGCAR structure is required for decoration.");
            end
            siteProperties = struct( ...
                "partial_charge_ddec6", obj.ddec_charges);
            if ~isempty(obj.dipoles)
                siteProperties.dipole_ddec6 = ...
                    num2cell(obj.dipoles, 2);
            end
            if ~isempty(obj.bond_order_sums)
                siteProperties.bond_order_sum_ddec6 = ...
                    obj.bond_order_sums;
            end
            if ~isempty(obj.ddec_spin_moments)
                siteProperties.spin_moment_ddec6 = ...
                    obj.ddec_spin_moments;
            end
            if ~isempty(obj.cm5_charges)
                siteProperties.partial_charge_cm5 = obj.cm5_charges;
            end
            result = obj.structure.copy(siteProperties);
        end

        function value = get.summary(obj)
            ddec = struct("partial_charges", obj.ddec_charges);
            optional = { ...
                "bond_order_sums", obj.bond_order_sums; ...
                "spin_moments", obj.ddec_spin_moments; ...
                "dipoles", obj.dipoles; ...
                "rsquared_moments", obj.ddec_rsquared_moments; ...
                "rcubed_moments", obj.ddec_rcubed_moments; ...
                "rfourth_moments", obj.ddec_rfourth_moments; ...
                "bond_order_dict", obj.bond_order_dict};
            for index = 1:size(optional, 1)
                if ~isempty(optional{index, 2})
                    ddec.(optional{index, 1}) = optional{index, 2};
                end
            end
            if isempty(obj.cm5_charges)
                cm5 = [];
            else
                cm5 = struct("partial_charges", obj.cm5_charges);
            end
            value = struct("ddec", ddec, "cm5", cm5);
        end
    end

    methods (Static)
        function filepath = get_filepath(path, filename, suffix)
            if nargin < 3, suffix = ""; end
            if string(filename) == "POTCAR"
                pattern = string(filename) + "*";
            else
                pattern = string(filename) + string(suffix) + "*";
            end
            matches = dir(fullfile(string(path), pattern));
            matches = matches(~[matches.isdir]);
            if isempty(matches)
                filepath = "";
                return;
            end
            names = sort(string({matches.name}), "descend");
            filepath = absolutePath(fullfile(string(path), names(1)));
        end
    end

    methods (Access = private)
        function readVaspInputs(obj)
            if strlength(obj.chgcar_path) > 0
                obj.chgcar = ...
                    kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                    from_file(obj.chgcar_path);
                obj.structure = obj.chgcar.structure;
                obj.natoms = reshape(double(obj.chgcar.poscar.natoms), ...
                    1, []);
            end
            if strlength(obj.potcar_path) > 0
                potcar = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                    from_file(obj.potcar_path);
                obj.nelect = zeros(1, potcar.count);
                for index = 1:potcar.count
                    obj.nelect(index) = potcar(index).nelectrons;
                end
            end
            if strlength(obj.aeccar0_path) > 0
                obj.aeccar0 = ...
                    kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                    from_file(obj.aeccar0_path);
            end
            if strlength(obj.aeccar2_path) > 0
                obj.aeccar2 = ...
                    kssolv.analysis.matgenlab.io.vasp.Chgcar. ...
                    from_file(obj.aeccar2_path);
            end
        end

        function outputPath = executeChargemol(obj, computeBondOrders)
            densities = obj.atomic_densities_path;
            if ismissing(densities)
                configured = string(getenv("DDEC6_ATOMIC_DENSITIES_DIR"));
                if strlength(configured) > 0, densities = configured; end
            elseif strlength(densities) == 0
                densities = string(pwd);
            end
            if ismissing(densities) || strlength(densities) == 0
                error("KSSOLV:Matgenlab:Chargemol:AtomicDensities", ...
                    "atomic_densities_path or " + ...
                    "DDEC6_ATOMIC_DENSITIES_DIR must be specified.");
            end
            if ~isfolder(densities)
                error("KSSOLV:Matgenlab:Chargemol:AtomicDensities", ...
                    "Atomic densities directory does not exist: %s", ...
                    densities);
            end
            request = struct( ...
                "command", obj.command, ...
                "vasp_directory", obj.vasp_dir, ...
                "run_directory", obj.run_dir, ...
                "chgcar_path", obj.chgcar_path, ...
                "potcar_path", obj.potcar_path, ...
                "aeccar0_path", obj.aeccar0_path, ...
                "aeccar2_path", obj.aeccar2_path, ...
                "job_control_text", obj.jobControlText( ...
                    densities, computeBondOrders));
            result = callExecutor(obj.executor, request);
            [status, stdout, stderr, outputPath] = ...
                normalizeExecutorResult(result, obj.run_dir, ...
                obj.vasp_dir);
            if status ~= 0
                error("KSSOLV:Matgenlab:Chargemol:Execution", ...
                    "Chargemol executor exited with status %d: %s " + ...
                    "(stdout: %s)", status, stderr, stdout);
            end
            if ~isfolder(outputPath)
                error("KSSOLV:Matgenlab:Chargemol:OutputDirectory", ...
                    "Executor output directory does not exist: %s", ...
                    outputPath);
            end
        end

        function text = jobControlText(obj, densities, computeBondOrders)
            logicalText = [".false.", ".true."];
            lines = strings(0, 1);
            if obj.net_charge ~= 0
                lines(end + 1:end + 3) = [ ...
                    "<net charge>"; string(obj.net_charge); ...
                    "</net charge>"];
            end
            lines(end + 1:end + 5) = [ ...
                "<periodicity along A, B, and C vectors>"; ...
                logicalText(double(obj.periodicity(1)) + 1); ...
                logicalText(double(obj.periodicity(2)) + 1); ...
                logicalText(double(obj.periodicity(3)) + 1); ...
                "</periodicity along A, B, and C vectors>"];
            densityPath = string(densities);
            if ~endsWith(densityPath, filesep)
                densityPath = densityPath + filesep;
            end
            lines(end + 1:end + 4) = [ ...
                ""; "<atomic densities directory complete path>"; ...
                densityPath; ...
                "</atomic densities directory complete path>"];
            lines(end + 1:end + 4) = [ ...
                ""; "<charge type>"; upper(obj.method); "</charge type>"];
            if computeBondOrders
                lines(end + 1:end + 4) = [ ...
                    ""; "<compute BOs>"; ".true."; "</compute BOs>"];
            end
            text = strjoin(lines, newline) + newline;
        end

        function parseOutputDirectory(obj, path)
            chargePath = fullfile(path, ...
                "DDEC6_even_tempered_net_atomic_charges.xyz");
            obj.ddec_charges = getDataFromXyz(chargePath);
            obj.dipoles = getDipoleInfo(chargePath);

            bondPath = fullfile(path, ...
                "DDEC6_even_tempered_bond_orders.xyz");
            if isfile(bondPath)
                obj.bond_order_sums = getDataFromXyz(bondPath);
                obj.bond_order_dict = getBondOrderInfo(bondPath);
            end
            spinPath = fullfile(path, ...
                "DDEC6_even_tempered_atomic_spin_moments.xyz");
            if isfile(spinPath)
                obj.ddec_spin_moments = getDataFromXyz(spinPath);
            end
            obj.ddec_rsquared_moments = optionalXyz(path, ...
                "DDEC_atomic_Rsquared_moments.xyz");
            obj.ddec_rcubed_moments = optionalXyz(path, ...
                "DDEC_atomic_Rcubed_moments.xyz");
            obj.ddec_rfourth_moments = optionalXyz(path, ...
                "DDEC_atomic_Rfourth_moments.xyz");
            analysisPath = fullfile(path, "VASP_DDEC_analysis.output");
            if isfile(analysisPath)
                obj.cm5_charges = getCm5Data(analysisPath);
            end
        end

        function validateAtomIndex(obj, atomIndex)
            if ~isscalar(atomIndex) || atomIndex ~= fix(atomIndex) || ...
                    atomIndex < 1 || atomIndex > numel(obj.ddec_charges)
                error("KSSOLV:Matgenlab:Chargemol:AtomIndex", ...
                    "atom_index must identify a parsed atom.");
            end
        end
    end
end

function path = absolutePath(path)
path = string(path);
if ~isfolder(path) && ~isfile(path)
    path = string(fullfile(pwd, path));
elseif ~startsWith(path, filesep)
    path = string(fullfile(pwd, path));
end
try
    path = string(char(java.io.File(char(path)).getCanonicalPath()));
catch
    path = string(path);
end
end

function result = callExecutor(executor, request)
count = nargin(executor);
if count == 1 || count < 0
    result = executor(request);
elseif count == 2
    result = executor(request, request.command);
else
    error("KSSOLV:Matgenlab:Chargemol:ExecutorSignature", ...
        "executor must accept one request argument or request and command.");
end
end

function [status, stdout, stderr, outputPath] = ...
        normalizeExecutorResult(result, runDir, vaspDir)
status = 0;
stdout = "";
stderr = "";
if ischar(result) || isstring(result)
    outputPath = string(result);
elseif isstruct(result)
    if isfield(result, "status"), status = double(result.status); end
    if isfield(result, "returncode")
        status = double(result.returncode);
    end
    if isfield(result, "stdout"), stdout = string(result.stdout); end
    if isfield(result, "stderr"), stderr = string(result.stderr); end
    if isfield(result, "output_path")
        outputPath = string(result.output_path);
    elseif isfield(result, "output_directory")
        outputPath = string(result.output_directory);
    elseif strlength(runDir) > 0
        outputPath = fullfile(vaspDir, runDir);
    else
        error("KSSOLV:Matgenlab:Chargemol:ExecutorResult", ...
            "Executor result must include output_path or " + ...
            "output_directory.");
    end
else
    error("KSSOLV:Matgenlab:Chargemol:ExecutorResult", ...
        "Executor must return a directory path or result struct.");
end
outputPath = absolutePath(outputPath);
end

function values = optionalXyz(path, filename)
filepath = fullfile(path, filename);
if isfile(filepath), values = getDataFromXyz(filepath);
else, values = zeros(1, 0);
end
end

function values = getDataFromXyz(filepath)
if ~isfile(filepath)
    error("KSSOLV:Matgenlab:Chargemol:MissingOutput", ...
        "%s not found.", string(filepath));
end
lines = splitlines(string(fileread(filepath)));
values = zeros(1, 0);
for index = 3:numel(lines)
    line = strtrim(lines(index));
    if strlength(line) == 0, break; end
    tokens = split(line);
    tokens(tokens == "") = [];
    number = str2double(tokens(end));
    if isnan(number)
        error("KSSOLV:Matgenlab:Chargemol:MalformedXYZ", ...
            "Malformed atomic-property row in %s.", string(filepath));
    end
    values(end + 1) = number; %#ok<AGROW>
end
end

function dipoles = getDipoleInfo(filepath)
lines = splitlines(string(fileread(filepath)));
marker = find(contains(lines, "The following XYZ"), 1);
if isempty(marker), dipoles = zeros(0, 3); return; end
dipoles = zeros(0, 3);
for index = marker + 2:numel(lines)
    line = strtrim(lines(index));
    if strlength(line) == 0, break; end
    tokens = split(line);
    tokens(tokens == "") = [];
    if numel(tokens) < 9
        error("KSSOLV:Matgenlab:Chargemol:MalformedDipoles", ...
            "Malformed dipole row in %s.", string(filepath));
    end
    dipoles(end + 1, :) = str2double(tokens(7:9)); %#ok<AGROW>
end
end

function dictionary = getBondOrderInfo(filepath)
lines = splitlines(string(fileread(filepath)));
dictionary = cell(1, 0);
current = 0;
emptyBond = struct("index", {}, "element", {}, "bond_order", {}, ...
    "direction", {}, "spin_polarization", {});
for line = reshape(lines, 1, [])
    header = regexp(line, ...
        "Printing BOs for ATOM #\s*(\d+)\s*\(\s*([A-Za-z]+)\s*\)", ...
        "tokens", "once");
    if ~isempty(header)
        current = str2double(header{1});
        dictionary{current} = struct( ...
            "element", ...
            kssolv.analysis.matgenlab.core.Element(header{2}), ...
            "bonded_to", emptyBond);
        continue;
    end
    bond = regexp(line, ...
        "Bonded to the \(\s*([-+]?\d+),\s*([-+]?\d+),\s*" + ...
        "([-+]?\d+)\)\s*translated image of atom number\s*(\d+)" + ...
        "\s*\(\s*([A-Za-z]+)\s*\).*bond order =\s*" + ...
        "([-+0-9.Ee]+).*bonding =\s*([-+0-9.Ee]+)", ...
        "tokens", "once");
    if ~isempty(bond)
        if current == 0
            error("KSSOLV:Matgenlab:Chargemol:MalformedBondOrder", ...
                "Bond entry precedes atom header in %s.", filepath);
        end
        entry = struct( ...
            "index", str2double(bond{4}), ...
            "element", ...
            kssolv.analysis.matgenlab.core.Element(bond{5}), ...
            "bond_order", str2double(bond{6}), ...
            "direction", str2double(bond(1:3)), ...
            "spin_polarization", str2double(bond{7}));
        dictionary{current}.bonded_to(end + 1) = entry;
        continue;
    end
    total = regexp(line, ...
        "The sum of bond orders for this atom.*=\s*([-+0-9.Ee]+)", ...
        "tokens", "once");
    if ~isempty(total) && current > 0
        dictionary{current}.bond_order_sum = str2double(total{1});
    end
end
end

function values = getCm5Data(filepath)
lines = splitlines(string(fileread(filepath)));
active = false;
values = zeros(1, 0);
for line = reshape(lines, 1, [])
    if contains(line, "computed CM5")
        active = true;
        continue;
    end
    if contains(line, "Hirshfeld and CM5"), break; end
    if active
        parsed = sscanf(char(line), "%f").';
        values = [values, parsed]; %#ok<AGROW>
    end
end
end
