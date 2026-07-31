function text = write_output(system, x, filename)
%WRITE_OUTPUT Write Packmol-compatible PDB, XYZ, or TINKER output.

[coordinates, ~, ~] = ...
    kssolv.analysis.packmol.cartesian_coordinates(system, x);
settings = system.config.settings;
switch settings.filetype
    case "xyz"
        text = formatXyz(system, coordinates);
    case "pdb"
        text = formatPdb(system, coordinates);
    case "tinker"
        text = formatTinker(system, coordinates);
    otherwise
        error("KSSOLV:Packmol:FileType", ...
            "Unsupported output file type '%s'.", settings.filetype);
end
if nargin >= 3 && strlength(string(filename)) > 0
    kssolv.analysis.packmol.write_restarts(system, x);
    filename = string(filename);
    [fileId, message] = fopen(filename, "w");
    if fileId < 0
        error("KSSOLV:Packmol:Output", ...
            "Unable to open output file '%s': %s", filename, message);
    end
    cleanup = onCleanup(@() fclose(fileId));
    fprintf(fileId, "%s", char(text));
    clear cleanup
    if settings.crd && settings.filetype == "pdb"
        crdPath = string(settings.crdfile);
        if ~isAbsolutePath(crdPath)
            crdPath = fullfile(system.config.working_directory, crdPath);
        end
        writeCrd(system, coordinates, crdPath);
    end
end
end

function text = formatXyz(system, coordinates)
lines = strings(system.atom_count + 2, 1);
lines(1) = sprintf("%12d", system.atom_count);
lines(2) = sprintf(" %-64s", " Built with Packmol ");
for i = 1:system.atom_count
    lines(i + 2) = sprintf("  %-3s    %14.6f  %14.6f  %14.6f", ...
        system.symbols(i), coordinates(i, 1), ...
        coordinates(i, 2), coordinates(i, 3));
end
text = join(lines, newline) + newline;
end

function text = formatPdb(system, coordinates)
lines = [ ...
    "HEADER "; ...
    pad("TITLE     Built with Packmol", 73); ...
    "REMARK   Packmol generated pdb file "; ...
    "REMARK   Home-Page: http://m3g.iqm.unicamp.br/packmol"; ...
    "REMARK"];
settings = system.config.settings;
if settings.hexadecimal_indices
    lines = [lines; ...
        "REMARK  Atom and residue indices are in hexadecimal format."; ...
        "REMARK"]; %#ok<AGROW>
end
if settings.using_pbc || settings.add_box_sides
    if settings.using_pbc
        boxLength = settings.pbc_max - settings.pbc_min;
    else
        lines = [lines; ...
            "REMARK  CRYST1 info below is (extrema(coordinates) +/- 1.1*tolerance) because no explicit"; ...
            "REMARK  PBCs were defined. To apply PBCs, use the `pbc` keyword."]; %#ok<AGROW>
        lower = min(coordinates, [], 1) - 1.1 * settings.tolerance;
        upper = max(coordinates, [], 1) + 1.1 * settings.tolerance;
        boxLength = upper - lower;
    end
    lines(end + 1, 1) = sprintf( ... %#ok<AGROW>
        "CRYST1%9.2f%9.2f%9.2f%7.2f%7.2f%7.2f P 1           1", ...
        boxLength, 90, 90, 90);
