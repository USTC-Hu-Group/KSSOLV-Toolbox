classdef GulpIO
    %GULPIO Generate GULP input and parse GULP output.

    methods (Static)
        function text = keyword_line(varargin)
            text = join(string(varargin), " ") + newline;
        end

        function text = structure_lines(structure, options)
            arguments
                structure
                options.cell_flg (1,1) logical = true
                options.frac_flg (1,1) logical = true
                options.anion_shell_flg (1,1) logical = true
                options.cation_shell_flg (1,1) logical = false
                options.symm_flg (1,1) logical = true
            end
            lines = strings(0, 1);
            if options.cell_flg
                lattice = structure.lattice;
                lengths = lattice.lengths;
                angles = lattice.angles;
                lines(end + 1:end + 2) = ["cell"; sprintf( ...
                    "%f %f %f %f %f %f", lengths, angles)];
            end
            if options.frac_flg
                lines(end + 1) = "frac";
                coordinates = structure.frac_coords;
            else
                lines(end + 1) = "cart";
                coordinates = structure.cart_coords;
            end
            anions = ["O", "S", "F", "Cl", "Br", "N", "P"];
            cations = ["Li", "Na", "K", "Be", "Mg", "Ca", "Al", ...
                "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", ...
                "Cu", "Zn", "Ge", "As", "Y", "Zr", "Nb", "Mo", ...
                "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", ...
                "Sb", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", ...
                "Au", "Hg", "Tl", "Pb", "Bi", "La", "Ce", "Pr", ...
                "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", ...
                "Er", "Tm", "Yb", "Lu"];
            for index = 1:structure.num_sites
                symbol = structure.sites{index}.specie.symbol;
                coordinateText = join(arrayfun(@upstreamFloat, ...
                    coordinates(index, :)), " ");
                lines(end + 1) = symbol + " core " + coordinateText; %#ok<AGROW>
                addShell = (any(symbol == anions) && ...
                    options.anion_shell_flg) || ...
                    (any(symbol == cations) && options.cation_shell_flg);
                if addShell
                    lines(end + 1) = symbol + " shel " + coordinateText; %#ok<AGROW>
                end
            end
            if options.symm_flg
                analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure);
                lines(end + 1:end + 2) = ["space"; ...
                    string(analyzer.get_space_group_number())];
            end
            text = join(lines, newline) + newline;
        end

        function text = specie_potential_lines(structure, potential, options)
            arguments
                structure
                potential
                options.valence_dict = []
                options.bush_file = ""
                options.lewis_file = ""
                options.tersoff_file = ""
            end
            kind = lower(string(potential));
            if kind == "buckingham"
                text = ...
                    kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpIO.buckingham_potential(structure, ...
                    options.valence_dict, options.bush_file, ...
                    options.lewis_file);
            elseif kind == "tersoff"
                text = ...
                    kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpIO.tersoff_potential(structure, ...
                    options.tersoff_file);
            else
                throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpError("Unsupported potential type '" + kind + "'."));
            end
        end

        function text = library_line(file_name)
            fileName = string(file_name);
            if contains(fileName, filesep) && isfile(fileName)
                text = "library " + fileName + newline;
                return
            end
            local = fullfile(pwd, fileName);
            if isfile(local)
                text = "library " + string(local) + newline;
                return
            end
            libraryFolder = string(getenv("GULP_LIB"));
            if strlength(libraryFolder) > 0 && ...
                    isfile(fullfile(libraryFolder, fileName))
                text = "library " + fileName + newline;
                return
            end
            throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                GulpError("GULP library not found"));
        end

        function text = buckingham_input(structure, keywords, options)
            arguments
                structure
                keywords
                options.library = ""
                options.uc (1,1) logical = true
                options.valence_dict = []
                options.bush_file = ""
                options.lewis_file = ""
            end
            keywordCell = cellstr(string(keywords));
            text = ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                GulpIO.keyword_line(keywordCell{:});
            text = text + ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                GulpIO.structure_lines(structure, symm_flg = ~options.uc);
            if strlength(string(options.library)) > 0
                text = text + ...
                    kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpIO.library_line(options.library);
            else
                text = text + ...
                    kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                    GulpIO.buckingham_potential(structure, ...
                    options.valence_dict, options.bush_file, ...
                    options.lewis_file);
            end
        end

        function text = buckingham_potential( ...
                structure, val_dict, bush_file, lewis_file)
            if nargin < 2, val_dict = []; end
            if nargin < 3, bush_file = ""; end
            if nargin < 4, lewis_file = ""; end
            values = normalizeValences(structure, val_dict);
            bpb = ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                BuckinghamPotential("bush", bush_file);
            bpl = ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                BuckinghamPotential("lewis", lewis_file);
            lines = strings(0, 1);
            keys = values.keys();
            for index = 1:numel(keys)
                key = keys{index};
                element = regexprep(key, '[1-9,+,\-]', '');
                valence = values(key);
                useBush = bpb.species_dict.isKey(element) && ...
                    valence == bpb.species_dict(element).oxi;
                if useBush
                    lines = appendPotential(lines, "species ", ...
                        bpb.species_dict(element).inp_str);
                    lines = appendPotential(lines, "buckingham ", ...
                        bpb.pot_dict(element));
                    lines = appendPotential(lines, "spring ", ...
                        bpb.spring_dict(element));
                elseif element ~= "O"
                    libraryKey = element + "_" + fix(valence) + "+";
                    if ~bpl.species_dict.isKey(char(libraryKey))
                        throw(kssolv.analysis.matgenlab.command_line. ...
                            gulp_caller.GulpError( ...
                            "Element " + libraryKey + " not in library"));
                    end
                    lines = appendPotential(lines, "species", ...
                        bpl.species_dict(char(libraryKey)));
                    lines = appendPotential(lines, "buckingham", ...
                        bpl.pot_dict(char(libraryKey)));
                else
                    lines = appendPotential(lines, "species", ...
                        bpl.species_dict("O_core") + ...
                        bpl.species_dict("O_shel"));
                    lines = appendPotential(lines, "buckingham", ...
                        bpl.pot_dict("O"));
                    lines = appendPotential(lines, "spring", ...
                        bpl.spring_dict("O"));
                end
            end
            text = join(lines, newline) + newline;
        end

        function text = tersoff_input( ...
                structure, periodic, uc, varargin)
            if nargin < 2 || isempty(periodic), periodic = false; end
            if nargin < 3 || isempty(uc), uc = true; end
            text = ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                GulpIO.keyword_line(varargin{:});
            text = text + ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                GulpIO.structure_lines(structure, ...
                cell_flg = logical(periodic), ...
                frac_flg = logical(periodic), ...
                anion_shell_flg = false, ...
                cation_shell_flg = false, symm_flg = ~logical(uc));
            text = text + ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                GulpIO.tersoff_potential(structure);
        end

        function text = tersoff_potential(structure, pot_file)
            if nargin < 2, pot_file = ""; end
            values = normalizeValences(structure, []);
            potential = ...
                kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                TersoffPotential(pot_file);
            lines = "species ";
            qerfc = "qerfc";
            keys = values.keys();
            for index = 1:numel(keys)
                key = string(keys{index});
                valence = values(keys{index});
                if key ~= "O" && mod(valence, 1) ~= 0
                    error("KSSOLV:Matgenlab:GULP:MixedValence", ...
                        "Oxide has mixed valence on metal");
                end
                lines(end + 1) = key + " core " + valence; %#ok<AGROW>
                qerfc(end + 1) = key + " " + key + ...
                    " 0.6000 10.0000 "; %#ok<AGROW>
            end
            lines(end + 1:end + 2) = ["# noelectrostatics "; " Morse "];
            for index = 1:numel(keys)
                key = string(keys{index});
                if key == "O", continue; end
                record = char(key + "(" + fix(values(keys{index})) + ")");
                if ~potential.data.isKey(record)
                    throw(kssolv.analysis.matgenlab.command_line. ...
                        gulp_caller.GulpError( ...
                        "Element " + record + " not in Tersoff library"));
                end
                lines(end + 1) = string(potential.data(record)); %#ok<AGROW>
            end
            lines = [lines, qerfc];
            text = join(lines, newline) + newline;
        end

        function energy = get_energy(gout)
            energyFields = strings(1, 0);
            lines = splitlines(string(gout));
            for index = 1:numel(lines)
                line = lines(index);
                if (contains(line, "Total lattice energy") && ...
                        contains(line, "eV")) || ...
                        (contains(line, "Non-primitive unit cell") && ...
                        contains(line, "eV"))
                    energyFields = split(strtrim(line));
                end
            end
            if ~isempty(energyFields)
                energy = str2double(energyFields(5));
                return
            end
            throw(kssolv.analysis.matgenlab.command_line.gulp_caller. ...
                GulpError("Energy not found in Gulp output"));
        end

        function structure = get_relaxed_structure(gout)
            lines = splitlines(string(gout));
            [a, b, c, alpha, beta, gamma] = initialCell(lines);
            marker = find(contains(lines, ...
                "Final fractional coordinates of atoms"), 1);
            if isempty(marker)
                error("KSSOLV:Matgenlab:GULP:NoStructure", ...
                    "No structure found");
            end
            species = cell(1, 0);
            coordinates = zeros(0, 3);
            index = marker + 6;
            while index <= numel(lines) && ...
                    ~startsWith(strtrim(lines(index)), "--")
                fields = split(strtrim(lines(index)));
                if numel(fields) >= 6 && fields(3) == "c"
                    species{end + 1} = char(fields(2)); %#ok<AGROW>
                    coordinates(end + 1, :) = ...
                        str2double(fields(4:6)); %#ok<AGROW>
                end
                index = index + 1;
            end
            if isempty(species)
                error("KSSOLV:Matgenlab:GULP:NoStructure", ...
                    "No structure found");
            end
            final = find(contains(lines, "Final cell parameters"), 1);
            if ~isempty(final)
                values = zeros(1, 6);
                for offset = 1:6
                    fields = split(strtrim(lines(final + 2 + offset)));
                    values(offset) = str2double(fields(2));
                end
                a = values(1); b = values(2); c = values(3);
                alpha = values(4); beta = values(5); gamma = values(6);
            end
            if ~all([a, b, c, alpha, beta, gamma])
                error("KSSOLV:Matgenlab:GULP:MissingLattice", ...
                    "Missing lattice parameters in Gulp output.");
            end
            lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                from_parameters(a, b, c, alpha, beta, gamma);
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, species, coordinates);
        end
    end
