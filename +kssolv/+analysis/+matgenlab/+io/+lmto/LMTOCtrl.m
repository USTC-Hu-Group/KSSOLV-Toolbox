classdef LMTOCtrl
    %LMTOCTRL Read and write Stuttgart LMTO-ASA CTRL structure files.

    properties (SetAccess = private)
        structure
        header
        version
    end

    methods
        function obj = LMTOCtrl(structure, header, version)
            if nargin < 2, header = []; end
            if nargin < 3, version = "LMASA-47"; end
            if ~isa(structure, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:LMTOCtrl:Structure", ...
                    "structure must be a Structure or IStructure.");
            end
            obj.structure = structure;
            obj.header = header;
            obj.version = version;
        end

        function text = get_str(obj, sigfigs)
            if nargin < 2, sigfigs = 8; end
            dictionary = obj.as_dict();
            lines = strings(0, 1);
            if isfield(dictionary, "HEADER")
                lines(end + 1) = sprintf("%-10s%s", ...
                    "HEADER", string(obj.header));
            end
            if isfield(dictionary, "VERS")
                lines(end + 1) = sprintf("%-10s%s", ...
                    "VERS", string(obj.version));
            end
            lines(end + 1) = sprintf("%-10sALAT=%.*f", ...
                "STRUC", sigfigs, dictionary.ALAT);
            for index = 1:3
                if index == 1, prefix = sprintf("%15s", "PLAT=");
                else, prefix = repmat(' ', 1, 15);
                end
                values = composeNumber(dictionary.PLAT(index, :), sigfigs);
                lines(end + 1) = prefix + strjoin(values, " "); %#ok<AGROW>
            end
            categories = ["CLASS", "SITE"];
            for category = categories
                entries = dictionary.(category);
                for index = 1:numel(entries)
                    if index == 1
                        tokens = sprintf("%-9s", category);
                    else
                        tokens = repmat(' ', 1, 9);
                    end
                    record = entries{index};
                    names = sort(string(fieldnames(record)));
                    for fieldIndex = 1:numel(names)
                        name = names(fieldIndex);
                        if name == "POS"
                            rendered = strjoin(composeNumber( ...
                                record.(name), sigfigs), " ");
                            tokens = tokens + " POS=" + rendered;
                        else
                            tokens = tokens + " " + name + "=" + ...
                                string(record.(name));
                        end
                    end
                    lines(end + 1) = tokens; %#ok<AGROW>
                end
            end
            text = strjoin(lines, newline) + newline;
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.lmto", ...
                "x_class", "LMTOCtrl");
            if ~isempty(obj.header), value.HEADER = string(obj.header); end
            if ~isempty(obj.version), value.VERS = string(obj.version); end
            analyzer = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.structure);
            conventional = analyzer. ...
                get_conventional_standard_structure();
            latticeParameter = conventional.lattice.lengths(1);
            dataset = analyzer.get_symmetry_dataset();
            equivalents = dataset.equivalent_atoms;
            inequivalent = unique(equivalents, "stable");
            classes = cell(1, numel(inequivalent));
            classForRepresentative = containers.Map( ...
                "KeyType", "double", "ValueType", "char");
            speciesCounts = containers.Map( ...
                "KeyType", "char", "ValueType", "double");
            classCount = 0;
            for siteIndex = 1:obj.structure.num_sites
                representative = equivalents(siteIndex);
                if ~isKey(classForRepresentative, representative)
                    symbol = char(obj.structure(siteIndex).specie.symbol);
                    if isKey(speciesCounts, symbol)
                        suffix = speciesCounts(symbol);
                        speciesCounts(symbol) = suffix + 1;
                        label = symbol + string(suffix);
                    else
                        speciesCounts(symbol) = 1;
                        label = string(symbol);
                    end
                    classCount = classCount + 1;
                    classes{classCount} = struct( ...
                        "ATOM", label, ...
                        "Z", obj.structure(siteIndex).specie.Z);
                    classForRepresentative(representative) = char(label);
                end
            end
            sites = cell(1, obj.structure.num_sites);
            for siteIndex = 1:obj.structure.num_sites
                label = string(classForRepresentative( ...
                    equivalents(siteIndex)));
                sites{siteIndex} = struct("ATOM", label, ...
                    "POS", obj.structure(siteIndex).coords / ...
                    latticeParameter);
            end
            value.ALAT = latticeParameter / ...
                kssolv.analysis.matgenlab.core.bohr_to_angstrom();
            value.PLAT = obj.structure.lattice.matrix / latticeParameter;
            value.CLASS = classes;
            value.SITE = sites;
        end

        function write_file(obj, filename, varargin)
            if nargin < 2, filename = "CTRL"; end
            sigfigs = 8;
            if ~isempty(varargin)
                if numel(varargin) ~= 2 || ...
                        string(varargin{1}) ~= "sigfigs"
                    error("KSSOLV:Matgenlab:LMTOCtrl:WriteOptions", ...
                        "Only the sigfigs name/value option is supported.");
                end
                sigfigs = varargin{2};
            end
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, obj.get_str(sigfigs));
        end

        function value = char(obj), value = char(obj.get_str()); end
        function value = string(obj), value = obj.get_str(); end
        function value = eq(obj, other)
            value = isa(other, class(obj)) && ...
                obj.get_str() == other.get_str();
        end
        function value = ne(obj, other), value = ~eq(obj, other); end
    end

    methods (Static)
        function obj = from_file(filename, varargin)
            if nargin < 1, filename = "CTRL"; end
            text = string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
            obj = ...
                kssolv.analysis.matgenlab.io.lmto.LMTOCtrl. ...
                from_str(text, varargin{:});
        end

        function obj = from_str(data, sigfigs)
            if nargin < 2, sigfigs = 8; end
            lines = splitlines(string(data));
            categories = ["HEADER", "VERS", "SYMGRP", ...
                "STRUC", "CLASS", "SITE"];
            grouped = struct();
            for category = categories
                grouped.(category) = strings(0, 1);
            end
            active = "";
            for line = reshape(lines, 1, [])
                if strlength(strtrim(line)) == 0, continue; end
                if ~isspace(char(extractBetween(line, 1, 1)))
                    active = extractBefore(strtrim(line) + " ", " ");
                end
                if any(active == categories)
                    grouped.(active)(end + 1) = line;
                end
            end
            combined = struct();
            for category = categories
                combined.(category) = regexprep( ...
                    strjoin(grouped.(category), " "), "=\s+", "=");
            end
            alatToken = regexp(combined.STRUC, ...
                "ALAT\s*=\s*([-+0-9.eEdD]+)", "tokens", "once");
            platToken = regexp(combined.STRUC, ...
                "PLAT\s*=\s*([-+0-9.eEdD\s]+)", "tokens", "once");
            if isempty(alatToken) || isempty(platToken)
                error("KSSOLV:Matgenlab:LMTOCtrl:StructureTokens", ...
                    "CTRL must define ALAT and a 3-by-3 PLAT.");
            end
            value = struct();
            value.ALAT = round(str2double( ...
                replace(string(alatToken{1}), ...
                ["d", "D"], ["e", "E"])), sigfigs);
            plat = sscanf(replace(string(platToken{1}), ...
                ["d", "D"], ["e", "E"]), "%f");
            if numel(plat) ~= 9
                error("KSSOLV:Matgenlab:LMTOCtrl:Plat", ...
                    "PLAT must contain nine values.");
            end
            value.PLAT = reshape(round(plat, sigfigs), 3, 3).';
            classTokens = regexp(combined.CLASS, ...
                "ATOM\s*=\s*(\S+)", "tokens");
            value.CLASS = cell(1, 0);
            for index = 1:numel(classTokens)
                label = string(classTokens{index}{1});
                if isempty(regexp(label, "^E\d*$", "once"))
                    value.CLASS{end + 1} = label;
                end
            end
            siteTokens = regexp(combined.SITE, ...
                "ATOM\s*=\s*(\S+)\s+POS\s*=\s*" + ...
                "([-+0-9.eEdD\s]+?)(?=\s+ATOM\s*=|$)", "tokens");
            value.SITE = cell(1, 0);
            for index = 1:numel(siteTokens)
                label = string(siteTokens{index}{1});
                if ~isempty(regexp(label, "^E\d*$", "once")), continue; end
                position = sscanf(replace(string(siteTokens{index}{2}), ...
                    ["d", "D"], ["e", "E"]), "%f").';
                if numel(position) ~= 3
                    error("KSSOLV:Matgenlab:LMTOCtrl:Position", ...
                        "Each SITE POS must contain three values.");
                end
                value.SITE{end + 1} = struct( ...
                    "ATOM", label, ...
                    "POS", round(position, sigfigs));
            end
            groupToken = regexp(combined.SYMGRP, ...
                "SPCGRP\s*=\s*(\S+)", "tokens", "once");
            if ~isempty(groupToken)
                value.SPCGRP = string(groupToken{1});
            end
            for token = ["HEADER", "VERS"]
                expression = "^" + token + "\s*(.*)$";
                match = regexp(strtrim(combined.(token)), ...
                    expression, "tokens", "once");
                if ~isempty(match) && strlength(strtrim(match{1})) > 0
                    value.(token) = strtrim(string(match{1}));
                end
            end
            obj = ...
                kssolv.analysis.matgenlab.io.lmto.LMTOCtrl. ...
                from_dict(value);
        end

        function obj = from_dict(value)
            header = [];
            version = [];
            if isfield(value, "HEADER"), header = value.HEADER; end
            if isfield(value, "VERS"), version = value.VERS; end
            alat = double(value.ALAT) * ...
                kssolv.analysis.matgenlab.core.bohr_to_angstrom();
            lattice = double(value.PLAT) * alat;
            sites = value.SITE;
            species = cell(1, numel(sites));
            positions = zeros(numel(sites), 3);
            for index = 1:numel(sites)
                if isstruct(sites), site = sites(index);
                else, site = sites{index};
                end
                label = string(site.ATOM);
                species{index} = regexprep(label, "[0-9*].*$", "");
                positions(index, :) = double(site.POS) * alat;
            end
            structure = [];
            if isfield(value, "CLASS") && isfield(value, "SPCGRP") && ...
                    numel(sites) == numel(value.CLASS)
                try
                    structure = ...
                        kssolv.analysis.matgenlab.core.Structure. ...
                        from_spacegroup(value.SPCGRP, lattice, ...
                        species, positions, ...
                        "coords_are_cartesian", true);
                catch
                end
            end
            if isempty(structure)
                structure = kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, species, positions, ...
                    coords_are_cartesian = true, ...
                    to_unit_cell = true);
            end
            obj = kssolv.analysis.matgenlab.io.lmto.LMTOCtrl( ...
                structure, header, version);
        end
    end
end

function values = composeNumber(input, decimals)
input = round(double(input), decimals);
values = strings(size(input));
for index = 1:numel(input)
    values(index) = sprintf("%.15g", input(index));
end
end
