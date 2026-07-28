classdef Procar < kssolv.analysis.matgenlab.util.MSONable
    %PROCAR Reader for VASP orbital-projection output.

    properties (SetAccess = private)
        data (1,1) struct = struct()
        weights double = []
        phase_factors (1,1) struct = struct()
        nbands (1,1) double = 0
        nkpoints (1,1) double = 0
        nions (1,1) double = 0
        nspins (1,1) double = 0
        is_soc (1,1) logical = false
        kpoints double = zeros(0,3)
        occupancies (1,1) struct = struct()
        eigenvalues (1,1) struct = struct()
        xyz_data = []
        orbitals (1,:) string = strings(1,0)
    end

    methods
        function obj = Procar(filename)
            if nargin == 0, return; end
            obj = obj.read(filename);
        end

        function obj = read(obj, filenames)
            filenames = obj.normalizeFiles(filenames);
            parsed = cell(1, numel(filenames));
            for fileIndex = 1:numel(filenames)
                parsed{fileIndex} = obj.readOne(filenames(fileIndex));
            end
            reference = parsed{1};
            for fileIndex = 2:numel(parsed)
                item = parsed{fileIndex};
                if item.nions ~= reference.nions
                    error("KSSOLV:Matgenlab:Procar:IonsMismatch", ...
                        "Mismatch in number of ions in supplied PROCARs.");
                end
                if item.is_soc ~= reference.is_soc
                    error("KSSOLV:Matgenlab:Procar:SocMismatch", ...
                        "Mismatch in SOC setting in supplied PROCARs.");
                end
                if ~isequal(item.orbitals, reference.orbitals)
                    error("KSSOLV:Matgenlab:Procar:OrbitalsMismatch", ...
                        "Mismatch in orbital headers in supplied PROCARs.");
                end
                if ~isequal(fieldnames(item.data), fieldnames(reference.data))
                    error("KSSOLV:Matgenlab:Procar:SpinMismatch", ...
                        "Mismatch in spin channels in supplied PROCARs.");
                end
            end

            maxBands = max(cellfun(@(item)item.nbands, parsed));
            kept = cell(size(parsed));
            for fileIndex = 1:numel(parsed)
                item = parsed{fileIndex};
                % Frozen pymatgen concatenates distinct files as supplied;
                % repeated points are removed only within each individual file.
                kept{fileIndex} = (1:item.nkpoints).';
            end

            obj.nbands = maxBands;
            obj.nions = reference.nions;
            obj.is_soc = reference.is_soc;
            obj.orbitals = reference.orbitals;
            obj.kpoints = vertcat(parsed{1}.kpoints(kept{1},:));
            obj.weights = parsed{1}.weights(kept{1});
            for fileIndex = 2:numel(parsed)
                obj.kpoints = [obj.kpoints; ...
                    parsed{fileIndex}.kpoints(kept{fileIndex},:)];
                obj.weights = [obj.weights; ...
                    parsed{fileIndex}.weights(kept{fileIndex})];
            end
            obj.nkpoints = size(obj.kpoints, 1);
            spinNames = string(fieldnames(reference.data));
            for spinName = spinNames.'
                obj.data.(spinName) = zeros(obj.nkpoints, maxBands, ...
                    obj.nions, numel(obj.orbitals));
                obj.phase_factors.(spinName) = complex(nan( ...
                    obj.nkpoints, maxBands, obj.nions, ...
                    numel(obj.orbitals)));
                obj.eigenvalues.(spinName) = zeros(obj.nkpoints, maxBands);
                obj.occupancies.(spinName) = zeros(obj.nkpoints, maxBands);
            end
            if obj.is_soc
                obj.xyz_data = struct();
                for direction = ["x","y","z"]
                    obj.xyz_data.(direction) = zeros(obj.nkpoints, ...
                        maxBands, obj.nions, numel(obj.orbitals));
                end
            else
                obj.xyz_data = [];
            end
            offset = 0;
            for fileIndex = 1:numel(parsed)
                item = parsed{fileIndex};
                rows = kept{fileIndex};
                target = offset + (1:numel(rows));
                for spinName = spinNames.'
                    obj.data.(spinName)(target,1:item.nbands,:,:) = ...
                        item.data.(spinName)(rows,:,:,:);
                    obj.phase_factors.(spinName)(target,1:item.nbands,:,:) = ...
                        item.phase_factors.(spinName)(rows,:,:,:);
                    obj.eigenvalues.(spinName)(target,1:item.nbands) = ...
                        item.eigenvalues.(spinName)(rows,:);
                    obj.occupancies.(spinName)(target,1:item.nbands) = ...
                        item.occupancies.(spinName)(rows,:);
                end
                if obj.is_soc
                    for direction = ["x","y","z"]
                        obj.xyz_data.(direction)(target,1:item.nbands,:,:) = ...
                            item.xyz_data.(direction)(rows,:,:,:);
                    end
                end
                offset = offset + numel(rows);
            end
            obj.nspins = numel(spinNames);
        end

        function output = get_projection_on_elements(obj, structure)
            if structure.num_sites ~= obj.nions
                error("KSSOLV:Matgenlab:Procar:StructureSites", ...
                    "Structure must contain one site per PROCAR ion.");
            end
            output = struct();
            spinNames = string(fieldnames(obj.data));
            for spinName = spinNames.'
                values = cell(obj.nbands, obj.nkpoints);
                for bandIndex = 1:obj.nbands
                    for pointIndex = 1:obj.nkpoints
                        projected = struct();
                        for ionIndex = 1:obj.nions
                            symbol = string( ...
                                structure(ionIndex).specie.symbol);
                            field = matlab.lang.makeValidName(symbol);
                            amount = sum(obj.data.(spinName)( ...
                                pointIndex,bandIndex,ionIndex,:), 4);
                            if isfield(projected, field)
                                projected.(field) = ...
                                    projected.(field) + amount;
                            else
                                projected.(field) = amount;
                            end
                        end
                        values{bandIndex,pointIndex} = projected;
                    end
                end
                output.(spinName) = values;
            end
        end

        function output = get_occupation(obj, atom_index, orbital)
            validateattributes(atom_index, {'numeric'}, ...
                {'scalar','integer','>=',1,'<=',obj.nions});
            orbital = string(orbital);
            indices = find(obj.orbitals == orbital);
            if isempty(indices) && ismember(orbital, ["s","p","d","f"])
                indices = find(startsWith(obj.orbitals, orbital));
            end
            if isempty(indices)
                error("KSSOLV:Matgenlab:Procar:Orbital", ...
                    "Orbital '%s' is not in the PROCAR orbital list.", orbital);
            end
            output = struct();
            for spinName = string(fieldnames(obj.data)).'
                values = sum(obj.data.(spinName)(:,:,atom_index,indices), ...
                    4);
                output.(spinName) = sum(values .* obj.weights, "all");
            end
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.vasp.outputs", ...
                "x_class", "Procar", "data", obj.data, ...
                "weights", obj.weights, ...
                "phase_factors", obj.phase_factors, ...
                "nbands", obj.nbands, "nkpoints", obj.nkpoints, ...
                "nions", obj.nions, "nspins", obj.nspins, ...
                "is_soc", obj.is_soc, "kpoints", obj.kpoints, ...
                "occupancies", obj.occupancies, ...
                "eigenvalues", obj.eigenvalues, ...
                "xyz_data", obj.xyz_data, ...
                "orbitals", obj.orbitals);
        end

        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Access = private)
        function item = readOne(~, filename)
            lines = splitlines(string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename)));
            preamble = "";
            for line = lines.'
                if contains(line, "# of k-points:")
                    preamble = line;
                    break
                end
            end
            counts = regexp(preamble, ...
                ['# of k-points:\s*(\d+)\s+# of bands:\s*(\d+)' ...
                '\s+# of ions:\s*(\d+)'], "tokens", "once");
            if isempty(counts)
                error("KSSOLV:Matgenlab:Procar:Preamble", ...
                    "Failed to locate the PROCAR dimensions.");
            end
            nk = str2double(counts{1});
            nb = str2double(counts{2});
            ni = str2double(counts{3});
            totalCount = 0;
            bandCount = 0;
            for line = lines.'
                trimmed = strtrim(line);
                if startsWith(trimmed, "tot"), totalCount = totalCount + 1; end
                if startsWith(trimmed, "band")
                    bandCount = bandCount + 1;
                    if bandCount == 2, break; end
                end
            end
            if totalCount == 1
                soc = false;
            elseif totalCount == 4
                soc = true;
            else
                error("KSSOLV:Matgenlab:Procar:Corrupt", ...
                    "Projection block count indicates a corrupted PROCAR.");
            end

            item = struct("nions", ni, "nbands", nb, "nkpoints", nk, ...
                "is_soc", soc, "orbitals", strings(1,0), ...
                "kpoints", zeros(nk,3), "weights", zeros(nk,1), ...
                "data", struct(), "phase_factors", struct(), ...
                "eigenvalues", struct(), "occupancies", struct(), ...
                "xyz_data", struct());
            spinName = "down";
            currentK = 0;
            currentBand = 0;
            projectionBlock = 0;
            uniqueKeys = strings(0,1);
            keepCurrent = true;
            skipped = 0;
            parsedKpoints = 0;
            for line = lines.'
                trimmed = strtrim(line);
                if startsWith(trimmed, "k-point")
                    numbers = regexp(extractBefore(trimmed, "weight"), ...
                        '[-+]?(?:\d*\.?\d+)(?:[Ee][-+]?\d+)?', ...
                        "match");
                    if numel(numbers) < 4, continue; end
                    originalK = str2double(numbers{1});
                    if originalK == 1
                        if spinName == "down", spinName = "up";
                        else, spinName = "down";
                        end
                    end
                    vector = round(cellfun(@str2double, ...
                        numbers(end-2:end)), 5);
                    key = sprintf("%.5f,%.5f,%.5f,%s", ...
                        vector, spinName);
                    if any(uniqueKeys == key)
                        keepCurrent = false;
                        skipped = skipped + 1;
                        continue
                    end
                    keepCurrent = true;
                    uniqueKeys(end + 1) = key; %#ok<AGROW>
                    currentK = originalK - skipped;
                    if spinName == "up"
                        item.kpoints(currentK,:) = vector;
                        weightToken = regexp(trimmed, ...
                            'weight\s*=\s*([-+0-9.Ee]+)', ...
                            "tokens", "once");
                        item.weights(currentK) = str2double(weightToken{1});
                        parsedKpoints = max(parsedKpoints, currentK);
                    end
                    if ~isfield(item.data, spinName)
                        item.data.(spinName) = [];
                        item.phase_factors.(spinName) = [];
                        item.eigenvalues.(spinName) = zeros(nk,nb);
                        item.occupancies.(spinName) = zeros(nk,nb);
                    end
                    projectionBlock = 0;
                elseif ~keepCurrent
                    continue
                elseif startsWith(trimmed, "band")
                    tokens = split(trimmed);
                    currentBand = str2double(tokens(2));
                    energy = regexp(trimmed, ...
                        'energy\s+([-+0-9.Ee]+)', "tokens", "once");
                    occupation = regexp(trimmed, ...
                        'occ\.\s+([-+0-9.Ee]+)', "tokens", "once");
                    item.eigenvalues.(spinName)(currentK,currentBand) = ...
                        str2double(energy{1});
                    item.occupancies.(spinName)(currentK,currentBand) = ...
                        str2double(occupation{1});
                    projectionBlock = 0;
                elseif startsWith(trimmed, "ion")
                    header = split(trimmed);
                    header = header(2:end-1);
                    if isempty(item.orbitals)
                        item.orbitals = reshape(header,1,[]);
                        no = numel(header);
                        for field = ["up","down"]
                            if isfield(item.eigenvalues, field)
                                item.data.(field) = zeros(nk,nb,ni,no);
                                item.phase_factors.(field) = ...
                                    complex(nan(nk,nb,ni,no));
                            end
                        end
                        if soc
                            for direction = ["x","y","z"]
                                item.xyz_data.(direction) = ...
                                    zeros(nk,nb,ni,no);
                            end
                        end
                    elseif isempty(item.data.(spinName))
                        no = numel(item.orbitals);
                        item.data.(spinName) = zeros(nk,nb,ni,no);
                        item.phase_factors.(spinName) = ...
                            complex(nan(nk,nb,ni,no));
                    end
                elseif ~isempty(regexp(trimmed, '^\d+\s+', "once"))
                    tokens = split(trimmed);
                    ionIndex = str2double(tokens(1));
                    numbers = str2double(tokens(2:end));
                    no = numel(item.orbitals);
                    if projectionBlock == 0
                        item.data.(spinName)(currentK,currentBand, ...
                            ionIndex,:) = numbers(1:no);
                    elseif soc && projectionBlock < 4
                        direction = ["x","y","z"];
                        item.xyz_data.(direction(projectionBlock))( ...
                            currentK,currentBand,ionIndex,:) = numbers(1:no);
                    elseif numel(numbers) >= 2 * no
                        item.phase_factors.(spinName)(currentK, ...
                            currentBand,ionIndex,:) = complex( ...
                            numbers(1:2:2*no), numbers(2:2:2*no));
                    else
                        existing = squeeze(item.phase_factors.(spinName)( ...
                            currentK,currentBand,ionIndex,:)).';
                        if all(isnan(existing))
                            item.phase_factors.(spinName)(currentK, ...
                                currentBand,ionIndex,:) = numbers(1:no);
                        else
                            item.phase_factors.(spinName)(currentK, ...
                                currentBand,ionIndex,:) = ...
                                existing + 1i * ...
                                reshape(numbers(1:no),1,[]);
                        end
                    end
                elseif startsWith(trimmed, "tot")
                    projectionBlock = projectionBlock + 1;
                end
            end
            item.nkpoints = parsedKpoints;
            item.kpoints = item.kpoints(1:parsedKpoints,:);
            item.weights = item.weights(1:parsedKpoints);
            fields = string(fieldnames(item.data));
            for field = fields.'
                item.data.(field) = item.data.(field)(1:parsedKpoints,:,:,:);
                item.phase_factors.(field) = ...
                    item.phase_factors.(field)(1:parsedKpoints,:,:,:);
                item.eigenvalues.(field) = ...
                    item.eigenvalues.(field)(1:parsedKpoints,:);
                item.occupancies.(field) = ...
                    item.occupancies.(field)(1:parsedKpoints,:);
            end
            if soc
                for direction = ["x","y","z"]
                    item.xyz_data.(direction) = ...
                        item.xyz_data.(direction)(1:parsedKpoints,:,:,:);
                end
            end
        end
    end

    methods (Static, Access = private)
        function files = normalizeFiles(input)
            files = string(input);
            files = reshape(files,1,[]);
            if isempty(files)
                error("KSSOLV:Matgenlab:Procar:Files", ...
                    "At least one PROCAR filename is required.");
            end
        end
    end
end