end

function values = normalizeValences(structure, input)
if isa(input, "containers.Map")
    values = input; return
elseif isstruct(input) && ~isempty(fieldnames(input))
    names = fieldnames(input);
    values = containers.Map(names, cellfun(@(name) ...
        double(input.(name)), names));
    return
end
symbols = cellfun(@(site) char(site.specie.symbol), ...
    structure.sites, "UniformOutput", false);
valences = zeros(1, structure.num_sites);
decorated = true;
for index = 1:structure.num_sites
    specie = structure.sites{index}.specie;
    if isprop(specie, "oxi_state"), valences(index) = specie.oxi_state;
    else, decorated = false; break
    end
end
if ~decorated
    analyzer = kssolv.analysis.matgenlab.core.BVAnalyzer();
    valences = analyzer.get_valences(structure);
end
values = containers.Map("KeyType", "char", "ValueType", "double");
for index = 1:numel(symbols), values(symbols{index}) = valences(index); end
end

function lines = appendPotential(lines, header, body)
lines(end + 1) = string(header);
bodyLines = splitlines(string(body));
bodyLines(strlength(bodyLines) == 0) = [];
lines = [lines; reshape(bodyLines, [], 1)];
end

function [a, b, c, alpha, beta, gamma] = initialCell(lines)
a = 0; b = 0; c = 0; alpha = 0; beta = 0; gamma = 0;
marker = find(contains(lines, "Full cell parameters"), 1);
if ~isempty(marker)
    first = split(strtrim(lines(marker + 2)));
    second = split(strtrim(lines(marker + 3)));
    third = split(strtrim(lines(marker + 4)));
    a = str2double(first(9)); alpha = str2double(first(12));
    b = str2double(second(9)); beta = str2double(second(12));
    c = str2double(third(9)); gamma = str2double(third(12));
    return
end
marker = find(contains(lines, "Cell parameters"), 1);
if ~isempty(marker)
    first = split(strtrim(lines(marker + 2)));
    second = split(strtrim(lines(marker + 3)));
    third = split(strtrim(lines(marker + 4)));
    a = str2double(first(3)); alpha = str2double(first(6));
    b = str2double(second(3)); beta = str2double(second(6));
    c = str2double(third(3)); gamma = str2double(third(6));
end
end

function text = upstreamFloat(value)
text = string(sprintf("%.16g", value));
if isfinite(value) && fix(value) == value
    text = text + ".0";
end
end
