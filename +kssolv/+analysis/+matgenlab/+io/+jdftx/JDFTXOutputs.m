classdef JDFTXOutputs
    %JDFTXOUTPUTS Aggregate JDFTx outfile and binary/text dump data.
    properties
        calc_dir string = ""
        outfile_name = []
        store_vars string = strings(0, 1)
        paths struct = struct()
        outfile = []
        bandProjections = []
        eigenvals = []
        kpts = []
        wk_list = []
        orb_label_list string = strings(0, 1)
        bandstructure = []
    end
    methods
        function obj = JDFTXOutputs(calc_dir, options)
            arguments
                calc_dir = ""
                options.store_vars = strings(0, 1)
                options.outfile_name = []
            end
            obj.calc_dir = string(calc_dir);
            obj.store_vars = unique(string(options.store_vars));
            obj.outfile_name = options.outfile_name;
            if strlength(obj.calc_dir) > 0
                obj = obj.initialize();
            end
        end
    end

    methods (Static)
        function obj = from_calc_dir(calc_dir, options)
            arguments
                calc_dir
                options.store_vars = strings(0, 1)
                options.outfile_name = []
            end
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXOutputs( ...
                calc_dir, store_vars = options.store_vars, ...
                outfile_name = options.outfile_name);
        end
    end

    methods (Access = private)
        function obj = initialize(obj)
            if ~isfolder(obj.calc_dir)
                error("KSSOLV:Matgenlab:JDFTX:MissingDirectory", ...
                    "Calculation directory '%s' does not exist.", obj.calc_dir);
            end
            if isempty(obj.outfile_name)
                candidates = [dir(fullfile(obj.calc_dir, "*.out")); ...
                    dir(fullfile(obj.calc_dir, "out"))];
                candidates = candidates(~[candidates.isdir]);
                if numel(candidates) ~= 1
                    error("KSSOLV:Matgenlab:JDFTX:OutfileResolution", ...
                        "Expected exactly one output file.");
                end
                outfile_path = fullfile(candidates(1).folder, ...
                    candidates(1).name);
            else
                outfile_path = fullfile(obj.calc_dir, obj.outfile_name);
            end
            obj.outfile = kssolv.analysis.matgenlab.io.jdftx. ...
                JDFTXOutfile.from_file(outfile_path);
            dump_names = ["bandProjections", "eigenvals", "kPts"];
            for name = dump_names
                candidates = [dir(fullfile(obj.calc_dir, "*." + name)); ...
                    dir(fullfile(obj.calc_dir, name))];
                candidates = candidates(~[candidates.isdir]);
                if ~isempty(candidates)
                    field = matlab.lang.makeValidName(name);
                    obj.paths.(field) = fullfile(candidates(1).folder, ...
                        candidates(1).name);
                end
            end
            requested = obj.store_vars;
            if any(requested == "bandstructure")
                requested = unique([requested(:); "eigenvals"; "kpts"]);
            end
            if any(requested == "bandProjections")
                obj = obj.store_band_projections();
            end
            if any(requested == "eigenvals")
                obj = obj.store_eigenvalues();
            end
            if any(requested == "kpts")
                obj = obj.store_kpoints();
            end
            if any(obj.store_vars == "bandstructure") && ...
                    ~isempty(obj.eigenvals) && ~isempty(obj.kpts)
                obj.bandstructure = struct("kpoints", obj.kpts, ...
                    "eigenvalues", obj.eigenvals, ...
                    "projections", obj.bandProjections, ...
                    "efermi", obj.outfile.efermi, ...
                    "structure", obj.outfile.structure);
            end
        end

        function obj = store_band_projections(obj)
            if ~isfield(obj.paths, "bandProjections")
                error("KSSOLV:Matgenlab:JDFTX:MissingBandProjections", ...
                    "bandProjections dump is unavailable.");
            end
            path = string(obj.paths.bandProjections);
            obj.bandProjections = kssolv.analysis.matgenlab.io.jdftx. ...
                get_proj_tju_from_file(path);
            obj.orb_label_list = orbital_labels(path);
        end

        function obj = store_eigenvalues(obj)
            if ~isfield(obj.paths, "eigenvals")
                error("KSSOLV:Matgenlab:JDFTX:MissingEigenvalues", ...
                    "eigenvals dump is unavailable.");
            end
            handle = fopen(obj.paths.eigenvals, "rb");
            if handle < 0
                error("KSSOLV:Matgenlab:JDFTX:ReadFailed", ...
                    "Unable to read eigenvals.");
            end
            cleanup = onCleanup(@() fclose(handle));
            values = fread(handle, Inf, "double=>double");
            nbands = obj.outfile.nbands;
            if mod(numel(values), nbands) ~= 0
                error("KSSOLV:Matgenlab:JDFTX:EigenvalueShape", ...
                    "Eigenvalue count is not a multiple of band count.");
            end
            obj.eigenvals = reshape(values, nbands, []).' * ...
                27.21138624598059;
        end

        function obj = store_kpoints(obj)
            if ~isfield(obj.paths, "bandProjections")
                error("KSSOLV:Matgenlab:JDFTX:MissingKpoints", ...
                    "K-points require bandProjections metadata.");
            end
            lines = string(kssolv.analysis.matgenlab.io.jdftx. ...
                read_file(string(obj.paths.bandProjections)));
            hits = find(startsWith(strtrim(lines), "#") & contains(lines, ";"));
            points = zeros(numel(hits), 3);
            weights = zeros(numel(hits), 1);
            for idx = 1:numel(hits)
                token = regexp(lines(hits(idx)), ...
                    "\[\s*(.*?)\s*\]\s*([-+0-9.Ee]+)", ...
                    "tokens", "once");
                points(idx, :) = sscanf(token{1}, "%f").';
                weights(idx) = str2double(token{2});
            end
            obj.kpts = points;
            obj.wk_list = weights;
        end
    end
end

function labels = orbital_labels(path)
lines = string(kssolv.analysis.matgenlab.io.jdftx.read_file(path));
header = regexp(lines(1), "(\d+) species", "tokens", "once");
nspecies = str2double(header{1});
orbital_sets = {"s", ["py", "pz", "px"], ...
    ["dxy", "dyz", "dz2", "dxz", "dx2-y2"], ...
    ["fy(3x2-y2)", "fxyz", "fyz2", "fz3", ...
    "fxz2", "fz(x2-y2)", "fx(x2-3y2)"]};
labels = strings(0, 1);
for idx = 1:nspecies
    tokens = regexp(strtrim(lines(idx + 2)), "\s+", "split");
    symbol = tokens(1);
    count = str2double(tokens(2));
    lmax = str2double(tokens(4));
    atom_orbs = strings(0, 1);
    for ell = 0:lmax
        shells = str2double(tokens(5 + ell));
        base = orbital_sets{ell + 1};
        for shell = 1:shells
            if shells > 1
                atom_orbs = [atom_orbs; string(shell - 1) + base(:)]; %#ok<AGROW>
            else
                atom_orbs = [atom_orbs; base(:)]; %#ok<AGROW>
            end
        end
    end
    for atom = 1:count
        labels = [labels; symbol + "#" + atom + "(" + atom_orbs + ")"]; %#ok<AGROW>
    end
end
end
