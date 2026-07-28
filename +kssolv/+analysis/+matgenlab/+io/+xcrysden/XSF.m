classdef XSF
    %XSF XCrySDen static XSF structure, scalar-grid, and band-grid adapter.

    properties
        structure = []
        forces double = []
        kind (1,1) string = ""
        ndim = []
        conventional_lattice double = []
        grids
        bands
        comment (1,1) string = ""
        fermi_energy = []
    end

    properties (Dependent, SetAccess = private)
        lattice
    end

    methods
        function obj = XSF(structure, options)
            arguments
                structure = []
                options.forces double = []
                options.kind (1,1) string = ""
                options.ndim = []
                options.conventional_lattice double = []
                options.grids = []
                options.bands = []
                options.comment (1,1) string = ""
                options.fermi_energy = []
            end
            obj.structure = structure;
            obj.forces = options.forces;
            obj.kind = options.kind;
            obj.ndim = options.ndim;
            obj.conventional_lattice = options.conventional_lattice;
            obj.grids = normalizeMap(options.grids);
            obj.bands = normalizeMap(options.bands);
            obj.comment = options.comment;
            obj.fermi_energy = options.fermi_energy;
        end

        function value = get.lattice(obj)
            if isa(obj.structure, ...
                    "kssolv.analysis.matgenlab.core.Structure")
                value = obj.structure.lattice;
            else
                value = [];
            end
        end

        function text = to_str(obj, atom_symbol)
            if nargin < 2, atom_symbol = true; end
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:XSF:MissingStructure", ...
                    "Cannot write XSF without a structure");
            end
            lines = strings(0, 1);
            lines = appendComments(lines, obj.comment);
            coordinates = obj.structure.cart_coords;
            nSites = obj.structure.num_sites;
            isMolecule = isa(obj.structure, ...
                "kssolv.analysis.matgenlab.core.Molecule");
            if isMolecule
                lines(end + 1:end + 2) = ["MOLECULE"; "ATOMS"];
            else
                kindValue = upper(obj.kind);
                if strlength(kindValue) == 0, kindValue = "CRYSTAL"; end
                if ~any(kindValue == ["POLYMER", "SLAB", "CRYSTAL"])
                    error("KSSOLV:Matgenlab:XSF:Kind", ...
                        "Unsupported XSF structure kind for periodic output: %s", ...
                        obj.kind);
                end
                lines(end + 1:end + 3) = [kindValue; ...
                    "# Primitive lattice vectors in Angstrom"; "PRIMVEC"];
                matrix = obj.structure.lattice.matrix;
                for row = 1:3
                    lines(end + 1) = sprintf( ...
                        " %.14f %.14f %.14f", matrix(row, :)); %#ok<AGROW>
                end
                lines(end + 1:end + 3) = [ ...
                    "# Cartesian coordinates in Angstrom."; ...
                    "PRIMCOORD"; sprintf(" %d 1", nSites)];
            end

            forceValues = obj.forces;
            if isempty(forceValues)
                hasVect = cellfun(@(site) ...
                    isfield(site.site_properties, "vect"), ...
                    obj.structure.sites);
                if any(hasVect) && ~all(hasVect)
                    error("KSSOLV:Matgenlab:XSF:PartialVect", ...
                        "site property 'vect' must be present on every site or none");
                elseif all(hasVect) && ~isempty(hasVect)
                    forceValues = zeros(nSites, 3);
                    for index = 1:nSites
                        forceValues(index, :) = ...
                            obj.structure.sites{index}.site_properties.vect;
                    end
                end
            end
            if ~isempty(forceValues) && ~isequal(size(forceValues), [nSites, 3])
                error("KSSOLV:Matgenlab:XSF:ForceShape", ...
                    "Forces must have shape (n_sites, 3)");
            end
            for index = 1:nSites
                site = obj.structure.sites{index};
                if atom_symbol
                    species = site.specie.symbol;
                else
                    species = string(site.specie.Z);
                end
                row = sprintf("%s %20.14f %20.14f %20.14f", ...
                    species, coordinates(index, :));
                if ~isempty(forceValues)
                    row = row + sprintf(" %20.14f %20.14f %20.14f", ...
                        forceValues(index, :));
                end
                lines(end + 1) = row; %#ok<AGROW>
            end

            if ~isempty(obj.conventional_lattice)
                if ~isequal(size(obj.conventional_lattice), [3, 3])
                    error("KSSOLV:Matgenlab:XSF:ConventionalLattice", ...
                        "conventional_lattice must have shape (3, 3)");
                end
                lines(end + 1:end + 2) = [ ...
                    "# Conventional lattice vectors in Angstrom"; "CONVVEC"];
                for row = 1:3
                    lines(end + 1) = formatRow( ...
                        obj.conventional_lattice(row, :)); %#ok<AGROW>
                end
            end

            gridKeys = obj.grids.keys();
            for index = 1:numel(gridKeys)
                lines = writeGrid(lines, string(gridKeys{index}), ...
                    obj.grids(gridKeys{index}));
            end
            if ~isempty(obj.bands.keys()) && isempty(obj.fermi_energy)
                error("KSSOLV:Matgenlab:XSF:MissingFermi", ...
                    "Cannot write BANDGRID blocks without a Fermi energy");
            end
            if ~isempty(obj.fermi_energy)
                lines(end + 1:end + 3) = ["BEGIN_INFO"; ...
                    sprintf("  Fermi Energy: %.14f", obj.fermi_energy); ...
                    "END_INFO"];
            end
            bandKeys = obj.bands.keys();
            for index = 1:numel(bandKeys)
                lines = writeBand(lines, string(bandKeys{index}), ...
                    obj.bands(bandKeys{index}));
            end
            text = join(lines, newline);
        end

        function properties = structure_properties(obj)
            properties = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            gridKeys = obj.grids.keys();
            for blockIndex = 1:numel(gridKeys)
                block = gridKeys{blockIndex};
                grid = obj.grids(block);
                labels = grid.labels;
                if isempty(labels)
                    labels = "UNKGRID" + string(0:size(grid.data, 1) - 1);
                end
                for index = 1:numel(labels)
                    label = stripPrefix(labels(index));
                    key = "grids/" + string(block) + "/" + label;
                    dimensions = [1, size(grid.data, 2), ...
                        size(grid.data, 3), size(grid.data, 4)];
                    if grid.ndim == 2, dimensions = dimensions(1:3); end
                    data = reshape(grid.data(index, :, :, :), dimensions);
                    properties(char(key)) = ...
                        kssolv.analysis.matgenlab.io.xcrysden.XSFGrid( ...
                        data, grid.lattice, grid.origin, ...
                        comment = grid.comment, labels = labels(index));
                end
            end
            bandKeys = obj.bands.keys();
            for blockIndex = 1:numel(bandKeys)
                block = bandKeys{blockIndex};
                band = obj.bands(block);
                labels = band.labels;
                if isempty(labels)
                    labels = "UNKBAND" + string(0:size(band.data, 1) - 1);
                end
                for index = 1:numel(labels)
                    label = stripPrefix(labels(index));
                    key = "bands/" + string(block) + "/" + label;
                    data = reshape(band.data(index, :, :, :), ...
                        [1, size(band.data, 2), size(band.data, 3), ...
                        size(band.data, 4)]);
                    properties(char(key)) = ...
                        kssolv.analysis.matgenlab.io.xcrysden.XSFBand( ...
                        data, band.lattice, band.origin, ...
                        comment = band.comment, labels = labels(index));
                end
            end
            if ~isempty(obj.fermi_energy)
                properties("bands/fermi_energy") = obj.fermi_energy;
            end
        end

        function write_file(obj, filename, atom_symbol)
            if nargin < 3, atom_symbol = true; end
            kssolv.analysis.matgenlab.io.xcrysden.XSFTransport. ...
                write_text(filename, obj.to_str(atom_symbol));
        end
    end

    methods (Static)
        function obj = from_file(filename)
            text = kssolv.analysis.matgenlab.io.xcrysden.XSFTransport. ...
                read_text(filename);
            obj = kssolv.analysis.matgenlab.io.xcrysden.XSF.from_str(text);
        end

        function obj = from_str(input_string)
            obj = parseText(string(input_string));
        end

        function obj = parse_file(stream)
            text = kssolv.analysis.matgenlab.io.xcrysden.XSFTransport. ...
                read_stream(stream);
            obj = parseText(text);
        end
    end