end
atomSerial = 0;
connectLines = strings(0, 1);
moleculeSerial = 0;
residueCounter = 1;
chainCounter = 0;
oddChain = ' ';
evenChain = ' ';
for instanceIndex = 1:numel(system.instances)
    instance = system.instances(instanceIndex);
    structure = system.structures(instance.structure_index);
    indices = instance.atom_indices;
    if ~instance.fixed
        moleculeSerial = moleculeSerial + 1;
    end
    originalResidues = ones(numel(indices), 1);
    for localAtom = 1:numel(indices)
        if localAtom <= numel(structure.molecule.records) && ...
                strlength(structure.molecule.records(localAtom)) > 0
            record = char(pad(structure.molecule.records(localAtom), 80));
            parsed = str2double(record(23:26));
            if isfinite(parsed)
                originalResidues(localAtom) = parsed;
            end
        end
    end
    firstResidue = originalResidues(1);
    residueCount = max(originalResidues) - firstResidue + 1;
    residueMode = structure.resnumbers;
    if residueMode < 0
        if residueCount == 1
            residueMode = 0;
        else
            residueMode = 1;
        end
    end
    if ~instance.fixed && structure.chain == "#"
        if instance.copy_index == 1 || ...
                mod(instance.copy_index, 9999) == 1
            chainCounter = chainCounter + 1;
            if structure.changechains
                oddChain = chainCharacter(chainCounter);
                chainCounter = chainCounter + 1;
                evenChain = chainCharacter(chainCounter);
            else
                evenChain = chainCharacter(chainCounter);
                oddChain = evenChain;
            end
        end
        if mod(instance.copy_index, 2) == 0
            outputChain = evenChain;
        else
            outputChain = oddChain;
        end
    else
        outputChain = char(0);
    end
    localToGlobal = zeros(1, numel(indices));
    for localAtom = 1:numel(indices)
        if settings.amber_ter_preserve && ...
                structure.molecule.ter_before_atom(localAtom)
            lines(end + 1, 1) = "TER"; %#ok<AGROW>
        end
        atomSerial = atomSerial + 1;
        localToGlobal(localAtom) = atomSerial;
        if localAtom <= numel(structure.molecule.records) && ...
                strlength(structure.molecule.records(localAtom)) > 0
            record = normalizedPdbRecord( ...
                structure.molecule.records(localAtom));
        else
            symbol = char(system.symbols(indices(localAtom)));
            record = sprintf("HETATM%5d %-4s MOL A%4d", ...
                atomSerial, symbol, moleculeSerial);
            record = char(pad(string(record), 80));
        end
        record(7:11) = indexText(atomSerial, 5, ...
            settings.hexadecimal_indices);
        originalResidue = originalResidues(localAtom);
        if instance.fixed
            switch residueMode
                case 0
                    residueSerial = 1;
                case 1
                    residueSerial = originalResidue;
                case 2
                    residueSerial = originalResidue - ...
                        firstResidue + residueCounter;
                case 3
                    residueSerial = moleculeSerial;
                otherwise
                    residueSerial = originalResidue;
            end
        else
            switch residueMode
                case 0
                    residueSerial = instance.copy_index;
                case 1
                    residueSerial = originalResidue;
                case 2
                    residueSerial = originalResidue - ...
                        firstResidue + residueCounter;
                case 3
                    residueSerial = moleculeSerial;
                otherwise
                    residueSerial = instance.copy_index;
            end
        end
        residueSerial = mod(residueSerial, 9999);
        if residueSerial == 0
            residueSerial = 9999;
        end
        record(23:26) = indexText(residueSerial, 4, ...
            settings.hexadecimal_indices);
        coordinateText = char(sprintf("%8.3f%8.3f%8.3f", ...
            coordinates(indices(localAtom), 1), ...
            coordinates(indices(localAtom), 2), ...
            coordinates(indices(localAtom), 3)));
        if numel(coordinateText) ~= 24
            error("KSSOLV:Packmol:PDBCoordinates", ...
                "Coordinate cannot be represented in PDB columns.");
        end
        record(31:54) = coordinateText;
        if structure.chain ~= "#"
            chain = char(structure.chain);
            record(22) = chain(1);
        elseif ~instance.fixed
            record(22) = outputChain;
        end
        lines(end + 1, 1) = string(record); %#ok<AGROW>
    end
    if settings.amber_ter_preserve && ...
            structure.molecule.ter_before_atom(numel(indices) + 1)
        lines(end + 1, 1) = "TER"; %#ok<AGROW>
    end
    residueCounter = residueCounter + residueCount;
    if settings.add_amber_ter
        lines(end + 1, 1) = "TER"; %#ok<AGROW>
    end
    if structure.connect && ~settings.ignore_conect
        for localAtom = 1:numel(indices)
            targets = structure.molecule.connectivity{localAtom};
            if isempty(targets)
                continue
            end
            targets = targets(targets >= 1 & targets <= numel(indices));
            globalTargets = localToGlobal(targets);
            newLines = formatConect( ...
                localToGlobal(localAtom), globalTargets, ...
                settings.hexadecimal_indices);
            connectLines = [connectLines; newLines]; %#ok<AGROW>
        end
    end
end
lines = [lines; connectLines; "END"];
text = join(lines, newline) + newline;
end

function text = formatTinker(system, coordinates)
lines = strings(system.atom_count + 1, 1);
lines(1) = sprintf("%6d  %-64s", ...
    system.atom_count, " Built with Packmol ");
serial = 0;
for instanceIndex = 1:numel(system.instances)
    instance = system.instances(instanceIndex);
    structure = system.structures(instance.structure_index);
    indices = instance.atom_indices;
    base = serial;
    for localAtom = 1:numel(indices)
        serial = serial + 1;
        targets = structure.molecule.connectivity{localAtom};
        targets = base + targets;
        values = [structure.molecule.atom_types(localAtom), targets];
        if numel(values) > 9
            error("KSSOLV:Packmol:TinkerConnectivity", ...
                "TINKER output supports at most eight bonds per atom.");
        end
        integerFields = join(compose("  %7d", values), "");
        lines(serial + 1) = sprintf( ...
            "%7d  %-3s  %10.6f  %10.6f  %10.6f%s", ...
            serial, system.symbols(indices(localAtom)), ...
            coordinates(indices(localAtom), 1), ...
            coordinates(indices(localAtom), 2), ...
            coordinates(indices(localAtom), 3), integerFields);
    end
