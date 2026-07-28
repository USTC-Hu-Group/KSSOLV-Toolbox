classdef Outcar < handle
    %OUTCAR Parser for VASP output not represented in vasprun.xml.
    properties
        filename (1,1) string = ""
        is_stopped (1,1) logical = false
        run_stats (1,1) struct = struct()
        magnetization cell = cell(1,0)
        charge cell = cell(1,0)
        efermi = []
        nelect = []
        total_mag = []
        final_energy = []
        final_energy_wo_entrp = []
        final_fr_energy = []
        final_energy_contribs (1,1) struct = struct()
        data (1,1) struct = struct()
        drift double = zeros(0,3)
        spin (1,1) logical = false
        noncollinear (1,1) logical = false
        dfpt (1,1) logical = false
        lepsilon (1,1) logical = false
        lcalcpol (1,1) logical = false
        nmr_cs (1,1) logical = false
        nmr_efg (1,1) logical = false
        has_onsite_density_matrices (1,1) logical = false
        electrostatic_potential = []
        ngf = []
        sampling_radii = []
        plasma_frequencies (1,1) struct = struct()
        dielectric_energies double = []
        dielectric_tensor_function = []
        elastic_tensor double = []
        piezo_tensor double = []
        dielectric_tensor double = []
        born double = []
        internal_strain_tensor cell = cell(1,0)
        dielectric_ionic_tensor double = []
        piezo_ionic_tensor double = []
        p_elec = []
        p_ion = []
        p_sp1 = []
        p_sp2 = []
        zval_dict (1,1) struct = struct()
        er_ev (1,1) struct = struct()
        er_bp (1,1) struct = struct()
        er_ev_tot = []
        er_bp_tot = []
    end
    properties (Access = private)
        text_ (1,1) string = ""
        lines_ string = strings(0,1)
    end
    methods
        function obj = Outcar(filename)
            if nargin == 0, return; end
            obj.filename = string(filename);
            obj.text_ = string(kssolv.analysis.matgenlab.io.vasp. ...
                VaspIOUtils.readText(filename));
            obj.lines_ = splitlines(obj.text_);
            obj.is_stopped = contains(obj.text_, ...
                "soft stop encountered!  aborting job");

            stats = struct();
            for line = obj.lines_.'
                token = regexp(line, ...
                    '^\s*(.+\((?:sec|kb)\)):\s*(\S+)', ...
                    "tokens","once");
                if ~isempty(token)
                    field = matlab.lang.makeValidName(token{1});
                    value = str2double(token{2});
                    if isnan(value), value = []; end
                    stats.(field) = value;
                end
            end
            stats.cores = [];
            for line = obj.lines_.'
                if contains(line,"serial")
                    stats.cores = 1;
                    break
                end
                if contains(line,"running")
                    numbers = regexp(line,'\d+',"match");
                    if ~isempty(numbers)
                        stats.cores = str2double(numbers{1});
                        break
                    end
                end
            end
            obj.run_stats = stats;
            obj.efermi = obj.lastNumber( ...
                'E-fermi\s*:\s*([-+0-9.Ee]+)');
            obj.nelect = obj.lastNumber( ...
                'number of electron\s+([-+0-9.Ee]+)\s+magnetization');
            obj.total_mag = obj.lastNumber( ...
                'number of electron\s+\S+\s+magnetization\s+([-+0-9.Ee]+)');
            obj.final_fr_energy = obj.lastNumber( ...
                'free\s+energy\s+TOTEN\s*=\s*([-+0-9.Ee]+)');
            obj.final_energy_wo_entrp = obj.lastNumber( ...
                'energy\s+without entropy\s*=\s*([-+0-9.Ee]+)');
            obj.final_energy = obj.lastNumber( ...
                'energy\(sigma->0\)\s*=\s*([-+0-9.Ee]+)');
            [obj.charge,obj.magnetization] = obj.readChargeMagnetization();

            obj.read_pattern(struct("nbands", ...
                'number\s+of\s+bands\s+NBANDS=\s+(\d+)'), ...
                false,true,@str2double);
            if ~isempty(obj.data.nbands)
                obj.data.nbands = obj.data.nbands{1}{1};
            end
            obj.read_pattern(struct("nplwv", ...
                'total plane-waves\s+NPLWV\s*=\s+(\*{6}|\d+)'), ...
                false,true,@string);
            if isempty(obj.data.nplwv)
                obj.data.nplwv = {{[]}};
            else
                value = str2double(obj.data.nplwv{1}{1});
                if isnan(value), value = []; end
                obj.data.nplwv = {{value}};
            end
            waves = regexp(obj.text_,'plane waves:\s+(\*{6,}|\d+)', ...
                "tokens");
            obj.data.nplwvs_at_kpoints = cellfun(@(x) ...
                obj.nanToEmpty(str2double(x{1})),waves, ...
                "UniformOutput",false);
            obj.read_pattern(struct("drift", ...
                'total drift:\s+([.\-\d]+)\s+([.\-\d]+)\s+([.\-\d]+)'), ...
                false,false,@str2double);
            if isfield(obj.data,"drift") && ~isempty(obj.data.drift)
                obj.drift = cell2mat(cellfun(@cell2mat, ...
                    obj.data.drift,"UniformOutput",false));
            end
            obj.spin = ~isempty(regexp(obj.text_,'ISPIN\s*=\s*2',"once"));
            obj.noncollinear = ~isempty(regexp( ...
                obj.text_,'LNONCOLLINEAR\s*=\s*T',"once"));
            ibrion = regexp(obj.text_,'IBRION\s*=\s*([-\d]+)', ...
                "tokens","once");
            obj.dfpt = ~isempty(ibrion) && str2double(ibrion{1}) > 6;
            obj.lepsilon = ~isempty(regexp( ...
                obj.text_,'LEPSILON\s*=\s*T',"once"));
            obj.lcalcpol = ~isempty(regexp( ...
                obj.text_,'LCALCPOL\s*=\s*T',"once"));
            obj.nmr_cs = ~isempty(regexp( ...
                obj.text_,'LCHIMAG\s*=\s*T',"once"));
            obj.nmr_efg = contains(obj.text_,"NMR quadrupolar parameters");
            obj.has_onsite_density_matrices = ...
                contains(obj.text_,"onsite density matrix");

            if obj.dfpt, obj.read_internal_strain_tensor(); end
            if obj.lepsilon
                obj.read_lepsilon();
                if obj.dfpt, obj.read_lepsilon_ionic(); end
            end
            if obj.lcalcpol
                obj.read_lcalcpol();
                obj.read_pseudo_zval();
            end
            if contains(obj.text_,"average (electrostatic) potential at core")
                obj.read_electrostatic_potential();
            end
            if obj.nmr_cs
                obj.read_chemical_shielding();
                obj.read_cs_g0_contribution();
                obj.read_cs_core_contribution();
                obj.read_cs_raw_symmetrized_tensors();
            end
            if obj.nmr_efg
                obj.read_nmr_efg();
                obj.read_nmr_efg_tensor();
            end
            if obj.has_onsite_density_matrices
                obj.read_onsite_density_matrices();
            end
            keys = ["PSCENC","TEWEN","DENC","EXHF","XCENC", ...
                "PAW double counting","EENTRO","EBANDS","EATOM","Ediel_sol"];
            contributions = struct();
            for key = keys
                pattern = regexptranslate("escape",key) + ...
                    '\s*=\s*([-+0-9.Ee]+)(?:\s+([-+0-9.Ee]+))?';
                matches = regexp(obj.text_,pattern,"tokens");
                if isempty(matches), continue; end
                values = cellfun(@str2double,matches{end});
                values = values(~isnan(values));
                contributions.(matlab.lang.makeValidName(key)) = sum(values);
            end
            obj.final_energy_contribs = contributions;
        end

        function value = as_dict(obj)
            value = struct("x_module","pymatgen.io.vasp.outputs", ...
                "x_class","Outcar","efermi",obj.efermi, ...
                "run_stats",obj.run_stats, ...
                "magnetization",{obj.magnetization}, ...
                "charge",{obj.charge}, ...
                "total_magnetization",obj.total_mag, ...
                "nelect",obj.nelect,"is_stopped",obj.is_stopped, ...
                "drift",obj.drift,"ngf",obj.ngf, ...
                "sampling_radii",obj.sampling_radii, ...
                "electrostatic_potential",obj.electrostatic_potential);
            if obj.lepsilon
                value.piezo_tensor = obj.piezo_tensor;
                value.dielectric_tensor = obj.dielectric_tensor;
                value.born = obj.born;
            end
            if obj.dfpt
                value.internal_strain_tensor = obj.internal_strain_tensor;
            end
            if obj.dfpt && obj.lepsilon
                value.piezo_ionic_tensor = obj.piezo_ionic_tensor;
                value.dielectric_ionic_tensor = obj.dielectric_ionic_tensor;
            end
            if obj.lcalcpol
                value.p_elec = obj.p_elec;
                value.p_ion = obj.p_ion;
                value.zval_dict = obj.zval_dict;
            end
            if obj.has_onsite_density_matrices
                value.onsite_density_matrices = ...
                    obj.data.onsite_density_matrices;
            end
        end

        function read_pattern(obj,patterns,reverse,terminate_on_match,postprocess)
            if nargin < 3, reverse = false; end
            if nargin < 4, terminate_on_match = false; end
            if nargin < 5, postprocess = @string; end
            names = string(fieldnames(patterns));
            results = struct();
            for name = names.'
                results.(name) = cell(0,1);
            end
            indices = 1:numel(obj.lines_);
            if reverse, indices = fliplr(indices); end
            for lineIndex = indices
                line = obj.lines_(lineIndex);
                for name = names.'
                    pattern = patterns.(name);
                    if isempty(regexp(line,pattern,"once")), continue; end
                    tokens = regexp(line,pattern,"tokens","once");
                    if isempty(tokens), tokens = cell(1,0); end
                    converted = cellfun(@(item)obj.applyPost( ...
                        postprocess,item),tokens,"UniformOutput",false);
                    results.(name){end + 1,1} = converted;
                end
                if terminate_on_match && all(arrayfun( ...
                        @(name)~isempty(results.(name)),names))
                    break
                end
            end
            for name = names.'
                obj.data.(name) = results.(name);
            end
        end

        function retained = read_table_pattern(obj,header_pattern, ...
                row_pattern,footer_pattern,postprocess,attribute_name, ...
                last_one_only,first_one_only)
            if nargin < 5, postprocess = @string; end
            if nargin < 6, attribute_name = ""; end
            if nargin < 7, last_one_only = true; end
            if nargin < 8, first_one_only = false; end
            if last_one_only && first_one_only
                error("KSSOLV:Matgenlab:Outcar:TableOptions", ...
                    "last_one_only and first_one_only are incompatible.");
            end
            header_pattern = strrep(header_pattern,"(?P<","(?<");
            row_pattern = strrep(row_pattern,"(?P<","(?<");
            footer_pattern = strrep(footer_pattern,"(?P<","(?<");
            combined = ['(?ms)' char(header_pattern) ...
                '\s*^(?<table_body>(?:\s+' char(row_pattern) ...
                ')+)\s+' char(footer_pattern)];
            matches = regexp(char(obj.text_),combined,"names");
            tables = cell(1,numel(matches));
            for tableIndex = 1:numel(matches)
                rows = splitlines(string(matches(tableIndex).table_body));
                parsed = cell(0,1);
                for line = rows.'
                    if isempty(regexp(line,row_pattern,"once")), continue; end
                    named = regexp(line,row_pattern,"names","once");
                    if ~isempty(named) && ~isempty(fieldnames(named))
                        fields = fieldnames(named);
                        row = struct();
                        for fieldIndex = 1:numel(fields)
                            row.(fields{fieldIndex}) = obj.applyPost( ...
                                postprocess,named.(fields{fieldIndex}));
                        end
                    else
                        tokens = regexp(line,row_pattern,"tokens","once");
                        row = cellfun(@(item)obj.applyPost( ...
                            postprocess,item),tokens,"UniformOutput",false);
                    end
                    parsed{end + 1,1} = row; %#ok<AGROW>
                end
                tables{tableIndex} = obj.compactRows(parsed);
                if first_one_only, tables = tables(1); break; end
            end
            if isempty(tables), retained = [];
            elseif last_one_only, retained = tables{end};
            elseif first_one_only, retained = tables{1};
            else, retained = tables;
            end
            if string(attribute_name) ~= ""
                obj.data.(attribute_name) = retained;
            end
        end

        function read_electrostatic_potential(obj)
            ngfTokens = regexp(obj.text_, ...
                ['dimension x,y,z NGXF=\s+([.\-\d]+)\s+' ...
                'NGYF=\s+([.\-\d]+)\s+NGZF=\s+([.\-\d]+)'], ...
                "tokens","once");
            if ~isempty(ngfTokens)
                obj.ngf = cellfun(@str2double,ngfTokens);
            end
            radii = regexp(obj.text_, ...
                'the test charge radii are((?:\s+[.\-\d]+)+)', ...
                "tokens");
            if ~isempty(radii)
                obj.sampling_radii = sscanf(radii{end}{1},"%f").';
            end
            sections = regexp(obj.text_, ...
                ['(?s)\(the norm of the test charge is\s+[.\-\d]+\)' ...
                '(.*?)\s+E-fermi\s*:'],"tokens");
            if isempty(sections), obj.electrostatic_potential = []; return; end
            pairs = regexp(sections{end}{1}, ...
                '\s+\d+\s*([.\-\d]+)',"tokens");
            obj.electrostatic_potential = ...
                cellfun(@(item)str2double(item{1}),pairs);
        end

        function read_freq_dielectric(obj)
            plasma = struct("intraband",zeros(0,3), ...
                "interband",zeros(0,3));
            energies = zeros(0,1);
            imaginary = zeros(0,3,3);
            realPart = zeros(0,3,3);
            plasmaMode = "";
            dielectric = false;
            component = "imaginary";
            dashCount = 0;
            for line = obj.lines_.'
                clean = strtrim(line);
                if contains(clean,"plasma frequency squared")
                    if contains(clean,"intraband")
                        plasmaMode = "intraband";
                    else
                        plasmaMode = "interband";
                    end
                    continue
                end
                if contains(clean,"frequency dependent") && ...
                        contains(clean,"IMAGINARY")
                    plasmaMode = "";
                    dielectric = true;
                    continue
                end
                values = sscanf(clean,"%f").';
                if plasmaMode ~= "" && numel(values) == 3
                    plasma.(plasmaMode)(end + 1,:) = values;
                elseif dielectric
                    sci = obj.parseSciNotation(clean);
                    if numel(values) ~= 7 && numel(sci) == 7
                        values = sci;
                    end
                    if numel(values) == 7
                        if component == "imaginary"
                            energies(end + 1,1) = values(1); %#ok<AGROW>
                        end
                        v = values(2:end);
                        tensor = [v(1),v(4),v(6);v(4),v(2),v(5); ...
                            v(6),v(5),v(3)];
                        if component == "imaginary"
                            imaginary(end + 1,:,:) = tensor; %#ok<AGROW>
                        else
                            realPart(end + 1,:,:) = tensor; %#ok<AGROW>
                        end
                    elseif ~isempty(regexp(clean,'^-+$',"once"))
                        dashCount = dashCount + 1;
                        if dashCount == 2, component = "real"; end
                        if dashCount == 3, break; end
                    end
                end
            end
            obj.plasma_frequencies = struct( ...
                "intraband",plasma.intraband(1:min(3,end),:), ...
                "interband",plasma.interband(1:min(3,end),:));
            obj.dielectric_energies = energies;
            obj.dielectric_tensor_function = complex(realPart,imaginary);
        end

        function read_chemical_shielding(obj)
            obj.data.chemical_shielding = struct( ...
                "valence_only",obj.shieldingRows( ...
                "(absolute, valence only)"), ...
                "valence_and_core",obj.shieldingRows( ...
                "(absolute, valence and core)"));
        end

        function read_cs_g0_contribution(obj)
            starts = find(contains(obj.lines_, ...
                "G=0 CONTRIBUTION TO CHEMICAL SHIFT"));
            table = zeros(0,3);
            if ~isempty(starts)
                pointer = starts(end)+1;
                started = false;
                while pointer <= numel(obj.lines_)
                    values = sscanf(obj.lines_(pointer),"%f").';
                    if numel(values) == 4
                        table(end + 1,:) = values(2:4); %#ok<AGROW>
                        started = true;
                    elseif started && contains(obj.lines_(pointer),"---")
                        break
                    end
                    pointer = pointer+1;
                end
            end
            obj.data.cs_g0_contribution = table;
        end

        function read_cs_core_contribution(obj)
            result = struct();
            starts = find(contains(obj.lines_,"Core NMR properties"));
            if ~isempty(starts)
                pointer = starts(end)+1;
                started = false;
                while pointer <= numel(obj.lines_)
                    row = regexp(obj.lines_(pointer), ...
                        '^\s*\d+\s+([A-Z][a-z]?\w?)\s+(-?\d+\.\d+)', ...
                        "tokens","once");
                    if ~isempty(row)
                        result.(matlab.lang.makeValidName(row{1})) = ...
                            str2double(row{2});
                        started = true;
                    elseif started && contains(obj.lines_(pointer),"---")
                        break
                    end
                    pointer = pointer+1;
                end
            end
            obj.data.cs_core_contribution = result;
        end

        function read_cs_raw_symmetrized_tensors(obj)
            section = regexp(obj.text_, ...
                ['(?s)Absolute Chemical Shift tensors.*?' ...
                'UNSYMMETRIZED TENSORS(.*?)SYMMETRIZED TENSORS'], ...
                "tokens","once");
            if isempty(section)
                error("KSSOLV:Matgenlab:Outcar:NmrTensor", ...
                    "NMR UNSYMMETRIZED TENSORS was not found.");
            end
            blocks = regexp(section{1}, ...
                '(?s)ion\s+\d+\s*(.*?)(?=ion\s+\d+|$)',"tokens");
            tensors = cell(1,numel(blocks));
            for index = 1:numel(blocks)
                tensors{index} = obj.numericRows(blocks{index},3,false);
                tensors{index} = tensors{index}(1:min(3,end),:);
            end
            obj.data.unsym_cs_tensor = tensors;
        end

        function tensors = read_nmr_efg_tensor(obj)
            starts = find(strtrim(obj.lines_) == ...
                "Electric field gradients (V/A^2)");
            table = zeros(0,6);
            if ~isempty(starts)
                pointer = starts(end)+1;
                started = false;
                while pointer <= numel(obj.lines_)
                    values = sscanf(obj.lines_(pointer),"%f").';
                    if numel(values) == 7
                        table(end + 1,:) = values(2:7); %#ok<AGROW>
                        started = true;
                    elseif started && contains(obj.lines_(pointer),"---")
                        break
                    end
                    pointer = pointer+1;
                end
            end
            tensors = cell(1,size(table,1));
            for index = 1:size(table,1)
                v = table(index,:);
                tensors{index} = [v(1),v(4),v(5);v(4),v(2),v(6); ...
                    v(5),v(6),v(3)];
            end
            obj.data.unsym_efg_tensor = tensors;
        end

        function read_nmr_efg(obj)
            result = struct("cq",{},"eta",{}, ...
                "nuclear_quadrupole_moment",{});
            starts = find(strtrim(obj.lines_) == ...
                "NMR quadrupolar parameters");
            if ~isempty(starts)
                pointer = starts(end)+1;
                started = false;
                while pointer <= numel(obj.lines_)
                    values = sscanf(obj.lines_(pointer),"%f").';
                    if numel(values) == 4
                        result(end + 1) = struct("cq",values(2), ...
                            "eta",values(3), ...
                            "nuclear_quadrupole_moment",values(4)); %#ok<AGROW>
                        started = true;
                    elseif started && contains(obj.lines_(pointer),"---")
                        break
                    end
                    pointer = pointer+1;
                end
            end
            obj.data.efg = result;
        end

        function read_elastic_tensor(obj)
            section = regexp(obj.text_, ...
                ['(?s)TOTAL ELASTIC MODULI \(kBar\).*?\n\s*-+\s*\n' ...
                '(.*?)\n\s*-+'],"tokens");
            table = zeros(0,6);
            if ~isempty(section)
                rows = regexp(section{end}{1}, ...
                    ['(?m)^\s*[X-Z][X-Z]\s+' ...
                    '([-.\d]+)\s+([-.\d]+)\s+([-.\d]+)\s+' ...
                    '([-.\d]+)\s+([-.\d]+)\s+([-.\d]+)'], ...
                    "tokens");
                for index = 1:numel(rows)
                    table(end + 1,:) = ...
                        cellfun(@str2double,rows{index}); %#ok<AGROW>
                end
            end
            obj.elastic_tensor = table;
            obj.data.elastic_tensor = table;
        end

        function read_piezo_tensor(obj)
            table = obj.read_table_pattern( ...
                ['PIEZOELECTRIC TENSOR  for field in x, y, z\s+' ...
                '\(C/m\^2\)\s+([X-Z][X-Z]\s+)+\-+'], ...
                ['[x-z]\s+' repmat('(\-*[\d.]+)\s*',1,6)], ...
                'BORN EFFECTIVE',@str2double,"",true,false);
            obj.piezo_tensor = table;
            obj.data.piezo_tensor = table;
        end

        function read_onsite_density_matrices(obj)
            up = regexp(obj.text_, ...
                '(?s)spin component\s+1\s*(.*?)spin component\s+2', ...
                "tokens");
            down = regexp(obj.text_, ...
                '(?s)spin component\s+2\s*(.*?)occupancies and eigenvectors', ...
                "tokens");
            count = min(numel(up),numel(down));
            matrices = cell(1,count);
            for index = 1:count
                matrices{index} = struct( ...
                    "up",obj.matrixFromSection(up{index}{1}), ...
                    "down",obj.matrixFromSection(down{index}{1}));
            end
            obj.data.onsite_density_matrices = matrices;
        end

        function read_corrections(obj,reverse,terminate_on_match)
            if nargin < 2, reverse = true; end
            if nargin < 3, terminate_on_match = true; end
            obj.read_pattern(struct("dipol_quadrupol_correction", ...
                'dipol\+quadrupol energy correction\s+([\d\-.]+)'), ...
                reverse,terminate_on_match,@str2double);
            values = obj.data.dipol_quadrupol_correction;
            if ~isempty(values)
                obj.data.dipol_quadrupol_correction = values{1}{1};
            end
        end

        function read_neb(obj,reverse,terminate_on_match)
            if nargin < 2, reverse = true; end
            if nargin < 3, terminate_on_match = true; end
            patterns = struct("energy", ...
                'energy\(sigma->0\)\s*=\s+([\d\-.]+)', ...
                "tangent_force", ...
                ['(NEB: projections on to tangent \(spring, REAL\)\s+\S+' ...
                '|tangential force \(eV/A\))\s+([\d\-.]+)']);
            obj.read_pattern(patterns,reverse,terminate_on_match,@string);
            if ~isempty(obj.data.energy)
                obj.data.energy = str2double(obj.data.energy{1}{1});
            end
            if ~isempty(obj.data.tangent_force)
                obj.data.tangent_force = ...
                    str2double(obj.data.tangent_force{1}{2});
            end
        end

        function read_igpar(obj)
            ev = regexp(obj.text_, ...
                'e<r>_ev=\(\s*([-0-9.Ee+]+)\s+([-0-9.Ee+]+)\s+([-0-9.Ee+]+)\s*\)', ...
                "tokens");
            bp = regexp(obj.text_, ...
                'e<r>_bp=\(\s*([-0-9.Ee+]+)\s+([-0-9.Ee+]+)\s+([-0-9.Ee+]+)\s*\)', ...
                "tokens");
            if obj.spin && numel(ev) >= 2
                obj.er_ev.up = cellfun(@str2double,ev{end-1});
                obj.er_ev.down = cellfun(@str2double,ev{end});
                obj.er_bp.up = cellfun(@str2double,bp{end-1});
                obj.er_bp.down = cellfun(@str2double,bp{end});
            elseif ~isempty(ev)
                halfEv = cellfun(@str2double,ev{end})/2;
                halfBp = cellfun(@str2double,bp{end})/2;
                obj.er_ev = struct("up",halfEv,"down",halfEv);
                obj.er_bp = struct("up",halfBp,"down",halfBp);
            end
            if isfield(obj.er_ev,"up")
                obj.er_ev_tot = obj.er_ev.up + obj.er_ev.down;
                obj.er_bp_tot = obj.er_bp.up + obj.er_bp.down;
            end
            obj.read_lcalcpol();
        end

        function read_internal_strain_tensor(obj)
            starts = find(contains(obj.lines_,"INTERNAL STRAIN TENSOR FOR ION"));
            tensors = cell(1,numel(starts));
            for index = 1:numel(starts)
                tensor = zeros(3,6);
                row = 0;
                pointer = starts(index)+1;
                while pointer <= numel(obj.lines_) && row < 3
                    token = regexp(obj.lines_(pointer), ...
                        '^\s*([xyz])\s+(.+)$',"tokens","once");
                    if ~isempty(token)
                        values = sscanf(token{2},"%f").';
                        if numel(values) >= 6
                            row = row + 1;
                            tensor(row,:) = values(1:6);
                        end
                    end
                    pointer = pointer + 1;
                end
                tensors{index} = tensor;
            end
            obj.internal_strain_tensor = tensors;
        end

        function read_lepsilon(obj)
            obj.dielectric_tensor = obj.tensorAfter( ...
                "MACROSCOPIC STATIC DIELECTRIC TENSOR",3,3);
            obj.piezo_tensor = obj.labeledTensorAfter( ...
                "PIEZOELECTRIC TENSOR  for field in x, y, z",3,6);
            starts = find(contains(obj.lines_,"BORN EFFECTIVE CHARGES"));
            bornTensors = cell(1,0);
            if ~isempty(starts)
                pointer = starts(end)+1;
                current = [];
                while pointer <= numel(obj.lines_)
                    ion = regexp(obj.lines_(pointer), ...
                        '^\s*ion\s+(\d+)',"tokens","once");
                    if ~isempty(ion)
                        current = str2double(ion{1});
                        bornTensors{current} = zeros(3,3);
                    else
                        row = sscanf(obj.lines_(pointer),"%f").';
                        if ~isempty(current) && numel(row) == 4 && ...
                                ismember(row(1),1:3)
                            bornTensors{current}(row(1),:) = row(2:4);
                        elseif ~isempty(current) && contains( ...
                                obj.lines_(pointer),"-----")
                            break
                        end
                    end
                    pointer = pointer + 1;
                end
            end
            if ~isempty(bornTensors), obj.born = cat(3,bornTensors{:}); end
            if ~isempty(obj.born), obj.born = permute(obj.born,[3,1,2]); end
        end

        function read_lepsilon_ionic(obj)
            obj.dielectric_ionic_tensor = obj.tensorAfter( ...
                "MACROSCOPIC STATIC DIELECTRIC TENSOR IONIC",3,3);
            obj.piezo_ionic_tensor = obj.labeledTensorAfter( ...
                "PIEZOELECTRIC TENSOR IONIC CONTR",3,6);
        end

        function read_lcalcpol(obj)
            obj.p_elec = obj.lastVector( ...
                'Total electronic dipole moment:.*p\[elc\]=\(\s*([^)]+)\)');
            obj.p_ion = obj.lastVector( ...
                'Ionic dipole moment:.*p\[ion\]=\(\s*([^)]+)\)');
            obj.p_sp1 = obj.lastVector('p\[sp1\]=\(\s*([^)]+)\)');
            obj.p_sp2 = obj.lastVector('p\[sp2\]=\(\s*([^)]+)\)');
            ionicLines = obj.lines_(contains(obj.lines_,"Ionic dipole moment:"));
            if ~isempty(ionicLines) && contains(ionicLines(end),"|e|")
                obj.p_elec = -obj.p_elec;
                obj.p_ion = -obj.p_ion;
                obj.p_sp1 = -obj.p_sp1;
                obj.p_sp2 = -obj.p_sp2;
            end
        end

        function read_pseudo_zval(obj)
            symbols = regexp(obj.text_,'VRHFIN\s*=\s*([^:]+):', ...
                "tokens");
            zvalLines = obj.lines_(~cellfun(@isempty, ...
                regexp(cellstr(obj.lines_),'^\s*ZVAL\s*=','once')));
            if isempty(zvalLines), obj.zval_dict = struct(); return; end
            payload = extractAfter(zvalLines(end),"=");
            values = regexp(payload,'-?\d+\.\d*',"match");
            values = cellfun(@str2double,values);
            result = struct();
            for index = 1:min(numel(symbols),numel(values))
                field = matlab.lang.makeValidName(strtrim(symbols{index}{1}));
                result.(field) = values(index);
            end
            obj.zval_dict = result;
        end

        function result = read_core_state_eigen(obj)
            nions = regexp(obj.text_,'NIONS\s*=\s*(\d+)', ...
                "tokens","once");
            if isempty(nions), result = cell(1,0); return; end
            result = repmat({struct()},1,str2double(nions{1}));
            sections = regexp(obj.text_, ...
                '(?s)the core state eigen(.*?)(?=E-fermi)',"tokens");
            for section = sections
                lines = splitlines(string(section{1}{1}));
                atom = 0;
                for line = lines.'
                    start = regexp(line,'^\s*(\d+)-\s*(.*)$', ...
                        "tokens","once");
                    if ~isempty(start)
                        atom = str2double(start{1});
                        tokens = split(strtrim(start{2}));
                    else
                        tokens = split(strtrim(line));
                    end
                    tokens(tokens == "") = [];
                    if atom < 1 || isempty(tokens), continue; end
                    for index = 1:2:numel(tokens)-1
                        orbital = matlab.lang.makeValidName( ...
                            char(tokens(index)));
                        if isempty(orbital), continue; end
                        if ~isfield(result{atom},orbital)
                            result{atom}.(orbital) = [];
                        end
                        result{atom}.(orbital)(end + 1) = ...
                            str2double(tokens(index+1));
                    end
                end
            end
        end

        function result = read_avg_core_poten(obj)
            sections = regexp(obj.text_, ...
                ['(?s)the norm of the test charge is.*?\n' ...
                '(.*?)(?=E-fermi)'],"tokens");
            result = cell(1,numel(sections));
            for index = 1:numel(sections)
                pairs = regexp(sections{index}{1}, ...
                    '\s+\d+\s*([.\-\d]+)',"tokens");
                result{index} = cellfun(@(x)str2double(x{1}),pairs);
            end
        end

        function read_fermi_contact_shift(obj)
            obj.data.fermi_contact_shift = struct( ...
                "fch",obj.hyperfineTable("Fermi contact",5), ...
                "dh",obj.hyperfineTable("Dipolar hyperfine",6), ...
                "th",obj.hyperfineTable( ...
                    "Total hyperfine coupling parameters",4));
        end

        function read_vacuum_potentials(obj,reverse,terminate_on_match)
            if nargin < 2, reverse = true; end
            if nargin < 3, terminate_on_match = true; end
            obj.read_pattern(struct("vacuum_potentials", ...
                ['vacuum level on the upper side and lower side of the slab' ...
                '\s+([\d.\-]+)\s+([\d.\-]+)']), ...
                reverse,terminate_on_match,@str2double);
            values = obj.data.vacuum_potentials;
            if ~isempty(values)
                obj.data.vacuum_potential_upper = values{1}{1};
                obj.data.vacuum_potential_lower = values{1}{2};
                obj.data = rmfield(obj.data,"vacuum_potentials");
            end
        end
    end

    methods (Access = private)
        function value = lastNumber(obj,pattern)
            matches = regexp(obj.text_,pattern,"tokens");
            if isempty(matches), value = [];
            else
                value = str2double(matches{end}{1});
                if isnan(value), value = []; end
            end
        end
        function value = lastVector(obj,pattern)
            matches = regexp(obj.text_,pattern,"tokens");
            if isempty(matches), value = [];
            else, value = sscanf(matches{end}{1},"%f").';
            end
        end
        function [charge,mag] = readChargeMagnetization(obj)
            charge = cell(1,0); mx = cell(1,0);
            my = cell(1,0); mz = cell(1,0);
            mode = ""; header = strings(1,0);
            for line = obj.lines_.'
                clean = strtrim(line);
                if clean == "total charge"
                    charge = cell(1,0); mode = "charge"; continue
                elseif clean == "magnetization (x)"
                    mx = cell(1,0); mode = "x"; continue
                elseif clean == "magnetization (y)"
                    my = cell(1,0); mode = "y"; continue
                elseif clean == "magnetization (z)"
                    mz = cell(1,0); mode = "z"; continue
                end
                if mode == "", continue; end
                if startsWith(clean,"# of ion")
                    header = string(regexp(clean,'\s{2,}',"split"));
                    header = header(2:end);
                elseif startsWith(clean,"tot")
                    mode = "";
                elseif ~isempty(regexp(clean,'^\d+\s+',"once"))
                    numbers = sscanf(clean,"%f").';
                    if numel(numbers)-1 < numel(header), continue; end
                    row = struct();
                    for index = 1:numel(header)
                        row.(matlab.lang.makeValidName(header(index))) = ...
                            numbers(index+1);
                    end
                    switch mode
                        case "charge", charge{end + 1} = row; %#ok<AGROW>
                        case "x", mx{end + 1} = row; %#ok<AGROW>
                        case "y", my{end + 1} = row; %#ok<AGROW>
                        case "z", mz{end + 1} = row; %#ok<AGROW>
                    end
                elseif contains(clean,"electrostatic")
                    mode = "";
                end
            end
            if ~isempty(my) && ~isempty(mz)
                mag = cell(size(mx));
                for ion = 1:numel(mx)
                    row = struct();
                    fields = fieldnames(mx{ion});
                    for index = 1:numel(fields)
                        field = fields{index};
                        row.(field) = [mx{ion}.(field), ...
                            my{ion}.(field),mz{ion}.(field)];
                    end
                    mag{ion} = row;
                end
            else, mag = mx;
            end
        end
        function output = applyPost(~,postprocess,input)
            if isa(postprocess,"function_handle")
                output = postprocess(input);
            else
                switch string(postprocess)
                    case {"float","double","int"}
                        output = str2double(input);
                    otherwise, output = string(input);
                end
            end
        end
        function output = compactRows(~,rows)
            if isempty(rows), output = []; return; end
            if all(cellfun(@isstruct,rows))
                output = [rows{:}];
                return
            end
            if all(cellfun(@iscell,rows))
                lengths = cellfun(@numel,rows);
                if all(lengths == lengths(1)) && ...
                        all(cellfun(@(row)all(cellfun(@isnumeric,row)),rows))
                    output = cell2mat(cellfun(@cell2mat,rows, ...
                        "UniformOutput",false));
                elseif all(lengths == lengths(1))
                    output = vertcat(rows{:});
                else
                    output = rows;
                end
            else, output = rows;
            end
        end
        function rows = numericRows(~,section,width,skipIndex)
            if isempty(section), rows = zeros(0,width); return; end
            if iscell(section), section = section{1}; end
            lines = splitlines(string(section));
            rows = zeros(0,width);
            for line = lines.'
                values = sscanf(line,"%f").';
                if skipIndex && numel(values) == width+1
                    values = values(2:end);
                end
                if numel(values) == width
                    rows(end + 1,:) = values; %#ok<AGROW>
                end
            end
        end
        function matrix = matrixFromSection(obj,section)
            rows = obj.numericRows(section,7,false);
            if isempty(rows)
                for width = [5,3]
                    rows = obj.numericRows(section,width,false);
                    if ~isempty(rows), break; end
                end
            end
            matrix = rows;
        end
        function tensor = tensorAfter(obj,marker,nrow,ncol)
            starts = find(contains(obj.lines_,marker));
            if string(marker) == "MACROSCOPIC STATIC DIELECTRIC TENSOR"
                starts = starts(~contains(obj.lines_(starts),"IONIC"));
            end
            tensor = zeros(0,ncol);
            if isempty(starts), return; end
            pointer = starts(end)+1;
            while pointer <= numel(obj.lines_) && size(tensor,1)<nrow
                values = sscanf(obj.lines_(pointer),"%f").';
                if numel(values) == ncol
                    tensor(end + 1,:) = values; %#ok<AGROW>
                end
                pointer = pointer+1;
            end
        end
        function tensor = labeledTensorAfter(obj,marker,nrow,ncol)
            starts = find(contains(obj.lines_,marker));
            tensor = zeros(0,ncol);
            if isempty(starts), return; end
            pointer = starts(end)+1;
            while pointer <= numel(obj.lines_) && size(tensor,1)<nrow
                token = regexp(obj.lines_(pointer), ...
                    '^\s*[xyz]\s+(.+)$',"tokens","once");
                if ~isempty(token)
                    values = sscanf(token{1},"%f").';
                    if numel(values) >= ncol
                        tensor(end + 1,:) = values(1:ncol); %#ok<AGROW>
                    end
                end
                pointer = pointer+1;
            end
        end
        function table = hyperfineTable(obj,marker,width)
            starts = find(contains(obj.lines_,marker));
            table = zeros(0,width);
            if isempty(starts), return; end
            pointer = starts(end)+1;
            while pointer <= numel(obj.lines_)
                values = sscanf(obj.lines_(pointer),"%f").';
                if numel(values) == width+1
                    table(end + 1,:) = values(2:end); %#ok<AGROW>
                elseif ~isempty(table) && contains(obj.lines_(pointer),"---")
                    break
                end
                pointer = pointer+1;
            end
        end
        function table = shieldingRows(obj,marker)
            starts = find(contains(obj.lines_,marker));
            table = zeros(0,3);
            if isempty(starts), return; end
            pointer = starts(end)+1;
            started = false;
            while pointer <= numel(obj.lines_)
                values = sscanf(obj.lines_(pointer),"%f").';
                if numel(values) == 7
                    table(end + 1,:) = values(5:7); %#ok<AGROW>
                    started = true;
                elseif started && contains(obj.lines_(pointer),"---")
                    break
                end
                pointer = pointer+1;
            end
        end
    end
    methods (Static, Access = private)
        function value = nanToEmpty(value)
            if isnan(value), value = []; end
        end
        function values = parseSciNotation(line)
            tokens = regexp(line,'[.\-\d]+E[+\-]\d{2}',"match");
            values = cellfun(@str2double,tokens);
        end
    end
end
