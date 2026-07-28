classdef BoltztrapRunner < kssolv.analysis.matgenlab.util.MSONable
    %BOLTZTRAPRUNNER Write classic BoltzTraP inputs and invoke x_trans.

    properties
        lpfac (1,1) double = 10
        dos_type (1,1) string = "HISTO"
        energy_grid (1,1) double = 0.005
        error cell = cell(1, 0)
        run_type (1,1) string = "BOLTZ"
        band_nb = []
        spin = []
        cond_band (1,1) logical = false
        tauref (1,1) double = 0
        tauexp (1,1) double = 0
        tauen (1,1) double = 0
        soc (1,1) logical = false
        kpt_line = []
        cb_cut (1,1) double = 0.1
        doping double = []
        energy_span_around_fermi (1,1) double = 1.5
        scissor (1,1) double = 0
        tmax (1,1) double = 1300
        tgrid (1,1) double = 50
        symprec = 1e-3
        timeout (1,1) double = 7200
        executable (1,1) string = "x_trans"
    end

    properties (SetAccess = private)
        bs
        nelec (1,1) double
    end

    methods
        function obj = BoltztrapRunner(bs, nelec, varargin)
            obj.bs = bs;
            obj.nelec = double(nelec);
            options = runnerOptions(varargin{:});
            names = fieldnames(options);
            for index = 1:numel(names)
                obj.(names{index}) = options.(names{index});
            end
            obj.cb_cut = obj.cb_cut / 100;
            if isempty(obj.doping)
                levels = [1, 2.5, 5, 7.5].' * 10.^(16:21);
                obj.doping = [levels(:).', 1e22];
            end
            if any(obj.run_type == ["DOS", "BANDS"])
                obj.autoEnergyRange();
            end
        end

        function write_energy(obj, filename)
            file = fopen(filename, "w");
            assertFile(file, filename);
            cleanup = onCleanup(@() fclose(file));
            fprintf(file, "test\n%d\n", numel(obj.bs.kpoints));
            bandCount = floor(obj.bs.nb_bands * (1 - obj.cb_cut));
            for pointIndex = 1:numel(obj.bs.kpoints)
                point = obj.bs.kpoints{pointIndex}.frac_coords;
                if obj.run_type == "FERMI"
                    spinName = spinField(obj.spin);
                    values = obj.bs.bands.(spinName)( ...
                        obj.band_nb + indexOffset(obj.band_nb), pointIndex);
                    values = (values - obj.bs.efermi) / ryToEv();
                    if obj.cond_band, values = -values; end
                else
                    if obj.run_type == "DOS"
                        spinNames = {spinField(obj.spin)};
                    else
                        spinNames = fieldnames(obj.bs.bands);
                    end
                    values = zeros(1, bandCount * numel(spinNames));
                    offset = 0;
                    for spinIndex = 1:numel(spinNames)
                        values(offset+(1:bandCount)) = ...
                            (obj.bs.bands.(spinNames{spinIndex})( ...
                            1:bandCount, pointIndex) - obj.bs.efermi) / ...
                            ryToEv();
                        offset = offset + bandCount;
                    end
                    values = sort(values);
                end
                fprintf(file, "%12.8f %12.8f %12.8f %d\n", ...
                    point, numel(values));
                fprintf(file, "%18.8f\n", values);
            end
        end

        function write_struct(obj, filename)
            if isempty(obj.symprec)
                symbol = "symmetries disabled";
                rotations = reshape(eye(3), 3, 3, 1);
            else
                analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(obj.bs.structure, obj.symprec);
                symbol = analyzer.get_space_group_symbol();
                dataset = analyzer.get_symmetry_dataset();
                rotations = dataset.rotations;
                if size(rotations, 1) ~= 3 || size(rotations, 2) ~= 3
                    rotations = permute(rotations, [2, 3, 1]);
                end
            end
            file = fopen(filename, "w");
            assertFile(file, filename);
            cleanup = onCleanup(@() fclose(file));
            fprintf(file, "%s %s\n", ...
                obj.bs.structure.composition.formula, symbol);
            fprintf(file, "%.5f %.5f %.5f\n", ...
                (obj.bs.structure.lattice.matrix / bohrAngstrom()).');
            fprintf(file, "%d\n", size(rotations, 3));
            for index = 1:size(rotations, 3)
                fprintf(file, "%d %d %d\n", rotations(:, :, index).');
            end
        end

        function write_def(obj, filename)
            suffix = "";
            if obj.bs.is_spin_polarized || obj.soc, suffix = "so"; end
            lines = {
                "5, 'boltztrap.intrans', 'old', 'formatted',0"
                "6, 'boltztrap.outputtrans', 'unknown', 'formatted',0"
                "20, 'boltztrap.struct', 'old', 'formatted',0"
                "10, 'boltztrap.energy" + suffix + "', 'old', 'formatted',0"
                "48, 'boltztrap.engre', 'unknown', 'unformatted',0"
                "49, 'boltztrap.transdos', 'unknown', 'formatted',0"
                "50, 'boltztrap.sigxx', 'unknown', 'formatted',0"
                "51, 'boltztrap.sigxxx', 'unknown', 'formatted',0"
                "21, 'boltztrap.trace', 'unknown', 'formatted',0"
                "22, 'boltztrap.condtens', 'unknown', 'formatted',0"
                "24, 'boltztrap.halltens', 'unknown', 'formatted',0"
                "30, 'boltztrap_BZ.cube', 'unknown', 'formatted',0"};
            writeLines(filename, lines);
        end

        function write_proj(obj, projectionPrefix, definitionFile)
            if isempty(fieldnames(obj.bs.projections))
                builtin("error", "KSSOLV:Matgenlab:Boltztrap:Projections", ...
                    "Band structure has no projections.");
            end
            spinName = spinField(obj.spin);
            source = obj.bs.projections.(spinName);
            orbitals = ["s","py","pz","px","dxy","dyz", ...
                "dz2","dxz","dx2"];
            bandCount = floor(obj.bs.nb_bands * (1 - obj.cb_cut));
            orbitalCount = min(size(source, 3), numel(orbitals));
            definitionLines = strings(orbitalCount * size(source, 4), 1);
            definitionIndex = 0;
            unit = 1000;
            for orbital = 1:orbitalCount
                for site = 1:size(source, 4)
                    filename = sprintf("%s_%d_%s", projectionPrefix, ...
                        site - 1, orbitals(orbital));
                    file = fopen(filename, "w");
                    assertFile(file, filename);
                    fprintf(file, "%s\n%d\n", ...
                        obj.bs.structure.composition.formula, ...
                        numel(obj.bs.kpoints));
                    for pointIndex = 1:numel(obj.bs.kpoints)
                        point = obj.bs.kpoints{pointIndex}.frac_coords;
                        values = source(1:bandCount, pointIndex, ...
                            orbital, site);
                        fprintf(file, "%12.8f %12.8f %12.8f %d\n", ...
                            point, numel(values));
                        fprintf(file, "%18.8f\n", values);
                    end
                    fclose(file);
                    definitionIndex = definitionIndex + 1;
                    definitionLines(definitionIndex) = sprintf( ...
                        "%d,'%s','old','formatted',0", unit, filename);
                    unit = unit + 1;
                end
            end
            obj.write_def(definitionFile);
            file = fopen(definitionFile, "a");
            assertFile(file, definitionFile);
            cleanup = onCleanup(@() fclose(file));
            fprintf(file, "%s\n", definitionLines);
        end

        function write_intrans(obj, filename)
            setGap = double(obj.scissor > 1e-4);
            if any(obj.run_type == ["BOLTZ", "DOS"])
                lines = [
                    "GENE          # use generic interface"
                    sprintf("1 0 %d %.12g # iskip idebug setgap shiftgap", ...
                    setGap, obj.scissor / ryToEv())
                    sprintf("0.0 %.12g %.12g %.1f # EF grid span nelec", ...
                    obj.energy_grid / ryToEv(), ...
                    obj.energy_span_around_fermi / ryToEv(), obj.nelec)
                    "CALC"
                    string(obj.lpfac)
                    obj.run_type
                    ".15"
                    sprintf("%g %g", obj.tmax, obj.tgrid)
                    "-1."
                    obj.dos_type
                    sprintf("%.12g %.12g %.12g 0 0 0", ...
                    obj.tauref, obj.tauexp, obj.tauen)
                    string(2 * numel(obj.doping))
                    string(obj.doping(:))
                    string(-obj.doping(:))];
            elseif obj.run_type == "FERMI"
                lines = [
                    "GENE"
                    "1 0 0 0.0"
                    sprintf("0.0 %.12g 0.1 %.1f", ...
                    obj.energy_grid / ryToEv(), obj.nelec)
                    "CALC"
                    string(obj.lpfac)
                    "FERMI"
                    "1"];
            elseif obj.run_type == "BANDS"
                if isempty(obj.kpt_line)
                    path = kssolv.analysis.matgenlab.symmetry. ...
                        HighSymmKpath(obj.bs.structure);
                    [obj.kpt_line, ~] = path.get_kpoints(20, false);
                end
                headerLines = [
                    "GENE"
                    sprintf("1 0 %d %.12g", setGap, ...
                    obj.scissor / ryToEv())
                    sprintf("0.0 %.12g %.12g %.1f", ...
                    obj.energy_grid / ryToEv(), ...
                    obj.energy_span_around_fermi / ryToEv(), obj.nelec)
                    "CALC"
                    string(obj.lpfac)
                    "BANDS"
                    sprintf("P %d", size(obj.kpt_line, 1))];
                lines = strings(numel(headerLines) + ...
                    size(obj.kpt_line, 1), 1);
                lines(1:numel(headerLines)) = headerLines;
                for index = 1:size(obj.kpt_line, 1)
                    lines(numel(headerLines) + index) = sprintf( ...
                        "%.12g %.12g %.12g", ...
                        obj.kpt_line(index, :));
                end
            else
                builtin("error", "KSSOLV:Matgenlab:Boltztrap:RunType", ...
                    "Unknown run type '%s'.", obj.run_type);
            end
            writeLines(filename, lines);
        end

        function write_input(obj, directory)
            if ~isfolder(directory), mkdir(directory); end
            suffix = ""; if obj.bs.is_spin_polarized || obj.soc, suffix = "so"; end
            obj.write_energy(fullfile(directory, ...
                "boltztrap.energy" + suffix));
            obj.write_struct(fullfile(directory, "boltztrap.struct"));
            obj.write_intrans(fullfile(directory, "boltztrap.intrans"));
            obj.write_def(fullfile(directory, "BoltzTraP.def"));
            if obj.run_type == "DOS" && ...
                    ~isempty(fieldnames(obj.bs.projections))
                obj.write_proj(fullfile(directory, "boltztrap.proj"), ...
                    fullfile(directory, "BoltzTraP.def"));
            end
        end

        function directory = run(obj, pathDirectory, varargin)
            options = runOptions(varargin{:});
            if options.convergence && ~options.write_input
                builtin("error", ...
                    "KSSOLV:Matgenlab:Boltztrap:ConvergenceInput", ...
                    "Convergence mode requires write_input=true.");
            end
            if any(obj.run_type == ["BANDS", "DOS", "FERMI"])
                options.convergence = false;
            end
            if nargin < 2 || isempty(pathDirectory)
                base = tempname;
                mkdir(base);
            else
                base = char(pathDirectory);
                if ~isfolder(base), mkdir(base); end
            end
            directory = fullfile(base, "boltztrap");
            if ~isfolder(directory), mkdir(directory); end
            if options.clear_dir
                files = dir(directory);
                files = files(~[files.isdir]);
                for index = 1:numel(files)
                    delete(fullfile(directory, files(index).name));
                end
            end
            executablePath = resolveExecutable(obj.executable);
            started = tic;
            initialLpfac = obj.lpfac;
            converged = false;
            while obj.energy_grid >= options.min_egrid && ~converged
                obj.lpfac = initialLpfac;
                while obj.lpfac <= options.max_lpfac && ~converged
                    if toc(started) > obj.timeout
                        kssolv.analysis.matgenlab.electronic_structure. ...
                            BoltztrapError.throw( ...
                            "BoltzTraP exceeded timeout.");
                    end
                    if options.write_input, obj.write_input(directory); end
                    command = sprintf('cd "%s" && "%s" BoltzTraP', ...
                        directory, executablePath);
                    if obj.bs.is_spin_polarized || obj.soc
                        command = command + " -so";
                    end
                    [status, output] = system(command);
                    if status ~= 0
                        kssolv.analysis.matgenlab.electronic_structure. ...
                            BoltztrapError.throw( ...
                            "BoltzTraP failed: %s", output);
                    end
                    if contains(output, "error in factorization", ...
                            "IgnoreCase", true)
                        kssolv.analysis.matgenlab.electronic_structure. ...
                            BoltztrapError.throw( ...
                            "BoltzTraP factorization failed.");
                    end
                    warningText = outputWarning(directory);
                    if strlength(warningText) == 0 || ...
                            ~options.convergence
                        converged = true;
                    else
                        obj.lpfac = obj.lpfac + 10;
                    end
                end
                if ~converged, obj.energy_grid = obj.energy_grid / 10; end
            end
            if ~converged
                kssolv.analysis.matgenlab.electronic_structure. ...
                    BoltztrapError.throw( ...
                    "Doping convergence was not reached.");
            end
        end

        function value = as_dict(obj)
            value = struct("x_module", ...
                "pymatgen.electronic_structure.boltztrap", ...
                "x_class", "BoltztrapRunner", "lpfac", obj.lpfac, ...
                "bs", obj.bs.as_dict(), "nelec", obj.nelec, ...
                "dos_type", obj.dos_type, "run_type", obj.run_type, ...
                "band_nb", obj.band_nb, "spin", obj.spin, ...
                "cond_band", obj.cond_band, "tauref", obj.tauref, ...
                "tauexp", obj.tauexp, "tauen", obj.tauen, ...
                "soc", obj.soc, "kpt_line", obj.kpt_line, ...
                "doping", obj.doping, ...
                "energy_span_around_fermi", ...
                obj.energy_span_around_fermi, "scissor", obj.scissor, ...
                "tmax", obj.tmax, "tgrid", obj.tgrid, ...
                "symprec", obj.symprec);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Access = private)
        function autoEnergyRange(obj)
            values = [];
            names = fieldnames(obj.bs.bands);
            for index = 1:numel(names)
                values = [values; obj.bs.bands.(names{index})(:)]; %#ok<AGROW>
            end
            span = max(abs([min(values), max(values)] - obj.bs.efermi)) + 2;
            obj.energy_span_around_fermi = span * 1.01;
        end
    end
end

function options = runnerOptions(varargin)
options = struct("dos_type", "HISTO", "energy_grid", 0.005, ...
    "lpfac", 10, "run_type", "BOLTZ", "band_nb", [], ...
    "tauref", 0, "tauexp", 0, "tauen", 0, "soc", false, ...
    "doping", [], "energy_span_around_fermi", 1.5, "scissor", 0, ...
    "kpt_line", [], "spin", [], "cond_band", false, "tmax", 1300, ...
    "tgrid", 50, "symprec", 1e-3, "cb_cut", 10, ...
    "timeout", 7200, "executable", "x_trans");
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function options = runOptions(varargin)
options = struct("convergence", true, "write_input", true, ...
    "clear_dir", false, "max_lpfac", 150, "min_egrid", 0.00005);
for index = 1:2:numel(varargin)
    options.(char(varargin{index})) = varargin{index + 1};
end
end

function field = spinField(spin)
if isempty(spin) || double(spin) > 0, field = "up"; else, field = "down"; end
field = char(field);
end

function value = indexOffset(index)
value = double(index == 0);
end

function value = resolveExecutable(executable)
executable = char(executable);
if contains(executable, filesep) && isfile(executable)
    value = executable;
    return
end
[status, output] = system(sprintf('command -v "%s"', executable));
if status ~= 0
    kssolv.analysis.matgenlab.electronic_structure. ...
        BoltztrapError.throw("External runner boundary: executable " + ...
        "'%s' was not found. Configure BoltztrapRunner.executable.", ...
        executable);
end
value = strtrim(output);
end

function value = outputWarning(directory)
filename = fullfile(directory, "boltztrap.outputtrans");
if ~isfile(filename), value = "missing outputtrans"; return; end
text = string(fileread(filename));
expressions = ["WARNING", "Error - Fermi level was not found"];
value = "";
for expression = expressions
    if contains(text, expression)
        value = expression;
        return
    end
end
end

function writeLines(filename, lines)
file = fopen(filename, "w");
assertFile(file, filename);
cleanup = onCleanup(@() fclose(file));
fprintf(file, "%s\n", string(lines));
end

function assertFile(file, filename)
if file < 0
    error("KSSOLV:Matgenlab:Boltztrap:File", ...
        "Cannot open '%s' for writing.", filename);
end
end

function value = ryToEv()
value = 13.605693122994;
end

function value = bohrAngstrom()
value = 0.529177210903;
end