end
text = join(lines, newline) + newline;
end

function value = indexText(index, width, hexadecimal)
if hexadecimal
    if index > 16^width - 1
        error("KSSOLV:Packmol:PDBIndex", ...
            "Index %d exceeds hexadecimal PDB field width.", index);
    end
    value = upper(dec2hex(index, width));
elseif index <= 10^width - 1
    value = char(sprintf("%*d", width, index));
elseif index <= 16^width - 1
    value = upper(dec2hex(index, width));
else
    error("KSSOLV:Packmol:PDBIndex", ...
        "Atom index %d exceeds PDB field width.", index);
end
end

function lines = formatConect(source, targets, hexadecimal)
lines = strings(0, 1);
current = "CONECT" + string(indexText(source, 5, hexadecimal));
for i = 1:numel(targets)
    current = current + string(indexText(targets(i), 5, hexadecimal));
    finish = i == numel(targets) || mod(i, 5) == 0;
    if ~finish
        finish = targets(i + 1) <= targets(i);
    end
    if finish
        lines(end + 1, 1) = current; %#ok<AGROW>
        current = "CONECT" + ...
            string(indexText(source, 5, hexadecimal));
    end
end
end

function value = chainCharacter(index)
characters = ['A':'Z', '1':'9', '0'];
if index <= numel(characters)
    value = characters(index);
else
    value = '#';
end
end

function writeCrd(system, coordinates, filename)
[fileId, message] = fopen(filename, "w");
if fileId < 0
    error("KSSOLV:Packmol:Output", ...
        "Unable to open CRD output file '%s': %s", filename, message);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, "* TITLE %-64s%s", " Built with Packmol ", newline);
fprintf(fileId, "* Packmol generated CHARMM CRD File%s", newline);
fprintf(fileId, "* Home-Page:%s", newline);
fprintf(fileId, "* http://m3g.iqm.unicamp.br/packmol%s", newline);
fprintf(fileId, "* %s", newline);
fprintf(fileId, "%10d  EXT%s", system.atom_count, newline);

atomSerial = 0;
residueCounter = 1;
moleculeSerial = 0;
for instanceIndex = 1:numel(system.instances)
    instance = system.instances(instanceIndex);
    structure = system.structures(instance.structure_index);
    indices = instance.atom_indices;
    if ~instance.fixed
        moleculeSerial = moleculeSerial + 1;
    end
    records = structure.molecule.records;
    originalResidues = ones(numel(indices), 1);
    for localAtom = 1:numel(indices)
        if localAtom <= numel(records) && strlength(records(localAtom)) > 0
            record = normalizedPdbRecord(records(localAtom));
            parsed = str2double(record(23:26));
            if isfinite(parsed)
                originalResidues(localAtom) = parsed;
            end
        end
    end
    firstResidue = originalResidues(1);
    residueCount = max(originalResidues) - firstResidue + 1;
    residueMode = structure.resnumbers;
    if residueMode < 0
        residueMode = double(residueCount > 1);
    end
    for localAtom = 1:numel(indices)
        atomSerial = atomSerial + 1;
        originalResidue = originalResidues(localAtom);
        switch residueMode
            case 0
                if instance.fixed
                    residueSerial = 1;
                else
                    residueSerial = instance.copy_index;
                end
            case 1
                residueSerial = originalResidue;
            case 2
                residueSerial = originalResidue - firstResidue + residueCounter;
            case 3
                residueSerial = moleculeSerial;
            otherwise
                residueSerial = originalResidue;
        end
        if localAtom <= numel(records) && strlength(records(localAtom)) > 0
            record = normalizedPdbRecord(records(localAtom));
            residueName = strtrim(record(18:21));
            atomName = strtrim(record(13:16));
        else
            residueName = "MOL";
            atomName = system.symbols(indices(localAtom));
        end
        segmentId = residueName;
        if strlength(structure.segid) > 0
            segmentId = structure.segid;
        end
        crdCoordinates = coordinates(indices(localAtom), :);
        if instance.fixed
            % Preserve output.f90's historical fixed-molecule CRD
            % behavior: xcart is not advanced in the fixed branch.
            crdCoordinates = zeros(1, 3);
        end
        fprintf(fileId, ...
            "%10d%10d  %-8s  %-8s%20.10f%20.10f%20.10f  %-8s  %-8s%20.10f%s", ...
            atomSerial, residueSerial, residueName, atomName, ...
            crdCoordinates(1), crdCoordinates(2), crdCoordinates(3), ...
            segmentId, string(residueSerial), 0, newline);
    end
    residueCounter = residueCounter + residueCount;
end
clear cleanup
end

function record = normalizedPdbRecord(value)
record = char(pad(value, 80));
record = record(1:80);
end

function tf = isAbsolutePath(path)
value = char(path);
if ispc
    tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(value, "\\");
else
    tf = startsWith(value, "/");
end
end
