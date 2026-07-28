classdef ACstrExtractor < ...
        kssolv.analysis.matgenlab.io.pwmat.ACExtractorBase
    %ACSTREXTRACTOR Extract AtomConfig and MOVEMENT data from text.

    properties (SetAccess = private)
        atom_config_str (1,1) string
        strs_lst (:,1) string
        num_atoms (1,1) double
    end

    methods
        function obj = ACstrExtractor(atomConfigString)
            obj.atom_config_str = string(atomConfigString);
            obj.strs_lst = splitlines(obj.atom_config_str);
            obj.num_atoms = obj.get_n_atoms();
        end

        function value = get_n_atoms(obj)
            fields = regexp(strtrim(char(obj.strs_lst(1))), ...
                '\s+', 'split');
            value = str2double(fields{1});
            if isnan(value)
                error("KSSOLV:Matgenlab:PWmat:AtomCount", ...
                    "The first AtomConfig field is not an atom count.");
            end
        end

        function value = get_lattice(obj)
            start = obj.section("LATTICE");
            matrix = zeros(3);
            for row = 1:3
                fields = regexp(strtrim(char(obj.strs_lst( ...
                    start + row))), '\s+', 'split');
                if numel(fields) < 3
                    error("KSSOLV:Matgenlab:PWmat:Lattice", ...
                        "A lattice row contains fewer than three values.");
                end
                matrix(row, :) = cellfun(@str2double, fields(1:3));
            end
            if any(isnan(matrix), "all")
                error("KSSOLV:Matgenlab:PWmat:Lattice", ...
                    "The lattice contains a nonnumeric value.");
            end
            value = reshape(matrix.', 1, []);
        end

        function value = get_types(obj)
            rows = obj.atomRows();
            value = zeros(1, obj.num_atoms);
            for index = 1:obj.num_atoms
                fields = regexp(strtrim(char(rows(index))), '\s+', ...
                    'split');
                value(index) = str2double(fields{1});
            end
            if any(isnan(value))
                error("KSSOLV:Matgenlab:PWmat:AtomicNumber", ...
                    "A POSITION atomic number is not numeric.");
            end
        end

        function value = get_coords(obj)
            rows = obj.atomRows();
            coordinates = zeros(obj.num_atoms, 3);
            for index = 1:obj.num_atoms
                fields = regexp(strtrim(char(rows(index))), '\s+', ...
                    'split');
                if numel(fields) < 4
                    error("KSSOLV:Matgenlab:PWmat:Position", ...
                        "A POSITION row contains fewer than four values.");
                end
                coordinates(index, :) = ...
                    cellfun(@str2double, fields(2:4));
            end
            if any(isnan(coordinates), "all")
                error("KSSOLV:Matgenlab:PWmat:Position", ...
                    "A POSITION coordinate is not numeric.");
            end
            value = reshape(coordinates.', 1, []);
        end

        function value = get_magmoms(obj)
            locations = ...
                kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                locate_all_lines(obj.strs_lst, "MAGNETIC");
            if isempty(locations)
                value = zeros(1, obj.num_atoms);
                return
            end
            start = locations(1) + 1;
            value = zeros(1, obj.num_atoms);
            for index = 1:obj.num_atoms
                fields = regexp(strtrim(char(obj.strs_lst( ...
                    start + index))), '\s+', 'split');
                value(index) = str2double(fields{end});
            end
            if any(isnan(value))
                error("KSSOLV:Matgenlab:PWmat:Magmom", ...
                    "A MAGNETIC moment is not numeric.");
            end
        end

        function value = get_e_tot(obj)
            segments = split(obj.strs_lst(1), ",");
            locations = ...
                kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                locate_all_lines(segments, "EK");
            if isempty(locations)
                error("KSSOLV:Matgenlab:PWmat:Energy", ...
                    "The MOVEMENT header does not contain Ek.");
            end
            segment = segments(locations(1) + 1);
            match = regexp(char(segment), ...
                '=\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[Ee][+-]?\d+)?)', ...
                'tokens', 'once');
            if isempty(match)
                error("KSSOLV:Matgenlab:PWmat:Energy", ...
                    "The total energy cannot be parsed.");
            end
            value = str2double(match{1});
        end

        function value = get_atom_energies(obj)
            locations = ...
                kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                locate_all_lines(obj.strs_lst, "ATOMIC-ENERGY, ");
            if isempty(locations)
                value = [];
                return
            end
            start = locations(1) + 1;
            value = zeros(1, obj.num_atoms);
            for index = 1:obj.num_atoms
                fields = regexp(strtrim(char(obj.strs_lst( ...
                    start + index))), '\s+', 'split');
                value(index) = str2double(fields{2});
            end
            if any(isnan(value))
                error("KSSOLV:Matgenlab:PWmat:AtomicEnergy", ...
                    "An atomic energy is not numeric.");
            end
        end

        function value = get_atom_forces(obj)
            locations = ...
                kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                locate_all_lines(obj.strs_lst, "FORCE", "AVERAGE");
            if isempty(locations)
                error("KSSOLV:Matgenlab:PWmat:Force", ...
                    "No non-average Force section is present.");
            end
            start = locations(1) + 1;
            forces = zeros(obj.num_atoms, 3);
            for index = 1:obj.num_atoms
                fields = regexp(strtrim(char(obj.strs_lst( ...
                    start + index))), '\s+', 'split');
                forces(index, :) = cellfun(@str2double, fields(2:4));
            end
            if any(isnan(forces), "all")
                error("KSSOLV:Matgenlab:PWmat:Force", ...
                    "An atomic force is not numeric.");
            end
            value = -reshape(forces.', 1, []);
        end

        function value = get_virial(obj)
            start = obj.section("LATTICE");
            matrix = zeros(3);
            for row = 1:3
                fields = regexp(strtrim(char(obj.strs_lst( ...
                    start + row))), '\s+', 'split');
                if ~any(contains(upper(string(fields)), "STRESS"))
                    value = [];
                    return
                end
                matrix(row, :) = cellfun(@str2double, fields(end-2:end));
            end
            if any(isnan(matrix), "all")
                error("KSSOLV:Matgenlab:PWmat:Virial", ...
                    "A virial component is not numeric.");
            end
            value = reshape(matrix.', 1, []);
        end
    end

    methods (Access = private)
        function index = section(obj, content)
            locations = ...
                kssolv.analysis.matgenlab.io.pwmat.ListLocator. ...
                locate_all_lines(obj.strs_lst, content);
            if isempty(locations)
                error("KSSOLV:Matgenlab:PWmat:MissingSection", ...
                    "The text does not contain a %s section.", content);
            end
            index = locations(1) + 1;
        end

        function rows = atomRows(obj)
            start = obj.section("POSITION");
            last = start + obj.num_atoms;
            if last > numel(obj.strs_lst)
                error("KSSOLV:Matgenlab:PWmat:Position", ...
                    "POSITION contains fewer rows than the atom count.");
            end
            rows = obj.strs_lst(start + 1:last);
        end
    end
end
