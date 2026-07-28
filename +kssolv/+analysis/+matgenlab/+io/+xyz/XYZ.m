classdef XYZ
    %XYZ Import and export one or more molecular XYZ frames.

    properties (SetAccess = private)
        all_molecules cell = cell(1, 0)
        precision (1,1) double = 6
    end

    properties (Dependent, SetAccess = private)
        molecule
    end

    methods
        function obj = XYZ(molecule, coord_precision)
            if nargin < 2, coord_precision = 6; end
            if ~isscalar(coord_precision) || coord_precision < 0 || ...
                    coord_precision ~= fix(coord_precision)
                error("KSSOLV:Matgenlab:XYZ:Precision", ...
                    "Coordinate precision must be a nonnegative integer.");
            end
            if iscell(molecule)
                obj.all_molecules = reshape(molecule, 1, []);
            else
                obj.all_molecules = {molecule};
            end
            obj.precision = coord_precision;
        end

        function value = get.molecule(obj)
            if isempty(obj.all_molecules)
                error("KSSOLV:Matgenlab:XYZ:EmptyFrames", ...
                    "XYZ contains no molecular frames.");
            end
            value = obj.all_molecules{end};
        end

        function value = frame_str(obj, molecule)
            if ~molecule.is_ordered
                error("KSSOLV:Matgenlab:XYZ:Disordered", ...
                    "XYZ only supports ordered sites.");
            end
            lines = strings(molecule.num_sites + 2, 1);
            lines(1) = string(molecule.num_sites);
            lines(2) = molecule.formula;
            format = sprintf("%%s %%.%df %%.%df %%.%df", ...
                obj.precision, obj.precision, obj.precision);
            for index = 1:molecule.num_sites
                site = molecule.get_site(index);
                lines(index + 2) = sprintf(format, ...
                    string(site.specie), site.x, site.y, site.z);
            end
            value = strjoin(lines, newline);
        end

        function value = char(obj)
            frames = cellfun(@(molecule) obj.frame_str(molecule), ...
                obj.all_molecules, "UniformOutput", false);
            value = char(strjoin(string(frames), newline));
        end

        function value = string(obj), value = string(char(obj)); end
        function value = get_str(obj), value = string(obj); end

        function write_file(obj, filename)
            fid = fopen(filename, "w", "n", "UTF-8");
            if fid < 0
                error("KSSOLV:Matgenlab:XYZ:Open", ...
                    "Cannot open '%s' for writing.", filename);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, char(obj), "char");
            clear cleanup
        end

        function value = as_dataframe(obj)
            molecule = obj.molecule;
            atoms = strings(molecule.num_sites, 1);
            for index = 1:molecule.num_sites
                atoms(index) = molecule.get_site(index).species_string;
            end
            coordinates = molecule.cart_coords;
            value = table(atoms, coordinates(:, 1), coordinates(:, 2), ...
                coordinates(:, 3), VariableNames = ["atom", "x", "y", "z"]);
        end
    end

    methods (Static)
        function obj = from_str(contents)
            lines = splitlines(string(contents));
            frames = cell(1, 0);
            lineIndex = 1;
            while lineIndex <= numel(lines)
                if strtrim(lines(lineIndex)) == ""
                    lineIndex = lineIndex + 1;
                    continue
                end
                number = str2double(strtrim(lines(lineIndex)));
                if isnan(number) || number < 0 || number ~= fix(number)
                    error("KSSOLV:Matgenlab:XYZ:AtomCount", ...
                        "Invalid atom count on line %d.", lineIndex);
                end
                if lineIndex + number + 1 > numel(lines)
                    error("KSSOLV:Matgenlab:XYZ:Truncated", ...
                        "XYZ frame beginning on line %d is truncated.", lineIndex);
                end
                species = strings(number, 1);
                coordinates = zeros(number, 3);
                for atomIndex = 1:number
                    atomLine = strtrim(lines(lineIndex + 1 + atomIndex));
                    tokens = regexp(atomLine, ...
                        "^(\w+)\s+([0-9+\-.*^eEdD]+)\s+" + ...
                        "([0-9+\-.*^eEdD]+)\s+([0-9+\-.*^eEdD]+)", ...
                        "tokens", "once");
                    if isempty(tokens)
                        error("KSSOLV:Matgenlab:XYZ:Coordinate", ...
                            "Invalid coordinate line %d.", ...
                            lineIndex + 1 + atomIndex);
                    end
                    species(atomIndex) = string(tokens{1});
                    for axis = 1:3
                        token = lower(string(tokens{axis + 1}));
                        token = replace(token, ["d", "*^"], ["e", "e"]);
                        coordinates(atomIndex, axis) = str2double(token);
                    end
                end
                frames{end + 1} = ...
                    kssolv.analysis.matgenlab.core.Molecule( ...
                        species, coordinates); %#ok<AGROW>
                lineIndex = lineIndex + number + 2;
            end
            obj = kssolv.analysis.matgenlab.io.xyz.XYZ(frames);
        end

        function obj = from_file(filename)
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:XYZ:MissingFile", ...
                    "XYZ file '%s' does not exist.", filename);
            end
            obj = ...
                kssolv.analysis.matgenlab.io.xyz.XYZ.from_str( ...
                    fileread(filename));
        end
    end
end
