classdef QChemDictSet < kssolv.analysis.matgenlab.io.qchem.QCInput
    %QCHEMDICTSET Recommended Q-Chem defaults with controlled overrides.
    properties
        job_type = "sp"
        basis_set = "def2-tzvpd"
        scf_algorithm = "diis"
        qchem_version = 5
        dft_rung = 4
        pcm_dielectric = []
        isosvp_dielectric = []
        smd_solvent = []
        cmirs_solvent = []
        custom_smd = []
    end
    methods
        function obj = QChemDictSet(molecule, jobType, basisSet, scfAlgorithm, varargin)
            obj@kssolv.analysis.matgenlab.io.qchem.QCInput();
            if nargin == 0
                return
            end
            defaults = struct("qchem_version", 5, "dft_rung", 4, ...
                "pcm_dielectric", [], "isosvp_dielectric", [], ...
                "smd_solvent", [], "cmirs_solvent", [], "custom_smd", [], ...
                "opt_variables", [], "scan_variables", [], ...
                "max_scf_cycles", 100, "geom_opt_max_cycles", 200, ...
                "plot_cubes", false, "output_wavefunction", false, ...
                "nbo_params", [], "geom_opt", [], "cdft_constraints", [], ...
                "almo_coupling_states", [], "overwrite_inputs", [], ...
                "vdw_mode", "atomic", "extra_scf_print", false, ...
                "basis_set", basisSet, "scf_algorithm", scfAlgorithm);
            options = kssolv.analysis.matgenlab.io.qchem.QChemDictSet.parse_options(defaults, varargin);
            obj.job_type = string(jobType);
            obj.basis_set = string(options.basis_set);
            obj.scf_algorithm = string(options.scf_algorithm);
            obj.qchem_version = options.qchem_version;
            obj.dft_rung = options.dft_rung;
            obj.pcm_dielectric = options.pcm_dielectric;
            obj.isosvp_dielectric = options.isosvp_dielectric;
            obj.smd_solvent = options.smd_solvent;
            obj.cmirs_solvent = options.cmirs_solvent;
            obj.custom_smd = options.custom_smd;
            methodNames = ["spw92", "b97-d3", "b97mv", "wb97mv", "wb97m(2)"];
            if options.dft_rung < 1 || options.dft_rung > 5
                error("KSSOLV:Matgenlab:QChem:DFTRung", "dft_rung must be between 1 and 5.");
            end
            rem = struct("job_type", char(lower(string(jobType))), ...
                "basis", char(lower(obj.basis_set)), ...
                "max_scf_cycles", char(string(options.max_scf_cycles)), ...
                "gen_scfman", "true", "xc_grid", "3", "thresh", "14", ...
                "s2thresh", "16", "scf_algorithm", char(lower(obj.scf_algorithm)), ...
                "resp_charges", "true", "symmetry", "false", "sym_ignore", "true", ...
                "method", char(methodNames(options.dft_rung)));
            if options.dft_rung == 2, rem.dft_d = "d3_bj"; end
            if any(lower(string(jobType)) == ["opt", "ts", "pes_scan"])
                rem.geom_opt_max_cycles = char(string(options.geom_opt_max_cycles));
            end
            if options.output_wavefunction, rem.write_wfn = "wavefunction"; end
            pcm = []; solvent = []; smx = []; svp = []; pcmNonels = []; plots = [];
            solventCount = sum([~isempty(options.pcm_dielectric), ...
                ~isempty(options.isosvp_dielectric), ~isempty(options.smd_solvent), ...
                ~isempty(options.cmirs_solvent)]);
            if solventCount > 1
                error("KSSOLV:Matgenlab:QChem:Solvation", ...
                    "Only one of PCM, ISOSVP, SMD, and CMIRS may be used.");
            end
            if ~isempty(options.pcm_dielectric)
                pcm = struct("heavypoints", "194", "hpoints", "194", ...
                    "radii", "uff", "theory", "cpcm", "vdwscale", "1.1");
                solvent = struct("dielectric", char(string(options.pcm_dielectric)));
                rem.solvent_method = "pcm";
            elseif ~isempty(options.isosvp_dielectric)
                svp = struct("rhoiso", "0.001", "nptleb", "1202", ...
                    "itrngr", "2", "irotgr", "2", ...
                    "dielst", char(string(options.isosvp_dielectric)));
                rem.solvent_method = "isosvp"; rem.gen_scfman = "false";
            elseif ~isempty(options.smd_solvent)
                solventName = lower(string(options.smd_solvent));
                if any(solventName == ["custom", "other"]), outputName = "other";
                else, outputName = solventName; end
                smx = struct("solvent", char(outputName));
                rem.solvent_method = "smd"; rem.ideriv = "1";
                if outputName == "other" && isempty(options.custom_smd)
                    error("KSSOLV:Matgenlab:QChem:CustomSMD", ...
                        "A user-defined SMD solvent requires custom_smd parameters.");
                end
                if outputName == "other" && options.qchem_version == 6
                    tokens = split(string(options.custom_smd), ",");
                    if numel(tokens) ~= 7
                        error("KSSOLV:Matgenlab:QChem:CustomSMD", ...
                            "custom_smd must contain seven comma-separated values.");
                    end
                    fields = {"epsilon", "SolN", "SolA", "SolB", "SolG", "SolC", "SolH"};
                    for index = 1:7, smx.(fields{index}) = char(tokens(index)); end
                end
            elseif ~isempty(options.cmirs_solvent)
                [svp, pcmNonels] = ...
                    kssolv.analysis.matgenlab.io.qchem.QChemDictSet.cmirs(options.cmirs_solvent);
                rem.solvent_method = "isosvp"; rem.gen_scfman = "false";
            end
            if options.plot_cubes
                plots = struct("grid_spacing", "0.05", "total_density", "0");
                rem.plots = "true"; rem.make_cube_files = "true";
            end
            nbo = options.nbo_params;
            if ~isempty(nbo)
                rem.nbo = "true";
                if isfield(nbo, "version")
                    if str2double(string(nbo.version)) ~= 7
                        error("KSSOLV:Matgenlab:QChem:NBO", "NBO version must be 7.");
                    end
                    rem.nbo_external = "true"; nbo = rmfield(nbo, "version");
                end
            end
            geomOpt = options.geom_opt;
            if (lower(string(jobType)) == "opt" && options.qchem_version == 6) || ...
                    (options.qchem_version == 5 && ~isempty(geomOpt))
                if isempty(geomOpt), geomOpt = struct(); end
                geomOpt.maxiter = char(string(options.geom_opt_max_cycles));
                if options.qchem_version == 5, rem.geom_opt2 = "3";
                else
                    if ~isfield(geomOpt, "coordinates"), geomOpt.coordinates = "redundant"; end
                    if ~isfield(geomOpt, "max_displacement"), geomOpt.max_displacement = "0.1"; end
                    if ~isfield(geomOpt, "optimization_restart"), geomOpt.optimization_restart = "false"; end
                end
            end
            opt = options.opt_variables; scan = options.scan_variables; vdw = [];
            sections = struct("rem", rem, "pcm", pcm, "solvent", solvent, ...
                "smx", smx, "opt", opt, "scan", scan, "van_der_waals", vdw, ...
                "plots", plots, "svp", svp, "pcm_nonels", pcmNonels);
            if ~isempty(options.overwrite_inputs)
                overwriteNames = fieldnames(options.overwrite_inputs);
                for sectionIndex = 1:numel(overwriteNames)
                    section = overwriteNames{sectionIndex};
                    incoming = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique( ...
                        options.overwrite_inputs.(section));
                    if ~isfield(sections, section)
                        error("KSSOLV:Matgenlab:QChem:Overwrite", ...
                            "Unsupported overwrite section '%s'.", section);
                    end
                    sections.(section) = ...
                        kssolv.analysis.matgenlab.io.qchem.QChemDictSet.merge( ...
                        sections.(section), incoming);
                    if strcmp(section, "van_der_waals")
                        sections.pcm = kssolv.analysis.matgenlab.io.qchem.QChemDictSet.merge( ...
                            sections.pcm, struct("radii", "read"));
                    end
                end
            end
            if options.extra_scf_print
                sections.rem.scf_final_print = "3";
                if ~isfield(sections.rem, "scf_convergence") || ...
                        str2double(string(sections.rem.scf_convergence)) < 8
                    sections.rem.scf_convergence = "8";
                end
            end
            obj.molecule = molecule;
            obj.rem = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(sections.rem);
            obj.opt = sections.opt;
            obj.pcm = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(sections.pcm);
            obj.solvent = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(sections.solvent);
            obj.smx = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(sections.smx);
            obj.scan = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(sections.scan);
            obj.van_der_waals = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique( ...
                sections.van_der_waals);
            obj.vdw_mode = string(options.vdw_mode);
            obj.plots = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(sections.plots);
            obj.nbo = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(nbo);
            obj.geom_opt = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(geomOpt);
            obj.cdft = options.cdft_constraints;
            obj.almo_coupling = options.almo_coupling_states;
            obj.svp = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique(sections.svp);
            obj.pcm_nonels = kssolv.analysis.matgenlab.io.qchem.lower_and_check_unique( ...
                sections.pcm_nonels);
        end

        function write(obj, inputFile)
            obj.write_file(inputFile);
            if any(lower(string(obj.smd_solvent)) == ["custom", "other"]) && obj.qchem_version == 5
                sidecar = fullfile(fileparts(char(inputFile)), "solvent_data");
                fid = fopen(sidecar, "w", "n", "UTF-8");
                if fid < 0, error("KSSOLV:Matgenlab:QChem:Write", "Cannot write solvent_data."); end
                cleanup = onCleanup(@() fclose(fid));
                fwrite(fid, char(obj.custom_smd), "char");
                clear cleanup
            end
        end
    end
    methods (Static, Access = private)
        function options = parse_options(defaults, args)
            options = defaults;
            if mod(numel(args), 2) ~= 0
                error("KSSOLV:Matgenlab:QChem:Options", "Options must be name-value pairs.");
            end
            for index = 1:2:numel(args)
                name = matlab.lang.makeValidName(char(lower(string(args{index}))));
                if ~isfield(options, name)
                    error("KSSOLV:Matgenlab:QChem:Options", "Unknown option '%s'.", name);
                end
                options.(name) = args{index + 1};
            end
        end
        function output = merge(base, incoming)
            if isempty(base), output = struct(); else, output = base; end
            names = fieldnames(incoming);
            for index = 1:numel(names), output.(names{index}) = incoming.(names{index}); end
        end
        function [svp, nonels] = cmirs(solvent)
            name = lower(string(solvent));
            settings = struct();
            settings.water = {["-0.006736", "0.032698", "-1249.6", "-21.405", "3.7", "0.05"], "78.39"};
            settings.benzene = {["-0.00522", "0.01294", "", "", "", "0.0421"], "2.28"};
            settings.cyclohexane = {["-0.00938", "0.03184", "", "", "", "0.0396"], "2.02"};
            settings.dimethyl_sulfoxide = {["-0.00951", "0.044791", "", "-162.07", "4.1", "0.05279"], "47"};
            settings.acetonitrile = {["-0.008178", "0.045278", "", "-0.33914", "1.3", "0.03764"], "36.64"};
            field = matlab.lang.makeValidName(name);
            if ~isfield(settings, field)
                error("KSSOLV:Matgenlab:QChem:CMIRS", "Unsupported CMIRS solvent '%s'.", name);
            end
            item = settings.(field); values = item{1};
            svp = struct("rhoiso", "0.001", "nptleb", "1202", "itrngr", "2", ...
                "irotgr", "2", "dielst", char(item{2}), "idefesr", "1", "ipnrf", "1");
            nonels = struct("a", char(values(1)), "b", char(values(2)), ...
                "c", char(values(3)), "d", char(values(4)), ...
                "gamma", char(values(5)), "solvrho", char(values(6)), ...
                "delta", "7", "gaulag_n", "40");
        end
    end
end