end

function map = normalizeMap(value)
if isempty(value)
    map = containers.Map("KeyType", "char", "ValueType", "any");
elseif isa(value, "containers.Map")
    map = value;
elseif isstruct(value)
    names = fieldnames(value);
    map = containers.Map("KeyType", "char", "ValueType", "any");
    for index = 1:numel(names), map(names{index}) = value.(names{index}); end
else
    error("KSSOLV:Matgenlab:XSF:Mapping", ...
        "grids and bands must be containers.Map or struct values.");
end
end

function lines = appendComments(lines, comment)
parts = splitlines(string(comment));
for index = 1:numel(parts)
    line = parts(index);
    if ismissing(line) || strlength(line) == 0, continue; end
    if ~startsWith(line, "#"), line = "# " + line; end
    lines(end + 1) = line; %#ok<AGROW>
end
end

function text = formatRow(values)
parts = compose("%.14f", reshape(double(values), 1, []));
text = join(parts, " ");
end

function lines = appendFlat(lines, values)
values = reshape(values, 1, []);
for start = 1:6:numel(values)
    lines(end + 1) = join(compose("%.14f", ...
        values(start:min(start + 5, end))), " "); %#ok<AGROW>
end
end

function label = stripPrefix(label)
parts = split(string(label), "/", 2);
label = parts(end);
end

