classdef Critic2Analysis < handle
    %CRITIC2ANALYSIS Parse Critic2 JSON or standard output.
    %
    % Public site and critical-point indices are one-based in MATLAB.

    properties (SetAccess = private)
        structure
        critical_points cell = cell(1, 0)
        nodes cell = cell(1, 0)
        edges cell = cell(1, 0)
        stdout (1,1) string = ""
        stderr (1,1) string = ""
        cpreport = []
        yt = []
        zpsp = []
    end

    properties (Access = private)
        node_values cell = cell(1, 0)
    end

    methods
        function obj = Critic2Analysis(structure, stdout, stderr, ...
                cpreport, yt, zpsp)
            if nargin == 0, return; end
            if nargin < 2 || isempty(stdout), stdout = ""; end
            if nargin < 3 || isempty(stderr), stderr = ""; end
            if nargin < 4, cpreport = []; end
            if nargin < 5, yt = []; end
            if nargin < 6, zpsp = []; end
            obj.structure = structure;
            obj.stdout = string(stdout);
            obj.stderr = string(stderr);
            obj.cpreport = cpreport;
            obj.yt = yt;
            obj.zpsp = zpsp;
            if ~isempty(yt)
                obj.annotateStructureWithYt(yt, zpsp);
            end
            if ~isempty(cpreport)
                obj.parseCpreport(cpreport);
            elseif strlength(obj.stdout) > 0
                obj.parseStdout(obj.stdout);
            else
                error("KSSOLV:Matgenlab:Critic2:AnalysisInput", ...
                    "One of cpreport or stdout is required.");
            end
            obj.remapIndices();
        end

        function graph = structure_graph(obj, includeCriticalPoints)
            if nargin < 2
                includeCriticalPoints = ["bond", "ring", "cage"];
            end
            includeCriticalPoints = string(includeCriticalPoints);
            structureCopy = obj.structure.copy();
            pointToStructure = zeros(1, numel(obj.nodes));
            if ~isempty(includeCriticalPoints)
                zerosBySite = zeros(1, structureCopy.num_sites);
                structureCopy = structureCopy.add_site_property( ...
                    "ellipticity", zerosBySite);
                structureCopy = structureCopy.add_site_property( ...
                    "laplacian", zerosBySite);
                structureCopy = structureCopy.add_site_property( ...
                    "field", zerosBySite);
                for index = 1:numel(obj.nodes)
                    if isempty(obj.nodes{index}), continue; end
                    point = obj.critical_points{ ...
                        obj.nodes{index}.unique_idx};
                    if any(includeCriticalPoints == string(point.type))
                        symbol = "X" + extractBefore( ...
                            string(point.type), 2) + "cp";
                        specie = kssolv.analysis.matgenlab.core. ...
                            DummySpecies(symbol, NaN);
                        structureCopy = structureCopy.append( ...
                            specie, obj.nodes{index}.frac_coords, ...
                            properties = struct( ...
                            "ellipticity", point.ellipticity, ...
                            "laplacian", point.laplacian, ...
                            "field", point.field));
                        pointToStructure(index) = ...
                            structureCopy.num_sites;
                    end
                end
            end
            graph = kssolv.analysis.matgenlab.core.StructureGraph. ...
                from_empty_graph(structureCopy, ...
                "name", "bonds", ...
                "edge_weight_name", "bond_length", ...
                "edge_weight_units", "Å");

            duplicate = false(1, numel(obj.edges));
            for index = 1:numel(obj.edges)
                if isempty(obj.edges{index}) || duplicate(index), continue; end
                point = obj.pointForNode(index);
                if point.type ~= kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.bond
                    continue
                end
                for second = index + 1:numel(obj.edges)
                    if ~isempty(obj.edges{second}) && ...
                            isequal(obj.edges{index}, obj.edges{second})
                        duplicate(second) = true;
                        warning("KSSOLV:Matgenlab:Critic2:DuplicateEdge", ...
                            "Duplicate edge detected; rerun Critic2 " + ...
                            "with custom parameters if necessary.");
                    end
                end
            end

            for index = 1:numel(obj.edges)
                if isempty(obj.edges{index}) || duplicate(index), continue; end
                point = obj.pointForNode(index);
                if point.type ~= kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.bond
                    continue
                end
                edge = obj.edges{index};
                fromIndex = edge.from_idx;
                toIndex = edge.to_idx;
                if ~isempty(includeCriticalPoints) && ...
                        ~any(includeCriticalPoints == "nnattr")
                    fromType = obj.pointForNode(fromIndex).type;
                    toType = obj.pointForNode(toIndex).type;
                    nucleus = kssolv.analysis.matgenlab.command_line. ...
                        critic2_caller.CriticalPointType.nucleus;
                    if fromType ~= nucleus || toType ~= nucleus
                        continue
                    end
                end
                graphFrom = fromIndex;
                graphTo = toIndex;
                if fromIndex <= numel(pointToStructure) && ...
                        pointToStructure(fromIndex) > 0
                    graphFrom = pointToStructure(fromIndex);
                end
                if toIndex <= numel(pointToStructure) && ...
                        pointToStructure(toIndex) > 0
                    graphTo = pointToStructure(toIndex);
                end
                relativeImage = edge.to_lvec - edge.from_lvec;
                weight = structureCopy.get_distance( ...
                    graphFrom, graphTo, relativeImage);
                properties = struct("field", point.field, ...
                    "laplacian", point.laplacian, ...
                    "ellipticity", point.ellipticity, ...
                    "frac_coords", obj.nodes{index}.frac_coords);
                graph.add_edge(graphFrom, graphTo, ...
                    "from_jimage", edge.from_lvec, ...
                    "to_jimage", edge.to_lvec, ...
                    "weight", weight, ...
                    "edge_properties", properties);
            end
        end

        function point = get_critical_point_for_site(obj, index)
            obj.validateNode(index);
            point = obj.critical_points{obj.nodes{index}.unique_idx};
        end

        function value = get_volume_and_charge_for_site(obj, index)
            if isempty(obj.node_values)
                value = [];
                return
            end
            if index < 1 || index > numel(obj.node_values) || ...
                    isempty(obj.node_values{index})
                error("KSSOLV:Matgenlab:Critic2:SiteIndex", ...
                    "Site index is outside the YT integration data.");
            end
            value = obj.node_values{index};
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.command_line.critic2_caller", ...
                "x_class", "Critic2Analysis", ...
                "structure", obj.structure.as_dict(), ...
                "stdout", obj.stdout, ...
                "stderr", obj.stderr, ...
                "cpreport", obj.cpreport, ...
                "yt", obj.yt, ...
                "zpsp", obj.zpsp);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_dict(value)
            structure = value.structure;
            if isstruct(structure)
                structure = kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(structure);
            end
            obj = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.Critic2Analysis(structure, ...
                getField(value, "stdout", ""), ...
                getField(value, "stderr", ""), ...
                getField(value, "cpreport", []), ...
                getField(value, "yt", []), ...
                getField(value, "zpsp", []));
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.Critic2Analysis.from_dict(value);
        end
    end

    methods (Access = private)
        function parseCpreport(obj, report)
            points = asCell(report.critical_points.nonequivalent_cps);
            obj.critical_points = cell(1, numel(points));
            units = string(report.units);
            for index = 1:numel(points)
                source = points{index};
                type = signatureType(source.signature, source.is_nucleus);
                coords = [];
                if units == "bohr"
                    coords = reshape(double( ...
                        source.cartesian_coordinates), 1, 3) * ...
                        0.529177210903;
                end
                pointIndex = double(source.id);
                obj.critical_points{pointIndex} = ...
                    kssolv.analysis.matgenlab.command_line. ...
                    critic2_caller.CriticalPoint( ...
                    pointIndex, type, source.fractional_coordinates, ...
                    source.point_group, source.multiplicity, ...
                    source.field, source.gradient, coords, source.hessian);
            end
            cellPoints = asCell(report.critical_points.cell_cps);
            for index = 1:numel(cellPoints)
                source = cellPoints{index};
                obj.addNode(double(source.id), ...
                    double(source.nonequivalent_id), ...
                    source.fractional_coordinates);
                if isfield(source, "attractors") && ...
                        numel(source.attractors) >= 2
                    attractors = asCell(source.attractors);
                    obj.addEdge(double(source.id), ...
                        double(attractors{1}.cell_id), ...
                        attractors{1}.lvec, ...
                        double(attractors{2}.cell_id), ...
                        attractors{2}.lvec);
                end
            end
        end

        function parseStdout(obj, text)
            warning("KSSOLV:Matgenlab:Critic2:DeprecatedStdout", ...
                "Parsing Critic2 standard output is deprecated upstream; " + ...
                "prefer native CPREPORT JSON.");
            lines = splitlines(string(text));
            startIndex = find(contains(lines, "mult  name"), 1) + 1;
            endIndex = find(contains(lines, ...
                "* Analysis of system bonds"), 1) - 1;
            if isempty(startIndex) || isempty(endIndex)
                error("KSSOLV:Matgenlab:Critic2:StdoutFormat", ...
                    "Could not locate the non-equivalent CP table.");
            end
            for lineIndex = startIndex:endIndex
                line = strtrim(lines(lineIndex));
                if strlength(line) == 0, continue; end
                tokens = split(regexprep(line, "[()]", ""));
                tokens(tokens == "") = [];
                if numel(tokens) < 12, continue; end
                pointIndex = str2double(tokens(1));
                point = kssolv.analysis.matgenlab.command_line. ...
                    critic2_caller.CriticalPoint( ...
                    pointIndex, tokens(4), ...
                    str2double(tokens(5:7)).', tokens(2), ...
                    str2double(tokens(8)), str2double(tokens(10)), ...
                    str2double(tokens(11)));
                obj.critical_points{pointIndex} = point;
            end
            current = NaN;
            for lineIndex = 1:numel(lines)
                line = lines(lineIndex);
                if contains(line, "+ Critical point no.")
                    tokens = regexp(char(line), ...
                        'Critical point no\.\s*(\d+)', "tokens", "once");
                    if ~isempty(tokens), current = str2double(tokens{1}); end
                elseif contains(line, "Hessian:") && ~isnan(current)
                    if lineIndex + 3 > numel(lines)
                        error("KSSOLV:Matgenlab:Critic2:StdoutFormat", ...
                            "Incomplete Hessian in Critic2 output.");
                    end
                    hessian = zeros(3);
                    for row = 1:3
                        hessian(row, :) = sscanf( ...
                            char(lines(lineIndex + row)), "%f", 3).';
                    end
                    obj.critical_points{current}.field_hessian = hessian;
                end
            end
            startIndex = find(contains(lines, "#cp  ncp   typ"), 1) + 1;
            endIndex = find(contains(lines, ...
                "* Attractor connectivity matrix"), 1) - 1;
            if isempty(startIndex) || isempty(endIndex)
                error("KSSOLV:Matgenlab:Critic2:StdoutFormat", ...
                    "Could not locate the complete CP table.");
            end
            for lineIndex = startIndex:endIndex
                line = strtrim(lines(lineIndex));
                if strlength(line) == 0, continue; end
                tokens = split(regexprep(line, "[()]", ""));
                tokens(tokens == "") = [];
                if numel(tokens) < 6, continue; end
                pointIndex = str2double(tokens(1));
                uniqueIndex = str2double(tokens(2));
                if isnan(pointIndex) || isnan(uniqueIndex), continue; end
                obj.addNode(pointIndex, uniqueIndex, ...
                    str2double(tokens(4:6)).');
                if numel(tokens) >= 14
                    obj.addEdge(pointIndex, str2double(tokens(7)), ...
                        str2double(tokens(8:10)).', ...
                        str2double(tokens(11)), ...
                        str2double(tokens(12:14)).');
                end
            end
        end

        function remapIndices(obj)
            mapping = zeros(1, numel(obj.nodes));
            target = mod(obj.structure.frac_coords, 1);
            nucleus = kssolv.analysis.matgenlab.command_line. ...
                critic2_caller.CriticalPointType.nucleus;
            for index = 1:numel(obj.nodes)
                if isempty(obj.nodes{index}), continue; end
                point = obj.critical_points{ ...
                    obj.nodes{index}.unique_idx};
                if point.type == nucleus
                    delta = target - obj.nodes{index}.frac_coords;
                    [~, mapping(index)] = min(sum(delta .^ 2, 2));
                end
            end
            if nnz(mapping) ~= obj.structure.num_sites
                warning("KSSOLV:Matgenlab:Critic2:SiteCount", ...
                    "Input has %d sites but Critic2 detected %d nuclei.", ...
                    obj.structure.num_sites, nnz(mapping));
            end
            remappedNodes = cell(size(obj.nodes));
            for index = 1:numel(obj.nodes)
                if mapping(index) > 0, destination = mapping(index);
                else, destination = index;
                end
                remappedNodes{destination} = obj.nodes{index};
            end
            obj.nodes = remappedNodes;
            for index = 1:numel(obj.edges)
                if isempty(obj.edges{index}), continue; end
                edge = obj.edges{index};
                if edge.from_idx <= numel(mapping) && ...
                        mapping(edge.from_idx) > 0
                    edge.from_idx = mapping(edge.from_idx);
                end
                if edge.to_idx <= numel(mapping) && mapping(edge.to_idx) > 0
                    edge.to_idx = mapping(edge.to_idx);
                end
                obj.edges{index} = edge;
            end
        end

        function annotateStructureWithYt(obj, yt, zpsp)
            properties = asCell(yt.integration.properties);
            volumeIndex = NaN;
            chargeIndex = NaN;
            for index = 1:numel(properties)
                item = properties{index};
                if string(item.label) == "Volume"
                    volumeIndex = double(item.id);
                elseif string(item.label) == "$chg_int"
                    chargeIndex = double(item.id);
                end
            end
            if isnan(volumeIndex) || isnan(chargeIndex)
                error("KSSOLV:Matgenlab:Critic2:YtProperties", ...
                    "YT integration lacks Volume or $chg_int.");
            end
            attractors = asCell(yt.integration.attractors);
            atoms = asCell(yt.structure.cell_atoms);
            count = numel(atoms);
            if count ~= obj.structure.num_sites
                error("KSSOLV:Matgenlab:Critic2:YtSiteCount", ...
                    "YT integration and Structure site counts differ.");
            end
            volumes = zeros(1, count);
            charges = zeros(1, count);
            transfers = zeros(1, count);
            obj.node_values = cell(1, count);
            for index = 1:count
                atom = atoms{index};
                if any(abs(obj.structure.frac_coords(index, :) - ...
                        reshape(double(atom.fractional_coordinates), 1, 3)) ...
                        > 1e-8)
                    error("KSSOLV:Matgenlab:Critic2:YtSiteMismatch", ...
                        "Structure site %d does not match YT integration.", ...
                        index);
                end
                nonequivalent = double(atom.nonequivalent_id);
                attractor = attractors{nonequivalent};
                if double(attractor.id) ~= nonequivalent
                    error("KSSOLV:Matgenlab:Critic2:YtOrdering", ...
                        "YT attractor list is not ordered by id.");
                end
                integrals = double(attractor.integrals);
                volumes(index) = integrals(volumeIndex);
                charges(index) = integrals(chargeIndex);
                obj.node_values{index} = struct( ...
                    "volume", volumes(index), "charge", charges(index));
                if ~isempty(zpsp)
                    symbol = obj.structure(index).species_string;
                    [found, valence] = mapLookup(zpsp, symbol);
                    if ~found
                        error("KSSOLV:Matgenlab:Critic2:ZpspSpecies", ...
                            "zpsp does not contain species '%s'.", symbol);
                    end
                    transfers(index) = charges(index) - valence;
                end
            end
            obj.structure = obj.structure.copy();
            obj.structure = obj.structure.add_site_property( ...
                "bader_volume", volumes);
            obj.structure = obj.structure.add_site_property( ...
                "bader_charge", charges);
            if ~isempty(zpsp)
                obj.structure = obj.structure.add_site_property( ...
                    "bader_charge_transfer", transfers);
            end
        end

        function addNode(obj, index, uniqueIndex, fracCoords)
            obj.nodes{index} = struct("unique_idx", uniqueIndex, ...
                "frac_coords", reshape(double(fracCoords), 1, 3));
        end

        function addEdge(obj, index, fromIndex, fromVector, ...
                toIndex, toVector)
            obj.edges{index} = struct( ...
                "from_idx", double(fromIndex), ...
                "from_lvec", reshape(double(fromVector), 1, 3), ...
                "to_idx", double(toIndex), ...
                "to_lvec", reshape(double(toVector), 1, 3));
        end

        function point = pointForNode(obj, index)
            obj.validateNode(index);
            point = obj.critical_points{obj.nodes{index}.unique_idx};
        end

        function validateNode(obj, index)
            if ~isscalar(index) || index < 1 || index ~= fix(index) || ...
                    index > numel(obj.nodes) || isempty(obj.nodes{index})
                error("KSSOLV:Matgenlab:Critic2:NodeIndex", ...
                    "Critical-point node index is invalid.");
            end
        end
    end
end

function type = signatureType(signature, isNucleus)
switch double(signature)
    case 3
        type = "cage";
    case 1
        type = "ring";
    case -1
        type = "bond";
    case -3
        if logical(isNucleus), type = "nucleus";
        else, type = "nnattr";
        end
    otherwise
        error("KSSOLV:Matgenlab:Critic2:Signature", ...
            "Unknown critical-point signature %g.", double(signature));
end
end

function value = asCell(input)
if isempty(input), value = cell(1, 0);
elseif iscell(input), value = reshape(input, 1, []);
elseif isstruct(input), value = num2cell(reshape(input, 1, []));
else
    error("KSSOLV:Matgenlab:Critic2:JsonShape", ...
        "Expected a JSON object array.");
end
end

function value = getField(input, name, default)
if isfield(input, name), value = input.(name);
else, value = default;
end
end

function [found, value] = mapLookup(mapping, key)
if isa(mapping, "containers.Map")
    found = isKey(mapping, char(key));
    if found, value = double(mapping(char(key))); else, value = NaN; end
elseif isstruct(mapping)
    found = isfield(mapping, char(key));
    if found, value = double(mapping.(char(key))); else, value = NaN; end
else
    error("KSSOLV:Matgenlab:Critic2:Zpsp", ...
        "zpsp must be a struct or containers.Map.");
end
end
