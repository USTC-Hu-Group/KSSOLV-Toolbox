classdef BandStructure < kssolv.analysis.matgenlab.util.MSONable
    %BANDSTRUCTURE Spin-resolved eigenvalues on reciprocal-space points.

    properties (SetAccess = protected)
        efermi (1,1) double
        lattice_rec
        kpoints cell
        labels_dict
        structure
        projections (1,1) struct
        bands (1,1) struct
        nb_bands (1,1) double
        is_spin_polarized (1,1) logical
    end

    methods
        function obj = BandStructure(kpoints, eigenvalues, lattice, ...
                efermi, labels, coordsAreCartesian, structure, projections)
            if nargin < 5 || isempty(labels)
                labels = containers.Map( ...
                    "KeyType", "char", "ValueType", "any");
            end
            if nargin < 6 || isempty(coordsAreCartesian)
                coordsAreCartesian = false;
            end
            if nargin < 7, structure = []; end
            if nargin < 8 || isempty(projections), projections = struct(); end
            obj.efermi = double(efermi);
            obj.lattice_rec = lattice;
            obj.structure = structure;
            obj.projections = obj.normalizeSpinMapping(projections);
            if ~isempty(fieldnames(obj.projections)) && isempty(structure)
                error("KSSOLV:Matgenlab:BandStructure:MissingStructure", ...
                    "Projections require an associated structure.");
            end
            labelMap = obj.normalizeLabels(labels);
            obj.labels_dict = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            coordinates = double(kpoints);
            obj.kpoints = cell(1, size(coordinates, 1));
            labelKeys = labelMap.keys;
            for index = 1:size(coordinates, 1)
                label = [];
                for labelIndex = 1:numel(labelKeys)
                    key = labelKeys{labelIndex};
                    target = labelMap(key);
                    if isa(target, ...
                            "kssolv.analysis.matgenlab.electronic_structure.Kpoint")
                        target = target.frac_coords;
                    end
                    target = reshape(double(target), 1, []);
                    if norm(coordinates(index, :) - double(target)) < 1e-4
                        label = string(key);
                        point = kssolv.analysis.matgenlab. ...
                            electronic_structure.Kpoint( ...
                            coordinates(index, :), lattice, false, ...
                            coordsAreCartesian, label);
                        obj.labels_dict(key) = point;
                    end
                end
                obj.kpoints{index} = ...
                    kssolv.analysis.matgenlab.electronic_structure.Kpoint( ...
                    coordinates(index, :), lattice, false, ...
                    coordsAreCartesian, label);
            end
            obj.bands = obj.normalizeSpinMapping(eigenvalues);
            if ~isfield(obj.bands, "up")
                error("KSSOLV:Matgenlab:BandStructure:MissingSpinUp", ...
                    "Eigenvalues require a spin-up channel.");
            end
            obj.nb_bands = size(obj.bands.up, 1);
            if size(obj.bands.up, 2) ~= numel(obj.kpoints)
                error("KSSOLV:Matgenlab:BandStructure:SizeMismatch", ...
                    "Band arrays must have one column per kpoint.");
            end
            obj.is_spin_polarized = isfield(obj.bands, "down");
        end

        function value = is_metal(obj, tolerance)
            if nargin < 2 || isempty(tolerance), tolerance = 1e-4; end
            value = false;
            names = fieldnames(obj.bands);
            for spinIndex = 1:numel(names)
                bandsForSpin = obj.bands.(names{spinIndex});
                for bandIndex = 1:size(bandsForSpin, 1)
                    relative = bandsForSpin(bandIndex, :) - obj.efermi;
                    if any(relative < -tolerance) && ...
                            any(relative > tolerance)
                        value = true;
                        return
                    end
                end
            end
        end

        function value = get_vbm(obj)
            value = obj.bandEdge(false);
        end

        function value = get_cbm(obj)
            value = obj.bandEdge(true);
        end

        function value = get_band_gap(obj)
            if obj.is_metal()
                value = struct("energy", 0, "direct", false, ...
                    "transition", []);
                return
            end
            cbm = obj.get_cbm();
            vbm = obj.get_vbm();
            direct = (~isempty(cbm.kpoint.label) && ...
                isequal(cbm.kpoint.label, vbm.kpoint.label)) || ...
                norm(cbm.kpoint.cart_coords - vbm.kpoint.cart_coords) < 0.01;
            value = struct("energy", cbm.energy - vbm.energy, ...
                "direct", direct, ...
                "transition", obj.transitionText(vbm.kpoint, cbm.kpoint));
        end

        function value = get_direct_band_gap_dict(obj)
            if obj.is_metal()
                error("KSSOLV:Matgenlab:BandStructure:MetalDirectGap", ...
                    "Direct gap details are only defined for non-metals.");
            end
            value = struct();
            names = fieldnames(obj.bands);
            for index = 1:numel(names)
                name = names{index};
                bandsForSpin = obj.bands.(name);
                allAbove = all(bandsForSpin > obj.efermi, 2);
                allBelow = all(bandsForSpin < obj.efermi, 2);
                above = bandsForSpin(allAbove, :);
                below = bandsForSpin(allBelow, :);
                [minimumAbove, conductionIndices] = min(above, [], 1);
                [maximumBelow, valenceIndices] = max(below, [], 1);
                difference = minimumAbove - maximumBelow;
                [gap, kpointIndex] = min(difference);
                valenceOriginal = find(allBelow);
                conductionOriginal = find(allAbove);
                value.(name) = struct( ...
                    "value", gap, ...
                    "kpoint_index", kpointIndex, ...
                    "band_indices", [ ...
                    valenceOriginal(valenceIndices(kpointIndex)), ...
                    conductionOriginal(conductionIndices(kpointIndex))]);
            end
        end

        function value = get_direct_band_gap(obj)
            if obj.is_metal()
                value = 0;
                return
            end
            details = obj.get_direct_band_gap_dict();
            names = fieldnames(details);
            value = min(cellfun(@(name) details.(name).value, names));
        end

        function value = get_projection_on_elements(obj)
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:BandStructure:MissingStructure", ...
                    "structure is required for projected bands.");
            end
            value = struct();
            spins = fieldnames(obj.projections);
            for spinIndex = 1:numel(spins)
                spin = spins{spinIndex};
                array = obj.projections.(spin);
                output = cell(obj.nb_bands, numel(obj.kpoints));
                for bandIndex = 1:obj.nb_bands
                    for pointIndex = 1:numel(obj.kpoints)
                        projected = struct();
                        for siteIndex = 1:obj.structure.num_sites
                            key = matlab.lang.makeValidName(char(string( ...
                                obj.structure.sites{siteIndex}.specie)));
                            if ~isfield(projected, key)
                                projected.(key) = 0;
                            end
                            projected.(key) = projected.(key) + ...
                                sum(array(bandIndex, pointIndex, :, siteIndex), 3);
                        end
                        output{bandIndex, pointIndex} = projected;
                    end
                end
                value.(spin) = output;
            end
        end

        function value = get_projections_on_elements_and_orbitals( ...
                obj, specification)
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:BandStructure:MissingStructure", ...
                    "structure is required for projected bands.");
            end
            value = struct();
            spins = fieldnames(obj.projections);
            for spinIndex = 1:numel(spins)
                spin = spins{spinIndex};
                array = obj.projections.(spin);
                output = cell(obj.nb_bands, numel(obj.kpoints));
                for bandIndex = 1:obj.nb_bands
                    for pointIndex = 1:numel(obj.kpoints)
                        result = struct();
                        requested = fieldnames(specification);
                        for elementIndex = 1:numel(requested)
                            key = requested{elementIndex};
                            orbitals = string(specification.(key));
                            result.(key) = cell2struct( ...
                                num2cell(zeros(size(orbitals))), ...
                                cellstr(matlab.lang.makeValidName(orbitals)), 2);
                        end
                        for siteIndex = 1:obj.structure.num_sites
                            element = matlab.lang.makeValidName(char(string( ...
                                obj.structure.sites{siteIndex}.specie)));
                            if ~isfield(specification, element), continue; end
                            requestedOrbitals = string(specification.(element));
                            for orbitalIndex = 1:size(array, 3)
                                type = extractBefore(string( ...
                                    obj.orbitalNameFromIndex(orbitalIndex)), 2);
                                if any(requestedOrbitals == type)
                                    field = matlab.lang.makeValidName(type);
                                    result.(element).(field) = ...
                                        result.(element).(field) + ...
                                        array(bandIndex, pointIndex, ...
                                        orbitalIndex, siteIndex);
                                end
                            end
                        end
                        output{bandIndex, pointIndex} = result;
                    end
                end
                value.(spin) = output;
            end
        end

        function points = get_sym_eq_kpoints(obj, kpoint, ...
                cartesian, tolerance)
            if nargin < 3 || isempty(cartesian), cartesian = false; end
            if nargin < 4 || isempty(tolerance), tolerance = 1e-2; end
            if isempty(obj.structure)
                points = [];
                return
            end
            analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.structure);
            operations = analyzer.get_point_group_operations(cartesian);
            points = zeros(numel(operations), 3);
            for index = 1:numel(operations)
                if iscell(operations)
                    operation = operations{index};
                else
                    operation = operations(index);
                end
                points(index, :) = reshape(kpoint, 1, 3) * ...
                    operation.rotation_matrix;
            end
            keep = true(size(points, 1), 1);
            for first = 1:size(points, 1)-1
                for second = first+1:size(points, 1)
                    difference = points(first, :) - points(second, :);
                    difference = difference - round(difference);
                    if all(abs(difference) <= tolerance)
                        keep(first) = false;
                        break
                    end
                end
            end
            points = points(keep, :);
        end

        function value = get_kpoint_degeneracy(obj, kpoint, ...
                cartesian, tolerance)
            if nargin < 3, cartesian = []; end
            if nargin < 4, tolerance = []; end
            points = obj.get_sym_eq_kpoints(kpoint, cartesian, tolerance);
            if isempty(obj.structure)
                value = [];
            else
                value = size(points, 1);
            end
        end

        function value = as_dict(obj)
            bandMap = obj.spinMap(obj.bands);
            projectionMap = obj.spinMap(obj.projections);
            labels = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            keys = obj.labels_dict.keys;
            for index = 1:numel(keys)
                key = keys{index};
                wireKey = key;
                if startsWith(key, "$"), wireKey = [' ', key]; end
                labels(wireKey) = obj.labels_dict(key).frac_coords;
            end
            points = cellfun(@(point) point.frac_coords, ...
                obj.kpoints, UniformOutput=false);
            value = struct( ...
                "x_module", "pymatgen.electronic_structure.bandstructure", ...
                "x_class", classShortNameBand(obj), ...
                "lattice_rec", obj.lattice_rec.as_dict(), ...
                "efermi", obj.efermi, ...
                "kpoints", {points}, ...
                "bands", bandMap, ...
                "is_metal", obj.is_metal(), ...
                "labels_dict", labels, ...
                "is_spin_polarized", obj.is_spin_polarized, ...
                "projections", projectionMap);
            if ~isempty(obj.structure)
                value.structure = obj.structure.as_dict();
            end
            value.band_gap = obj.get_band_gap();
            value.vbm = obj.edgeForSerialization(obj.get_vbm());
            value.cbm = obj.edgeForSerialization(obj.get_cbm());
        end

        function value = asDict(obj), value = obj.as_dict(); end
    end

    methods (Static)
        function obj = from_dict(value)
            if isfield(value, "projections") && ...
                    ~isempty(value.projections) && ...
                    ~projectionMappingIsNumeric(value.projections)
                obj = kssolv.analysis.matgenlab.electronic_structure. ...
                    BandStructure.from_old_dict(value);
                return
            end
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_dict(value.lattice_rec);
            labels = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.decodeLabels(value.labels_dict);
            bands = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.decodeSpinMap(value.bands);
            projections = struct();
            if isfield(value, "projections") && ~isempty(value.projections)
                projections = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    BandStructure.decodeSpinMap(value.projections);
            end
            structure = [];
            if isfield(value, "structure")
                structure = kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
            end
            coordinates = decodeBandKpoints(value.kpoints);
            className = "BandStructure";
            if isfield(value, "x_class"), className = string(value.x_class); end
            if contains(className, "SymmLine")
                constructor = str2func( ...
                    "kssolv.analysis.matgenlab.electronic_structure." + ...
                    className);
                obj = constructor(coordinates, bands, lattice, value.efermi, ...
                    labels, false, structure, projections);
            else
                obj = kssolv.analysis.matgenlab.electronic_structure. ...
                    BandStructure(coordinates, bands, lattice, value.efermi, ...
                    labels, false, structure, projections);
            end
        end

        function obj = from_old_dict(value)
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_dict(value.lattice_rec);
            labels = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.decodeLabels(value.labels_dict);
            bands = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.decodeSpinMap(value.bands);
            projections = struct();
            structure = [];
            if isfield(value, "projections") && ~isempty(value.projections)
                if ~isfield(value, "structure")
                    error("KSSOLV:Matgenlab:BandStructure:LegacyStructure", ...
                        "Legacy projections require a structure.");
                end
                structure = kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
                projections = decodeLegacyBandProjections( ...
                    value.projections, bands, false);
            elseif isfield(value, "structure")
                structure = kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
            end
            coordinates = decodeBandKpoints(value.kpoints);
            className = "BandStructure";
            if isfield(value,"x_class")
                className = string(value.x_class);
            end
            if contains(className,"SymmLine")
                constructor = str2func( ...
                    "kssolv.analysis.matgenlab.electronic_structure." + ...
                    className);
                obj = constructor(coordinates,bands,lattice,value.efermi, ...
                    labels,false,structure,projections);
            else
                obj = kssolv.analysis.matgenlab.electronic_structure. ...
                    BandStructure(coordinates,bands,lattice,value.efermi, ...
                    labels,false,structure,projections);
            end
        end
    end

    methods (Access = protected)
        function edge = bandEdge(obj, conduction)
            if obj.is_metal()
                edge = struct("band_index", [], "kpoint_index", [], ...
                    "kpoint", [], "energy", [], "projections", struct());
                return
            end
            if conduction, energy = inf; else, energy = -inf; end
            pointIndex = [];
            names = fieldnames(obj.bands);
            for spinIndex = 1:numel(names)
                array = obj.bands.(names{spinIndex});
                if conduction
                    candidates = find(array >= obj.efermi);
                    [candidateEnergy, location] = min(array(candidates));
                else
                    candidates = find(array < obj.efermi);
                    [candidateEnergy, location] = max(array(candidates));
                end
                if conduction && candidateEnergy < energy || ...
                        ~conduction && candidateEnergy > energy
                    energy = candidateEnergy;
                    linear = candidates(location);
                    [~, pointIndex] = ind2sub(size(array), linear);
                end
            end
            point = obj.kpoints{pointIndex};
            if ~isempty(point.label)
                pointIndices = find(cellfun(@(item) ...
                    isequal(item.label, point.label), obj.kpoints));
            else
                pointIndices = pointIndex;
            end
            bandIndices = struct();
            projection = struct();
            for spinIndex = 1:numel(names)
                name = names{spinIndex};
                array = obj.bands.(name);
                bandIndices.(name) = find( ...
                    abs(array(:, pointIndex) - energy) <= 1e-3).';
                if isfield(obj.projections, name) && ...
                        ~isempty(bandIndices.(name))
                    projection.(name) = squeeze(obj.projections.(name)( ...
                        bandIndices.(name)(1), pointIndices(1), :, :));
                end
            end
            edge = struct("band_index", bandIndices, ...
                "kpoint_index", pointIndices, "kpoint", point, ...
                "energy", energy, "projections", projection);
        end

        function value = transitionText(~, first, second)
            value = pointName(first) + "-" + pointName(second);
        end

        function value = edgeForSerialization(~, edge)
            value = edge;
            if isstruct(edge.band_index)
                value.band_index = ...
                    kssolv.analysis.matgenlab.electronic_structure. ...
                    BandStructure.spinMapStatic(edge.band_index);
            end
            value = rmfield(value, "kpoint");
        end

        function value = spinMap(~, input)
            value = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.spinMapStatic(input);
        end
    end

    methods (Static, Access = protected)
        function value = normalizeSpinMapping(input)
            if isempty(input)
                value = struct();
            elseif isstruct(input)
                value = struct();
                names = fieldnames(input);
                for index = 1:numel(names)
                    field = names{index};
                    normalized = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        BandStructure.spinField(field);
                    value.(normalized) = double(input.(field));
                end
            elseif isa(input, "containers.Map")
                value = struct();
                keys = input.keys;
                for index = 1:numel(keys)
                    field = ...
                        kssolv.analysis.matgenlab.electronic_structure. ...
                        BandStructure.spinField(keys{index});
                    value.(field) = double(input(keys{index}));
                end
            else
                error("KSSOLV:Matgenlab:BandStructure:InvalidSpinMapping", ...
                    "Spin data must be a struct or containers.Map.");
            end
        end

        function value = spinField(input)
            if isa(input, ...
                    "kssolv.analysis.matgenlab.electronic_structure.Spin")
                input = double(input);
            end
            text = lower(string(input));
            if any(text == ["1", "up", "x1"])
                value = "up";
            elseif any(text == ["-1", "down", "x_1"])
                value = "down";
            else
                error("KSSOLV:Matgenlab:BandStructure:InvalidSpin", ...
                    "Invalid spin identifier.");
            end
        end

        function value = normalizeLabels(input)
            if isa(input, "containers.Map")
                value = input;
            elseif isstruct(input)
                names = fieldnames(input);
                values = cellfun(@(name) input.(name), names, ...
                    UniformOutput=false);
                value = containers.Map(names, values, ...
                    "UniformValues", false);
            else
                error("KSSOLV:Matgenlab:BandStructure:InvalidLabels", ...
                    "labels_dict must be a struct or containers.Map.");
            end
        end

        function value = spinMapStatic(input)
            keys = cell(1, 0);
            values = cell(1, 0);
            if isfield(input, "up")
                keys{end+1} = '1'; values{end+1} = input.up;
            end
            if isfield(input, "down")
                keys{end+1} = '-1'; values{end+1} = input.down;
            end
            if isempty(keys)
                value = struct();
            else
                value = containers.Map(keys, values, ...
                    "UniformValues", false);
            end
        end

        function value = decodeSpinMap(input)
            value = ...
                kssolv.analysis.matgenlab.electronic_structure. ...
                BandStructure.normalizeSpinMapping(input);
        end

        function value = decodeLabels(input)
            if isa(input, "containers.Map")
                keys = input.keys;
                values = cellfun(@(key) input(key), keys, ...
                    UniformOutput=false);
            else
                keys = fieldnames(input);
                values = cellfun(@(key) input.(key), keys, ...
                    UniformOutput=false);
            end
            keys = cellfun(@strtrim, keys, UniformOutput=false);
            for index = 1:numel(keys)
                if startsWith(keys{index}, "x_")
                    keys{index} = ['\', keys{index}(3:end)];
                end
            end
            value = containers.Map(keys, values, ...
                "UniformValues", false);
        end

        function value = orbitalNameFromIndex(index)
            names = ["s","py","pz","px","dxy","dyz","dz2","dxz", ...
                "dx2","f_3","f_2","f_1","f0","f1","f2","f3"];
            value = names(index);
        end

        function value = decodeLegacyProjectionMap(input,bands,lobster)
            if nargin < 3, lobster = false; end
            value = decodeLegacyBandProjections(input,bands,lobster);
        end
    end
end

function value = classShortNameBand(obj)
name = split(string(class(obj)), ".");
value = name(end);
end

function value = pointName(point)
if ~isempty(point.label)
    value = string(point.label);
else
    value = "(" + strjoin(compose("%.3f", point.frac_coords), ",") + ")";
end
end

function coordinates = decodeBandKpoints(input)
if isnumeric(input)
    coordinates = double(input);
elseif iscell(input)
    coordinates = cell2mat(reshape(input,[],1));
else
    error("KSSOLV:Matgenlab:BandStructure:Kpoints", ...
        "kpoints must be a numeric array or cell array.");
end
coordinates = reshape(coordinates,[],3);
end

function value = projectionMappingIsNumeric(input)
if isa(input,"containers.Map")
    keys = input.keys;
    if isempty(keys), value = true; else
        value = isnumeric(input(keys{1}));
    end
elseif isstruct(input)
    names = fieldnames(input);
    if isempty(names), value = true; else
        value = isnumeric(input.(names{1}));
    end
else
    value = false;
end
end

function projections = decodeLegacyBandProjections(input,bands,lobster)
if nargin < 3, lobster = false; end
if isa(input,"containers.Map")
    keys=input.keys;
    values=cellfun(@(key)input(key),keys,UniformOutput=false);
else
    keys=fieldnames(input);
    values=cellfun(@(key)input.(key),keys,UniformOutput=false);
end
projections=struct();
orbitalNames={'s','py','pz','px','dxy','dyz','dz2','dxz', ...
    'dx2','f_3','f_2','f_1','f0','f1','f2','f3'};
for spinIndex=1:numel(keys)
    key=lower(string(keys{spinIndex}));
    if any(key==["1","up","x1"])
        field="up";
    elseif any(key==["-1","down","x_1"])
        field="down";
    else
        error("KSSOLV:Matgenlab:BandStructure:InvalidSpin", ...
            "Invalid spin identifier in legacy projections.");
    end
    field=char(field);
    bandArray=bands.(field);
    legacy=values{spinIndex};
    first=legacyNestedValue(legacy,1,1);
    if lobster
        firstValues=double(first);
        siteCount=size(firstValues,2);
        orbitalCount=size(firstValues,1);
    else
        names=fieldnames(first);
        orbitalCount=numel(names);
        siteCount=numel(first.(orbitalNames{1}));
    end
    decoded=zeros(size(bandArray,1),size(bandArray,2), ...
        orbitalCount,siteCount);
    for bandIndex=1:size(bandArray,1)
        for pointIndex=1:size(bandArray,2)
            entry=legacyNestedValue(legacy,bandIndex,pointIndex);
            if lobster
                array=double(entry);
                decoded(bandIndex,pointIndex,:,:) = ...
                    reshape(array,1,1,size(array,1),size(array,2));
            else
                for orbitalIndex=1:orbitalCount
                    name=orbitalNames{orbitalIndex};
                    decoded(bandIndex,pointIndex,orbitalIndex,:) = ...
                        reshape(double(entry.(name)),1,1,1,[]);
                end
            end
        end
    end
    projections.(field)=decoded;
end
end

function value = legacyNestedValue(input,first,second)
if iscell(input)
    if ismatrix(input) && size(input,1)>=first && size(input,2)>=second && ...
            ~iscell(input{first,second})
        value=input{first,second};
    else
        row=input{first};
        if iscell(row), value=row{second};
        elseif isstruct(row), value=row(second);
        else, value=squeeze(row(second,:,:,:));
        end
    end
elseif isstruct(input)
    if ismatrix(input), value=input(first,second);
    else, value=input(first);
    end
else
    value=squeeze(input(first,second,:,:));
end
if iscell(value) && isscalar(value), value=value{1}; end
end