function lines = writeGrid(lines, blockName, grid)
data = grid.data;
ndim = grid.ndim;
if ~any(ndim == [2, 3]) || ~any(ndims(data) == [3, 4])
    error("KSSOLV:Matgenlab:XSF:GridShape", ...
        "XSFGrid data must have shape (n, nx, ny) or (n, nx, ny, nz)");
end
if ~any(isequal(size(grid.lattice), [2, 3]) | ...
        isequal(size(grid.lattice), [3, 3]))
    error("KSSOLV:Matgenlab:XSF:GridLattice", ...
        "XSFGrid lattice must have shape (2, 3) or (3, 3)");
end
if numel(grid.origin) ~= 3
    error("KSSOLV:Matgenlab:XSF:GridOrigin", ...
        "XSFGrid origin must have shape (3,)");
end
labels = grid.labels;
if isempty(labels), labels = "UNKGRID" + string(0:size(data, 1) - 1); end
if numel(labels) ~= size(data, 1)
    error("KSSOLV:Matgenlab:XSF:GridLabels", ...
        "XSFGrid labels must be empty or match the number of grids");
end
lines(end + 1:end + 2) = [ ...
    "BEGIN_BLOCK_DATAGRID_" + ndim + "D"; blockName];
lines = appendComments(lines, grid.comment);
shape = size(data);
shape = shape(2:ndim + 1);
for index = 1:numel(labels)
    label = stripPrefix(labels(index));
    if strlength(label) == 0, label = "UNKGRID" + (index - 1); end
    lines(end + 1) = "BEGIN_DATAGRID_" + ndim + "D_" + label; %#ok<AGROW>
    lines(end + 1) = join(string(shape), " "); %#ok<AGROW>
    lines(end + 1) = formatRow(grid.origin); %#ok<AGROW>
    for row = 1:size(grid.lattice, 1)
        lines(end + 1) = formatRow(grid.lattice(row, :)); %#ok<AGROW>
    end
    values = reshape(data(index, :, :, :), shape);
    lines = appendFlat(lines, values(:).');
    lines(end + 1) = "END_DATAGRID_" + ndim + "D"; %#ok<AGROW>
end
lines(end + 1) = "END_BLOCK_DATAGRID_" + ndim + "D";
end

function lines = writeBand(lines, blockName, band)
data = band.data;
if ndims(data) ~= 4
    error("KSSOLV:Matgenlab:XSF:BandShape", ...
        "XSFBand data must have shape (n_bands, nx, ny, nz)");
end
if ~isequal(size(band.lattice), [3, 3])
    error("KSSOLV:Matgenlab:XSF:BandLattice", ...
        "XSFBand lattice must have shape (3, 3)");
end
if numel(band.origin) ~= 3
    error("KSSOLV:Matgenlab:XSF:BandOrigin", ...
        "XSFBand origin must have shape (3,)");
end
labels = band.labels;
if isempty(labels), labels = "UNKBAND" + string(0:size(data, 1) - 1); end
lines(end + 1:end + 4) = ["BEGIN_BLOCK_BANDGRID_3D"; blockName; ...
    "BEGIN_BANDGRID_3D_" + blockName; string(size(data, 1))];
shape = [size(data, 2), size(data, 3), size(data, 4)];
lines(end + 1) = join(string(shape), " ");
lines(end + 1) = formatRow(band.origin);
for row = 1:3
    lines(end + 1) = formatRow(band.lattice(row, :)); %#ok<AGROW>
end
for index = 1:numel(labels)
    label = labels(index);
    if strlength(label) == 0, label = "UNKBAND" + (index - 1); end
    lines(end + 1) = "BAND: " + label; %#ok<AGROW>
    values = reshape(data(index, :, :, :), shape);
    values = permute(values, [3, 2, 1]);
    lines = appendFlat(lines, values(:).');
end
lines(end + 1:end + 2) = ["END_BANDGRID_3D"; ...
    "END_BLOCK_BANDGRID_3D"];
end

function xsf = parseText(text)
lines = splitlines(replace(string(text), compose("\r\n"), newline));
xsf = kssolv.analysis.matgenlab.io.xcrysden.XSF();
comments = strings(0, 1);
index = 1;
currentLattice = [];
iframe = [];
blockName = "";
blockDim = [];
blockType = "";
blockLabels = strings(1, 0);
blockData = {};
blockOrigin = [];
blockLattice = [];
while index <= numel(lines)
    line = strtrim(lines(index));
    index = index + 1;
    if strlength(line) == 0, continue; end
    if startsWith(line, "#")
        comments(end + 1) = line; %#ok<AGROW>
        continue
    end
    tokens = split(line);
    keyword = upper(tokens(1));
    if keyword == "ANIMSTEPS"
        error("KSSOLV:Matgenlab:XSF:Animated", ...
            "ANIMSTEPS keyword is not allowed in static XSF files; use AnimatedXSF for AXSF files");
    elseif any(keyword == ["MOLECULE", "POLYMER", "SLAB", "CRYSTAL"])
        xsf.kind = lower(keyword);
        xsf.ndim = find(["MOLECULE", "POLYMER", "SLAB", "CRYSTAL"] == keyword) - 1;
    elseif keyword == "PRIMVEC" || keyword == "CONVVEC"
        frame = [];
        if numel(tokens) > 1, frame = str2double(tokens(2)); end
        if ~isempty(iframe) && ~isempty(frame) && iframe ~= frame, break; end
        if isempty(iframe) && ~isempty(frame), iframe = frame; end
        [matrix, index] = readRows(lines, index, 3);
        if keyword == "PRIMVEC", currentLattice = matrix;
        else, xsf.conventional_lattice = matrix;
        end
    elseif keyword == "PRIMCOORD"
        frame = [];
        if numel(tokens) > 1, frame = str2double(tokens(2)); end
        if ~isempty(iframe) && ~isempty(frame) && iframe ~= frame, break; end
        if isempty(iframe) && ~isempty(frame), iframe = frame; end
        if isempty(currentLattice)
            error("KSSOLV:Matgenlab:XSF:PrimcoordBeforePrimvec", ...
                "PRIMCOORD encountered before PRIMVEC");
        end
        if ~any(xsf.kind == ["crystal", "slab", "polymer"])
            error("KSSOLV:Matgenlab:XSF:PrimcoordKind", ...
                "PRIMCOORD is only valid in periodic sections");
        end
        if ~isempty(xsf.structure)
            error("KSSOLV:Matgenlab:XSF:MultipleStructures", ...
                "XSF only supports a single structure; use AnimatedXSF for multiple frames");
        end
        header = sscanf(char(strtrim(lines(index))), "%d").';
        index = index + 1;
        if numel(header) ~= 2 || header(2) ~= 1
            error("KSSOLV:Matgenlab:XSF:PrimcoordHeader", ...
                "PRIMCOORD header second value must be 1");
        end
        [species, coords, forces, index] = ...
            readAtoms(lines, index, header(1), true);
        xsf.structure = kssolv.analysis.matgenlab.core.Structure( ...
            currentLattice, species, coords, coords_are_cartesian = true);
        xsf.forces = forces;
    elseif keyword == "ATOMS"
        if xsf.kind ~= "molecule"
            error("KSSOLV:Matgenlab:XSF:AtomsKind", ...
                "ATOMS is only valid in MOLECULE sections");
        end
        [species, coords, forces, index] = readMoleculeAtoms(lines, index);
        xsf.structure = kssolv.analysis.matgenlab.core.Molecule( ...
            species, coords);
        xsf.forces = forces;
    elseif keyword == "CONVCOORD"
        error("KSSOLV:Matgenlab:XSF:Convcoord", ...
            "CONVCOORD section is not allowed in XSF files");
    elseif startsWith(keyword, "BEGIN_BLOCK_DATAGRID_")
        if strlength(blockName) > 0
            error("KSSOLV:Matgenlab:XSF:NestedDatagrid", ...
                "Nested BEGIN_BLOCK_DATAGRID is not allowed");
        end
        blockDim = sscanf(char(erase(keyword, ["BEGIN_BLOCK_DATAGRID_", "D"])), "%d");
        if ~any(blockDim == [2, 3])
            error("KSSOLV:Matgenlab:XSF:DatagridDimension", ...
                "Unsupported DATAGRID dimensionality: %dD", blockDim);
        end
        blockName = strtrim(lines(index)); index = index + 1;
        if xsf.grids.isKey(char(blockName))
            error("KSSOLV:Matgenlab:XSF:DuplicateDatagrid", ...
                "Duplicate DATAGRID block name: %s", blockName);
        end
        blockType = "grid"; blockLabels = strings(1, 0); blockData = {};
        blockOrigin = []; blockLattice = [];
    elseif startsWith(keyword, "END_BLOCK_DATAGRID")
        if strlength(blockName) == 0 || blockType ~= "grid"
            error("KSSOLV:Matgenlab:XSF:DatagridEnd", ...
                "END_BLOCK_DATAGRID encountered without a matching BEGIN_BLOCK_DATAGRID");
        end
        requireBlockGeometry(blockOrigin, blockLattice, "DATAGRID");
        data = concatenateBlocks(blockData, blockDim);
        xsf.grids(char(blockName)) = ...
            kssolv.analysis.matgenlab.io.xcrysden.XSFGrid( ...
            data, blockLattice, blockOrigin, labels = blockLabels);
        blockName = ""; blockType = ""; blockDim = [];
    elseif startsWith(keyword, "BEGIN_DATAGRID_")
        if strlength(blockName) == 0 || blockType ~= "grid"
            error("KSSOLV:Matgenlab:XSF:DatagridBegin", ...
                "BEGIN_DATAGRID encountered without a matching BEGIN_BLOCK_DATAGRID");
        end
        remainder = string(extractAfter( ...
            char(line), strlength("BEGIN_DATAGRID_")));
        [dimensionToken, label] = splitHeader(remainder);
        gridDim = str2double(erase(dimensionToken, "D"));
        if gridDim ~= blockDim
            error("KSSOLV:Matgenlab:XSF:DatagridDimensionMismatch", ...
                "Declared DATAGRID dimension %dD does not match block keyword %dD", ...
                gridDim, blockDim);
        end
        if strlength(label) == 0, label = "UNKGRID" + numel(blockLabels); end
        shape = sscanf(char(strtrim(lines(index))), "%d").'; index = index + 1;
        [origin, index] = readRows(lines, index, 1);
        [latticeValue, index] = readRows(lines, index, blockDim);
        [blockOrigin, blockLattice] = mergeGeometry( ...
            blockOrigin, blockLattice, origin, latticeValue, "DATAGRID");
        count = prod(shape);
        [values, index] = readNumericValues(lines, index, count, "grid");
        blockLabels(end + 1) = "grid/" + label; %#ok<AGROW>
        blockData{end + 1} = reshape(values, shape); %#ok<AGROW>
    elseif startsWith(keyword, "END_DATAGRID")
        requireBlockGeometry(blockOrigin, blockLattice, "DATAGRID");
    elseif startsWith(keyword, "BEGIN_INFO")
        if ~isempty(xsf.fermi_energy)
            error("KSSOLV:Matgenlab:XSF:MultipleInfo", ...
                "Multiple BEGIN_INFO sections are not supported");
        end
        match = regexp(char(lines(index)), ...
            '[-+]?\d+(?:\.\d*)?(?:[eE][-+]?\d+)?', "match", "once");
        index = index + 1;
        if isempty(match)
            error("KSSOLV:Matgenlab:XSF:FermiParse", ...
                "Could not parse Fermi energy from line");
        end
        xsf.fermi_energy = str2double(match);
    elseif startsWith(keyword, "END_INFO")
        if isempty(xsf.fermi_energy)
            error("KSSOLV:Matgenlab:XSF:InfoEnd", ...
                "END_INFO encountered without a preceding BEGIN_INFO");
        end
    elseif startsWith(keyword, "BEGIN_BLOCK_BANDGRID_")
        if strlength(blockName) > 0
            error("KSSOLV:Matgenlab:XSF:NestedBandgrid", ...
                "Nested BEGIN_BLOCK_BANDGRID is not allowed");
        end
        blockDim = sscanf(char(erase(keyword, ["BEGIN_BLOCK_BANDGRID_", "D"])), "%d");
        blockName = strtrim(lines(index)); index = index + 1;
        if blockDim ~= 3
            error("KSSOLV:Matgenlab:XSF:BandgridDimension", ...
                "Unsupported BANDGRID dimensionality: %dD", blockDim);
        end
        if xsf.bands.isKey(char(blockName))
            error("KSSOLV:Matgenlab:XSF:DuplicateBandgrid", ...
                "Duplicate BANDGRID block name: %s", blockName);
        end
        if ~isempty(xsf.bands.keys())
            error("KSSOLV:Matgenlab:XSF:MultipleBandgrid", ...
                "Multiple BANDGRID blocks are not supported");
        end
        blockType = "band"; blockLabels = strings(1, 0); blockData = {};
        blockOrigin = []; blockLattice = [];
    elseif startsWith(keyword, "END_BLOCK_BANDGRID")
        if strlength(blockName) == 0 || blockType ~= "band"
            error("KSSOLV:Matgenlab:XSF:BandgridEnd", ...
                "END_BLOCK_BANDGRID encountered without a matching BEGIN_BLOCK_BANDGRID");
        end
        requireBlockGeometry(blockOrigin, blockLattice, "BANDGRID");
        if isempty(xsf.fermi_energy)
            error("KSSOLV:Matgenlab:XSF:BandgridFermi", ...
                "BANDGRID block is missing required Fermi energy from BEGIN_INFO section");
        end
        xsf.bands(char(blockName)) = ...
            kssolv.analysis.matgenlab.io.xcrysden.XSFBand( ...
            concatenateBlocks(blockData, 3), blockLattice, ...
            blockOrigin, labels = blockLabels);
        blockName = ""; blockType = ""; blockDim = [];
    elseif startsWith(keyword, "BEGIN_BANDGRID_")
        if strlength(blockName) == 0 || blockType ~= "band"
            error("KSSOLV:Matgenlab:XSF:BandgridBegin", ...
                "BEGIN_BANDGRID encountered without a matching BEGIN_BLOCK_BANDGRID");
        end
        remainder = string(extractAfter( ...
            char(line), strlength("BEGIN_BANDGRID_")));
        [dimensionToken, ~] = splitHeader(remainder);
        gridDim = str2double(erase(dimensionToken, "D"));
        if gridDim ~= 3
            error("KSSOLV:Matgenlab:XSF:BandgridDimensionMismatch", ...
                "Declared BANDGRID dimension %dD does not match expected 3D for band grids", ...
                gridDim);
        end
        nBands = str2double(strtrim(lines(index))); index = index + 1;
        shape = sscanf(char(strtrim(lines(index))), "%d").'; index = index + 1;
        [origin, index] = readRows(lines, index, 1);
        [latticeValue, index] = readRows(lines, index, 3);
        [blockOrigin, blockLattice] = mergeGeometry( ...
            blockOrigin, blockLattice, origin, latticeValue, "BANDGRID");
        for bandIndex = 1:nBands
            if index > numel(lines) || ~startsWith(strtrim(lines(index)), "BAND:")
                error("KSSOLV:Matgenlab:XSF:BandCount", ...
                    "Expected %d bands but parsed %d", nBands, bandIndex - 1);
            end
            label = strtrim(extractAfter(strtrim(lines(index)), "BAND:"));
            index = index + 1;
            if strlength(label) == 0, label = "UNK" + (bandIndex - 1); end
            [values, index] = readNumericValues( ...
                lines, index, prod(shape), "band energy");
            data = permute(reshape(values, fliplr(shape)), [3, 2, 1]);
            blockLabels(end + 1) = label; %#ok<AGROW>
            blockData{end + 1} = data; %#ok<AGROW>
        end
    elseif startsWith(keyword, "END_BANDGRID")
        requireBlockGeometry(blockOrigin, blockLattice, "BANDGRID");
        if isempty(xsf.fermi_energy)
            error("KSSOLV:Matgenlab:XSF:BandgridFermi", ...
                "BANDGRID block is missing required Fermi energy from BEGIN_INFO section");
        end
    else
        error("KSSOLV:Matgenlab:XSF:UnsupportedKeyword", ...
            "Unsupported or misplaced XSF keyword: %s", line);
    end
end
xsf.comment = join(comments, newline);
if isempty(xsf.structure) && isempty(xsf.grids.keys()) && isempty(xsf.bands.keys())
    error("KSSOLV:Matgenlab:XSF:NoData", ...
        "No data parsed from XSF file");
end
end

function [matrix, next] = readRows(lines, start, count)
if start + count - 1 > numel(lines)
    error("KSSOLV:Matgenlab:XSF:Truncated", "Unexpected end of XSF file.");
end
matrix = zeros(count, 3);
for row = 1:count
    values = sscanf(char(strtrim(lines(start + row - 1))), "%f").';
    if numel(values) ~= 3
        error("KSSOLV:Matgenlab:XSF:VectorShape", ...
            "XSF vector rows must contain three values.");
    end
    matrix(row, :) = values;
end
next = start + count;
end

function [species, coords, forces, next] = readAtoms(lines, start, count, periodic)
species = cell(1, count); coords = zeros(count, 3); forces = [];
fieldCount = [];
for row = 1:count
    if start + row - 1 > numel(lines)
        error("KSSOLV:Matgenlab:XSF:TruncatedAtoms", ...
            "Unexpected end of XSF atom records.");
    end
    tokens = split(strtrim(lines(start + row - 1)));
    if isempty(fieldCount), fieldCount = numel(tokens); end
    if ~any(numel(tokens) == [4, 7]) || numel(tokens) ~= fieldCount
        if periodic
            error("KSSOLV:Matgenlab:XSF:PrimcoordFields", ...
                "PRIMCOORD atom rows must contain 4 fields or 7 fields with forces");
        else
            error("KSSOLV:Matgenlab:XSF:AtomFields", ...
                "Each ATOMS row must have 3 coordinate fields followed by optional force fields");
        end
    end
    species{row} = parseSpecies(tokens(1));
    coords(row, :) = str2double(tokens(2:4));
    if fieldCount == 7
        if isempty(forces), forces = zeros(count, 3); end
        forces(row, :) = str2double(tokens(5:7)); %#ok<AGROW>
    end
end
next = start + count;
end

function [species, coords, forces, next] = readMoleculeAtoms(lines, start)
rows = strings(0, 1); index = start;
while index <= numel(lines)
    line = strtrim(lines(index));
    if strlength(line) == 0, index = index + 1; break; end
    token = upper(split(line)); token = token(1);
    if isKeyword(token), break; end
    rows(end + 1) = line; %#ok<AGROW>
    index = index + 1;
end
[species, coords, forces, ~] = readAtoms(rows, 1, numel(rows), false);
next = index;
end

function tf = isKeyword(token)
exact = ["ANIMSTEPS", "MOLECULE", "POLYMER", "SLAB", "CRYSTAL", ...
    "PRIMVEC", "CONVVEC", "PRIMCOORD", "ATOMS", "CONVCOORD", ...
    "END_BLOCK_DATAGRID", "END_DATAGRID", "BEGIN_INFO", "END_INFO", ...
    "END_BLOCK_BANDGRID", "END_BANDGRID"];
prefixes = ["BEGIN_BLOCK_DATAGRID_", "BEGIN_DATAGRID_", ...
    "BEGIN_BLOCK_BANDGRID_", "BEGIN_BANDGRID_"];
tf = any(token == exact) || any(startsWith(token, prefixes));
end

function species = parseSpecies(token)
number = str2double(token);
if isnan(number)
    species = char(token);
else
    species = char(kssolv.analysis.matgenlab.core.Element.from_Z(number).symbol);
end
end

function [dimension, label] = splitHeader(header)
text = char(header);
separator = find(text == '_', 1);
if isempty(separator)
    dimension = string(text);
    label = "";
else
    dimension = string(text(1:separator - 1));
    label = string(text(separator + 1:end));
end
end

function [values, next] = readNumericValues(lines, start, count, description)
values = zeros(1, 0); index = start;
while index <= numel(lines) && numel(values) < count
    line = strtrim(lines(index));
    token = upper(split(line)); token = token(1);
    if isKeyword(token) || startsWith(token, "BAND:"), break; end
    parsed = sscanf(char(line), "%f").';
    values = [values, parsed]; %#ok<AGROW>
    index = index + 1;
end
if numel(values) ~= count
    error("KSSOLV:Matgenlab:XSF:ValueCount", ...
        "Expected %d %s values but parsed %d", count, description, numel(values));
end
next = index;
end

function [storedOrigin, storedLattice] = mergeGeometry( ...
        storedOrigin, storedLattice, origin, lattice, kind)
if isempty(storedOrigin), storedOrigin = origin;
elseif any(abs(storedOrigin - origin) > 1e-8, "all")
    error("KSSOLV:Matgenlab:XSF:InconsistentOrigin", ...
        "Inconsistent %s origin within the same block", kind);
end
if isempty(storedLattice), storedLattice = lattice;
elseif any(abs(storedLattice - lattice) > 1e-8, "all")
    error("KSSOLV:Matgenlab:XSF:InconsistentLattice", ...
        "Inconsistent %s lattice within the same block", kind);
end
end

function requireBlockGeometry(origin, lattice, kind)
if isempty(origin) || isempty(lattice)
    error("KSSOLV:Matgenlab:XSF:BlockGeometry", ...
        "%s block is missing required origin or lattice information", kind);
end
end

function data = concatenateBlocks(blocks, ndim)
if isempty(blocks), data = []; return; end
shape = size(blocks{1});
if ndim == 2, shape = [shape(1), shape(2)];
else, shape = [shape(1), shape(2), shape(3)];
end
data = zeros([numel(blocks), shape]);
for index = 1:numel(blocks)
    if ndim == 2, data(index, :, :) = blocks{index};
    else, data(index, :, :, :) = blocks{index};
    end
end
end
