classdef CifParser < handle
    %CIFPARSER Parse CIF and magCIF files into matgenlab Structures.
    %
    % This implementation follows pymatgen-core v2026.7.24. Production
    % parsing is pure MATLAB; kssolv.analysis.spglib is used for cells and
    % symmetry when the CIF does not contain explicit operations.

    properties (SetAccess = private)
        cif kssolv.analysis.matgenlab.io.cif.CifFile
        occupancy_tolerance (1,1) double = 1
        site_tolerance (1,1) double = 1e-4
        frac_tolerance (1,1) double = 1e-4
        check_cif (1,1) logical = true
        comp_tol (1,1) double = 0.01
        feature_flags (1,1) struct = struct( ...
            "magcif", false, "magcif_incommensurate", false)
        warnings (1,:) string = strings(1, 0)
        symmetry_operations cell = cell(1, 0)
    end

    properties (Dependent, SetAccess = private)
        has_errors
    end

    methods
        function obj = CifParser(filename, options)
            arguments
                filename = ""
                options.occupancy_tolerance (1,1) double {mustBePositive} = 1
                options.site_tolerance (1,1) double {mustBeNonnegative} = 1e-4
                options.frac_tolerance (1,1) double {mustBeNonnegative} = 1e-4
                options.check_cif (1,1) logical = true
                options.comp_tol (1,1) double {mustBeNonnegative} = 0.01
            end
            if string(filename) == "", return; end
            if ~(ischar(filename) || (isstring(filename) && isscalar(filename)))
                error("KSSOLV:Matgenlab:CifParser:UnsupportedInput", ...
                    "CifParser expects a CIF filename; use from_str for text.");
            end
            if ~isfile(filename)
                error("KSSOLV:Matgenlab:CifParser:MissingFile", ...
                    "CIF file '%s' does not exist.", filename);
            end
            file = kssolv.analysis.matgenlab.io.cif.CifFile.from_file(filename);
            obj.initialize(file.orig_string, options);
        end

        function value = get.has_errors(obj), value = ~isempty(obj.warnings); end

        function lattice = get_lattice(obj, data, length_strings, ...
                angle_strings, lattice_type)
            if nargin < 3 || isempty(length_strings)
                length_strings = ["a", "b", "c"];
            end
            if nargin < 4 || isempty(angle_strings)
                angle_strings = ["alpha", "beta", "gamma"];
            end
            if nargin < 5, lattice_type = ""; end
            try
                lattice = obj.get_lattice_no_exception( ...
                    data, length_strings, angle_strings, lattice_type);
                return
            catch exception
                if ~strcmp(exception.identifier, ...
                        "KSSOLV:Matgenlab:CifBlock:MissingKey")
                    rethrow(exception)
                end
            end
            lattice = [];
            settingKeys = ["_symmetry_cell_setting", ...
                "_space_group_crystal_system"];
            for key = settingKeys
                if isKey(data.data, char(key))
                    type = lower(string(data.data(char(key))));
                    try
                        lattice = obj.latticeFromCrystalSystem(data, type);
                    catch exception
                        obj.addWarning(string(exception.message), false);
                    end
                    return
                end
            end
        end

        function lattice = get_lattice_no_exception(obj, data, ...
                length_strings, angle_strings, lattice_type)
            if nargin < 3 || isempty(length_strings)
                length_strings = ["a", "b", "c"];
            end
            if nargin < 4 || isempty(angle_strings)
                angle_strings = ["alpha", "beta", "gamma"];
            end
            if nargin < 5, lattice_type = ""; end
            lengths = zeros(1, numel(length_strings));
            angles = zeros(1, numel(angle_strings));
            for index = 1:numel(length_strings)
                lengths(index) = ...
                    kssolv.analysis.matgenlab.io.cif.CifParser.str2float( ...
                    data("_cell_length_" + string(length_strings(index))));
            end
            for index = 1:numel(angle_strings)
                angles(index) = ...
                    kssolv.analysis.matgenlab.io.cif.CifParser.str2float( ...
                    data("_cell_angle_" + string(angle_strings(index))));
            end
            if string(lattice_type) == ""
                lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                    from_parameters(lengths(1), lengths(2), lengths(3), ...
                    angles(1), angles(2), angles(3));
            else
                lattice = obj.latticeFromCrystalSystem(data, lattice_type);
            end
        end

        function operations = get_symops(obj, data)
            labels = [
                "_symmetry_equiv_pos_as_xyz"
                "_symmetry_equiv_pos_as_xyz_"
                "_space_group_symop_operation_xyz"
                "_space_group_symop_operation_xyz_"
                ];
            operations = cell(1, 0);
            for label = labels.'
                if ~isKey(data.data, char(label)), continue; end
                values = obj.asList(data.data(char(label)));
                try
                    operations = cellfun(@(text) ...
                        kssolv.analysis.matgenlab.core.SymmOp.from_xyz_str( ...
                        string(text)), values, "UniformOutput", false);
                    if isscalar(values)
                        obj.addWarning( ...
                            "A 1-line symmetry op P1 CIF is detected!", false);
                    end
                    return
                catch
                    operations = cell(1, 0);
                end
            end

            [number, symbol, sourceLabel] = obj.spaceGroupIdentity(data);
            hallNumber = obj.findHallNumber(number, symbol);
            if ~isempty(hallNumber)
                try
                    [rotations, translations] = ...
                        kssolv.analysis.spglib.Spglib.getSymmetryFromDatabase( ...
                        int32(hallNumber));
                    count = size(translations, 1);
                    operations = cell(1, count);
                    for index = 1:count
                        rotation = squeeze(rotations(index, :, :));
                        operations{index} = ...
                            kssolv.analysis.matgenlab.core.SymmOp. ...
                            from_rotation_and_translation( ...
                            double(rotation), translations(index, :));
                    end
                    obj.addWarning( ...
                        "No explicit symmetry operations found. Space group from " + ...
                        sourceLabel + " used.", true);
                    return
                catch exception
                    obj.addWarning("Could not load space-group operations: " + ...
                        string(exception.message), false);
                end
            end

            obj.addWarning("No _symmetry_equiv_pos_as_xyz type key found. " + ...
                "Defaulting to P1.", true);
            operations = { ...
                kssolv.analysis.matgenlab.core.SymmOp.from_xyz_str("x, y, z")};
        end

        function operations = get_magsymops(obj, data)
            operationKey = "_space_group_symop_magn_operation.xyz";
            centeringKey = "_space_group_symop_magn_centering.xyz";
            operations = cell(1, 0);
            if isKey(data.data, operationKey)
                values = obj.asList(data.data(operationKey));
                operations = cellfun(@(text) ...
                    kssolv.analysis.matgenlab.core.MagSymmOp.from_xyzt_str( ...
                    string(text)), values, "UniformOutput", false);
                if isKey(data.data, centeringKey)
                    values = obj.asList(data.data(centeringKey));
                    centerings = cellfun(@(text) ...
                        kssolv.analysis.matgenlab.core.MagSymmOp.from_xyzt_str( ...
                        string(text)), values, "UniformOutput", false);
                    combined = cell(1, numel(operations) * numel(centerings));
                    cursor = 0;
                    for first = 1:numel(operations)
                        for second = 1:numel(centerings)
                            cursor = cursor + 1;
                            op = operations{first};
                            center = centerings{second};
                            combined{cursor} = ...
                                kssolv.analysis.matgenlab.core.MagSymmOp. ...
                                from_rotation_and_translation_and_time_reversal( ...
                                op.rotation_matrix, ...
                                mod(op.translation_vector + ...
                                center.translation_vector, 1), ...
                                time_reversal = op.time_reversal * ...
                                center.time_reversal);
                        end
                    end
                    operations = combined;
                end
            end
            if isempty(operations)
                bnsNumber = "";
                if isKey(data.data, "_space_group_magn.number_BNS")
                    bnsNumber = string( ...
                        data.data("_space_group_magn.number_BNS"));
                elseif isKey(data.data, "_space_group_magn.name_BNS")
                    % spglib exposes BNS numbers rather than labels. This
                    % common standard label is retained for compatibility;
                    % full label lookup belongs to MagneticSpaceGroup.
                    normalized = regexprep(string( ...
                        data.data("_space_group_magn.name_BNS")), "\s", "");
                    if normalized == "P4/m'b'm'", bnsNumber = "127.395"; end
                end
                if bnsNumber ~= ""
                    [uniNumber, parentNumber] = ...
                        obj.findMagneticGroup(bnsNumber);
                    hallNumber = obj.findHallNumber(parentNumber, "");
                    if ~isempty(uniNumber) && ~isempty(hallNumber)
                        try
                            [rotations, translations, reversals] = ...
                                kssolv.analysis.spglib.Spglib. ...
                                getMagneticSymmetryFromDatabase( ...
                                int32(uniNumber), int32(hallNumber));
                            operations = cell(1, size(translations, 1));
                            for index = 1:numel(operations)
                                reversal = 1;
                                if logical(reversals(index)), reversal = -1; end
                                operations{index} = ...
                                    kssolv.analysis.matgenlab.core.MagSymmOp. ...
                                    from_rotation_and_translation_and_time_reversal( ...
                                    double(squeeze(rotations(index, :, :))), ...
                                    translations(index, :), ...
                                    time_reversal = reversal);
                            end
                        catch exception
                            obj.addWarning("Could not load magnetic " + ...
                                "space-group operations: " + ...
                                string(exception.message), false);
                        end
                    end
                end
            end
            if isempty(operations)
                % Magnetic-space-group database lookup requires a UNI number,
                % which is not the BNS number. Explicit magCIF operations are
                % authoritative; match pymatgen's primitive fallback otherwise.
                obj.addWarning("No magnetic symmetry detected, using primitive symmetry.", true);
                operations = { ...
                    kssolv.analysis.matgenlab.core.MagSymmOp. ...
                    from_xyzt_str("x, y, z, 1")};
            end
        end

        function structures = parse_structures(obj, options)
            arguments
                obj
                options.primitive = []
                options.symmetrized (1,1) logical = false
                options.check_occu (1,1) logical = true
                options.on_error (1,1) string {mustBeMember(options.on_error, ...
                    ["ignore", "warn", "raise"])} = "warn"
            end
            if isempty(options.primitive)
                primitive = false;
                obj.addWarning("The default value of primitive was changed " + ...
                    "from true to false. The cell in the CIF is returned as is.", true);
            else
                primitive = logical(options.primitive);
            end
            if primitive && options.symmetrized
                error("KSSOLV:Matgenlab:CifParser:PrimitiveSymmetrized", ...
                    "primitive and symmetrized cannot both be true.");
            end
            structures = cell(1, 0);
            for index = 1:numel(obj.cif.headers)
                block = obj.cif.data(char(obj.cif.headers(index)));
                try
                    structure = obj.getStructure(block, primitive, ...
                        options.symmetrized, options.check_occu, 0.01);
                    if ~isempty(structure)
                        structures{end + 1} = structure; %#ok<AGROW>
                    end
                catch exception
                    message = sprintf("No structure parsed for section %d in CIF.\n%s", ...
                        index, exception.message);
                    obj.warnings(end + 1) = string(message);
                    if options.on_error == "raise"
                        error("KSSOLV:Matgenlab:CifParser:Section", ...
                            "%s", message);
                    elseif options.on_error == "warn"
                        warning("KSSOLV:Matgenlab:CifParser:Section", "%s", message);
                    end
                end
            end
            if isempty(structures)
                error("KSSOLV:Matgenlab:CifParser:NoStructures", ...
                    "Invalid CIF file with no structures.");
            end
            if ~isempty(obj.warnings) && options.on_error == "warn"
                warning("KSSOLV:Matgenlab:CifParser:Issues", ...
                    "Issues encountered while parsing CIF:\n%s", ...
                    strjoin(obj.warnings, newline));
            end
        end

        function structures = get_structures(obj, primitive, varargin)
            if nargin < 2, primitive = true; end
            structures = obj.parse_structures( ...
                "primitive", primitive, varargin{:});
        end

        function output = as_dict(obj)
            output = containers.Map("KeyType", "char", "ValueType", "any");
            for header = obj.cif.headers
                block = obj.cif.data(char(header));
                output(char(header)) = block.data;
            end
        end

        function output = get_bibtex_string(obj)
            mappings = {
                "author", ["_publ_author_name", "_citation_author_name"]
                "title", ["_publ_section_title", "_citation_title"]
                "journal", ["_journal_name_full", "_journal_name_abbrev", ...
                    "_citation_journal_full", "_citation_journal_abbrev"]
                "volume", ["_journal_volume", "_citation_volume"]
                "year", ["_journal_year", "_citation_year"]
                "number", ["_journal_number", "_citation_number"]
                "doi", ["_journal_DOI", "_citation_DOI"]
                };
            entries = strings(1, 0);
            for index = 1:numel(obj.cif.headers)
                block = obj.cif.data(char(obj.cif.headers(index)));
                fields = strings(1, 0);
                for row = 1:size(mappings, 1)
                    value = obj.firstValueIgnoreCase(block, mappings{row, 2});
                    if value ~= ""
                        if mappings{row, 1} == "author"
                            value = strjoin(split(value, ";"), " and ");
                        end
                        fields(end + 1) = string(sprintf('    %s = "%s"', ...
                            mappings{row, 1}, replace(value, '"', '\"'))); %#ok<AGROW>
                    end
                end
                firstPage = obj.firstValueIgnoreCase(block, "_journal_page_first");
                lastPage = obj.firstValueIgnoreCase(block, "_journal_page_last");
                if firstPage ~= "" || lastPage ~= ""
                    fields(end + 1) = string(sprintf('    pages = "%s--%s"', ...
                        firstPage, lastPage)); %#ok<AGROW>
                end
                entries(end + 1) = "@article{cifref" + string(index - 1) + ...
                    "," + newline + strjoin(fields, "," + newline) + ...
                    newline + "}"; %#ok<AGROW>
            end
            output = char(strjoin(entries, newline + newline));
        end

        function failure = check(obj, structure)
            failure = "";
            if isempty(obj.cif.headers), return; end
            block = obj.cif.data(char(obj.cif.headers(1)));
            formula = "";
            for key = ["_chemical_formula_sum", "_chemical_formula_structural"]
                if isKey(block.data, char(key))
                    formula = string(block.data(char(key)));
                    if formula ~= "", break; end
                end
            end
            checkStoichiometry = true;
            if formula == "" && isKey(block.data, "_atom_site_type_symbol")
                checkStoichiometry = false;
                formula = strjoin(string(obj.asList( ...
                    block.data("_atom_site_type_symbol"))), " ");
            end
            try
                reported = kssolv.analysis.matgenlab.core.Composition(formula);
                reported = reported.element_composition;
                actual = structure.composition.element_composition;
            catch exception
                failure = "Cannot determine chemical composition from CIF! " + ...
                    string(exception.message);
                return
            end
            reportedElements = string(cellfun(@(x) x.symbol, reported.elements, ...
                "UniformOutput", false));
            actualElements = string(cellfun(@(x) x.symbol, actual.elements, ...
                "UniformOutput", false));
            if ~isequal(sort(reportedElements), sort(actualElements))
                missing = setdiff(reportedElements, actualElements);
                suffix = "from matgenlab structure composition";
                if isempty(missing)
                    missing = setdiff(actualElements, reportedElements);
                    suffix = "from CIF-reported composition";
                end
                failure = "Missing elements " + strjoin(missing, ", ") + " " + suffix;
                return
            end
            if checkStoichiometry && numel(reportedElements) > 1
                ratios = zeros(1, numel(reportedElements));
                for index = 1:numel(reportedElements)
                    ratios(index) = actual(reportedElements(index)) / ...
                        reported(reportedElements(index));
                end
                if max(ratios) - min(ratios) >= obj.comp_tol
                    failure = "Incorrect stoichiometry: CIF=" + reported.formula + ...
                        ", structure=" + actual.formula;
                end
            elseif ~checkStoichiometry
                obj.warnings(end + 1) = ...
                    "Skipping relative stoichiometry check because CIF does not contain formula keys.";
            end
        end
    end

    methods (Static)
        function obj = from_str(cif_string, options)
            arguments
                cif_string
                options.occupancy_tolerance (1,1) double {mustBePositive} = 1
                options.site_tolerance (1,1) double {mustBeNonnegative} = 1e-4
                options.frac_tolerance (1,1) double {mustBeNonnegative} = 1e-4
                options.check_cif (1,1) logical = true
                options.comp_tol (1,1) double {mustBeNonnegative} = 0.01
            end
            obj = kssolv.analysis.matgenlab.io.cif.CifParser();
            obj.initialize(cif_string, options);
        end

        function value = str2float(text)
            if iscell(text) && isscalar(text), text = text{1}; end
            token = regexprep(strtrim(char(string(text))), "\(.+\)*", "");
            if strcmp(token, "."), value = 0; return; end
            value = str2double(replace(lower(string(token)), "d", "e"));
            if isnan(value)
                error("KSSOLV:Matgenlab:CifParser:InvalidNumber", ...
                    "'%s' cannot be converted to float.", token);
            end
        end

        function states = parse_oxi_states(data)
            states = containers.Map("KeyType", "char", "ValueType", "double");
            if ~isKey(data.data, "_atom_type_symbol") || ...
                    ~isKey(data.data, "_atom_type_oxidation_number")
                states = [];
                return
            end
            symbols = kssolv.analysis.matgenlab.io.cif.CifParser. ...
                staticAsList(data.data("_atom_type_symbol"));
            values = kssolv.analysis.matgenlab.io.cif.CifParser. ...
                staticAsList(data.data("_atom_type_oxidation_number"));
            if numel(symbols) ~= numel(values), states = []; return; end
            try
                for index = 1:numel(symbols)
                    symbol = char(string(symbols{index}));
                    value = kssolv.analysis.matgenlab.io.cif.CifParser. ...
                        str2float(values{index});
                    states(symbol) = value;
                    stripped = regexprep(symbol, "\d?[\+,\-]?$", "");
                    states(stripped) = value;
                end
            catch
                states = [];
            end
        end

        function moments = parse_magmoms(data)
            moments = containers.Map("KeyType", "char", "ValueType", "any");
            keys = ["_atom_site_moment_label", ...
                "_atom_site_moment_crystalaxis_x", ...
                "_atom_site_moment_crystalaxis_y", ...
                "_atom_site_moment_crystalaxis_z"];
            if ~all(arrayfun(@(key) isKey(data.data, char(key)), keys))
                return
            end
            labels = kssolv.analysis.matgenlab.io.cif.CifParser. ...
                staticAsList(data.data(char(keys(1))));
            coordinates = cell(1, 3);
            for axis = 1:3
                coordinates{axis} = ...
                    kssolv.analysis.matgenlab.io.cif.CifParser. ...
                    staticAsList(data.data(char(keys(axis + 1))));
            end
            try
                for index = 1:numel(labels)
                    moments(char(string(labels{index}))) = [
                        kssolv.analysis.matgenlab.io.cif.CifParser.str2float(coordinates{1}{index})
                        kssolv.analysis.matgenlab.io.cif.CifParser.str2float(coordinates{2}{index})
                        kssolv.analysis.matgenlab.io.cif.CifParser.str2float(coordinates{3}{index})
                        ].';
                end
            catch
                moments = containers.Map("KeyType", "char", "ValueType", "any");
            end
        end
    end

    methods (Access = private)
        function initialize(obj, cifString, options)
            obj.cif = kssolv.analysis.matgenlab.io.cif.CifFile.from_str(cifString);
            obj.occupancy_tolerance = options.occupancy_tolerance;
            obj.site_tolerance = options.site_tolerance;
            obj.frac_tolerance = options.frac_tolerance;
            obj.check_cif = options.check_cif;
            obj.comp_tol = options.comp_tol;
            obj.feature_flags.magcif = obj.hasTagPrefix([
                "_space_group_magn", "_atom_site_moment", ...
                "_space_group_symop_magn"]);
            obj.feature_flags.magcif_incommensurate = ...
                obj.feature_flags.magcif && obj.hasTagPrefix([
                "_cell_modulation_dimension", "_cell_wave_vector"]);
            for header = obj.cif.headers
                block = obj.cif.data(char(header));
                obj.sanitizeData(block);
            end
        end

        function sanitizeData(obj, data)
            if isKey(data.data, "_atom_site_attached_hydrogens")
                values = obj.asList(data.data("_atom_site_attached_hydrogens"));
                nonzero = false;
                for index = 1:numel(values)
                    try
                        nonzero = nonzero || obj.str2float(values{index}) ~= 0;
                    catch
                    end
                end
                if nonzero
                    obj.warnings(end + 1) = "Structure has implicit hydrogens " + ...
                        "defined; parsed structure may need explicit hydrogens.";
                end
            end
            % Springer Materials / Pauling File exports sometimes exchange
            % atom labels and type symbols and encode a disordered site as
            % e.g. "0.8Nb + 0.2Zr". Expand that row into normal CIF rows.
            if isKey(data.data, "_atom_site_type_symbol") && ...
                    isKey(data.data, "_atom_site_label")
                labels = obj.asList(data.data("_atom_site_label"));
                symbols = obj.asList(data.data("_atom_site_type_symbol"));
                remove = zeros(1, 0);
                addedLabels = cell(1, 0);
                addedSymbols = cell(1, 0);
                addedOccupancies = cell(1, 0);
                addedX = cell(1, 0);
                addedY = cell(1, 0);
                addedZ = cell(1, 0);
                sourceX = obj.asList(data.data("_atom_site_fract_x"));
                sourceY = obj.asList(data.data("_atom_site_fract_y"));
                sourceZ = obj.asList(data.data("_atom_site_fract_z"));
                for index = 1:min(numel(labels), numel(symbols))
                    symbolText = char(string(symbols{index}));
                    labelText = char(string(labels{index}));
                    if numel(strsplit(symbolText, " + ")) <= ...
                            numel(strsplit(labelText, " + "))
                        continue
                    end
                    components = strsplit(symbolText, " + ");
                    parsed = cell(0, 2);
                    for componentIndex = 1:numel(components)
                        component = regexprep(components{componentIndex}, ...
                            "\([0-9]*\)", "");
                        component = erase(component, ["<sup>", "</sup>", ...
                            "<sub>", "</sub>"]);
                        match = regexp(strtrim(component), ...
                            "([0-9]*\.?[0-9]+)\s*([A-Z][a-z]?)", ...
                            "tokens", "once");
                        if isempty(match)
                            match = regexp(strtrim(component), ...
                                "([A-Z][a-z]?)\s*([0-9]*\.?[0-9]+)", ...
                                "tokens", "once");
                            if ~isempty(match), match = match([2,1]); end
                        end
                        if isempty(match), parsed = cell(0, 2); break; end
                        parsed(end + 1, :) = ...
                            {match{2}, str2double(match{1})}; %#ok<AGROW>
                    end
                    if isempty(parsed), continue; end
                    for componentIndex = 1:size(parsed, 1)
                        addedLabels{end + 1} = sprintf("%s_fix%d", ...
                            parsed{componentIndex, 1}, numel(addedLabels)); %#ok<AGROW>
                        addedSymbols{end + 1} = parsed{componentIndex, 1}; %#ok<AGROW>
                        addedOccupancies{end + 1} = ...
                            sprintf("%.15g", parsed{componentIndex, 2}); %#ok<AGROW>
                        addedX{end + 1} = char(string(obj.str2float( ...
                            sourceX{index}))); %#ok<AGROW>
                        addedY{end + 1} = char(string(obj.str2float( ...
                            sourceY{index}))); %#ok<AGROW>
                        addedZ{end + 1} = char(string(obj.str2float( ...
                            sourceZ{index}))); %#ok<AGROW>
                    end
                    remove(end + 1) = index; %#ok<AGROW>
                end
                if ~isempty(remove)
                    names = keys(data.data);
                    for nameIndex = 1:numel(names)
                        value = data.data(names{nameIndex});
                        if iscell(value)
                            valid = remove(remove <= numel(value));
                            value(valid) = [];
                            data.data(names{nameIndex}) = value;
                        end
                    end
                    data.data("_atom_site_label") = [ ...
                        obj.asList(data.data("_atom_site_label")), addedLabels];
                    data.data("_atom_site_type_symbol") = [ ...
                        obj.asList(data.data("_atom_site_type_symbol")), addedSymbols];
                    if ~isKey(data.data, "_atom_site_occupancy")
                        data.data("_atom_site_occupancy") = ...
                            repmat({"1"}, 1, numel(labels) - numel(remove));
                    end
                    data.data("_atom_site_occupancy") = [ ...
                        obj.asList(data.data("_atom_site_occupancy")), ...
                        addedOccupancies];
                    data.data("_atom_site_fract_x") = [ ...
                        obj.asList(data.data("_atom_site_fract_x")), addedX];
                    data.data("_atom_site_fract_y") = [ ...
                        obj.asList(data.data("_atom_site_fract_y")), addedY];
                    data.data("_atom_site_fract_z") = [ ...
                        obj.asList(data.data("_atom_site_fract_z")), addedZ];
                    obj.warnings(end + 1) = "Pauling file corrections applied.";
                end
            end
            if obj.feature_flags.magcif
                correctKeys = [
                    "_space_group_symop_magn_operation.xyz"
                    "_space_group_symop_magn_centering.xyz"
                    "_space_group_magn.name_BNS"
                    "_space_group_magn.number_BNS"
                    "_atom_site_moment_crystalaxis_x"
                    "_atom_site_moment_crystalaxis_y"
                    "_atom_site_moment_crystalaxis_z"
                    "_atom_site_moment_label"
                    ];
                originalKeys = string(keys(data.data));
                for correct = correctKeys.'
                    normalized = replace(correct, ".", "_");
                    match = find(replace(originalKeys, ".", "_") == normalized, 1);
                    if ~isempty(match)
                        data.data(char(correct)) = data.data(char(originalKeys(match)));
                    end
                end
                interim = "_magnetic_space_group.transform_to_standard_Pp_abc";
                final = "_space_group_magn.transform_BNS_Pp_abc";
                if isKey(data.data, interim)
                    data.data(final) = data.data(interim);
                    obj.warnings(end + 1) = ...
                        "Keys changed to match new magCIF specification.";
                end
            end
            for key = ["_atom_site_fract_x", "_atom_site_fract_y", ...
                    "_atom_site_fract_z"]
                if ~isKey(data.data, char(key)), continue; end
                values = obj.asList(data.data(char(key)));
                changed = 0;
                for index = 1:numel(values)
                    try
                        value = obj.str2float(values{index});
                        for ideal = [1/3, 2/3]
                            if abs(value - ideal) <= obj.frac_tolerance
                                values{index} = char(string(ideal));
                                changed = changed + 1;
                                break
                            end
                        end
                    catch
                    end
                end
                data.data(char(key)) = values;
                if changed > 0
                    obj.warnings(end + 1) = changed + ...
                        " fractional coordinates rounded to ideal values.";
                end
            end
        end

        function structure = getStructure(obj, data, primitive, ...
                symmetrized, checkOccu, minThickness)
            lattice = obj.get_lattice(data);
            if isempty(lattice)
                error("KSSOLV:Matgenlab:CifParser:MissingLattice", ...
                    "CIF data block has no complete lattice.");
            end
            thickness = [lattice.d_hkl([1,0,0]), ...
                lattice.d_hkl([0,1,0]), lattice.d_hkl([0,0,1])];
            if any(thickness < minThickness)
                error("KSSOLV:Matgenlab:CifParser:ThinCell", ...
                    "Lattice thickness is below %g angstrom.", minThickness);
            end
            if obj.feature_flags.magcif_incommensurate
                error("KSSOLV:Matgenlab:CifParser:Incommensurate", ...
                    "Incommensurate magnetic structures are not supported upstream.");
            end
            if obj.feature_flags.magcif
                obj.symmetry_operations = obj.get_magsymops(data);
                momentMap = obj.parse_magmoms(data);
            else
                obj.symmetry_operations = obj.get_symops(data);
                momentMap = containers.Map("KeyType", "char", "ValueType", "any");
            end
            oxidationStates = obj.parse_oxi_states(data);
            labels = obj.requiredList(data, "_atom_site_label");
            typeSymbols = {};
            if isKey(data.data, "_atom_site_type_symbol")
                typeSymbols = obj.asList(data.data("_atom_site_type_symbol"));
            end
            x = obj.requiredList(data, "_atom_site_fract_x");
            y = obj.requiredList(data, "_atom_site_fract_y");
            z = obj.requiredList(data, "_atom_site_fract_z");
            occupancies = repmat({1}, 1, numel(labels));
            if isKey(data.data, "_atom_site_occupancy")
                occupancies = obj.asList(data.data("_atom_site_occupancy"));
            end
            obj.requireEqualLengths(labels, x, y, z, occupancies);

            representativeCoords = zeros(0, 3);
            representativeSpecies = cell(1, 0);
            representativeMoments = zeros(0, 3);
            representativeLabels = strings(1, 0);
            implicitHydrogens = zeros(1, 0);
            for index = 1:numel(labels)
                label = string(labels{index});
                if isempty(typeSymbols), rawSymbol = label;
                else, rawSymbol = string(typeSymbols{index});
                end
                symbol = obj.parseSymbol(rawSymbol);
                if symbol == "", continue; end
                occupancy = 1;
                try
                    occupancy = obj.str2float(occupancies{index});
                catch
                end
                if checkOccu && occupancy <= 0, continue; end
                species = obj.speciesWithOxidation(symbol, rawSymbol, oxidationStates);
                composition = kssolv.analysis.matgenlab.core.Composition( ...
                    {species, max(occupancy, 1e-8)});
                coordinate = [obj.str2float(x{index}), ...
                    obj.str2float(y{index}), obj.str2float(z{index})];
                matching = obj.findRepresentative(representativeCoords, coordinate);
                if matching == 0
                    representativeCoords(end + 1, :) = coordinate; %#ok<AGROW>
                    representativeSpecies{end + 1} = composition; %#ok<AGROW>
                    representativeLabels(end + 1) = label; %#ok<AGROW>
                    if isKey(momentMap, char(label))
                        representativeMoments(end + 1, :) = momentMap(char(label)); %#ok<AGROW>
                    else
                        representativeMoments(end + 1, :) = [0,0,0]; %#ok<AGROW>
                    end
                    implicitHydrogens(end + 1) = ...
                        obj.implicitHydrogenCount(rawSymbol); %#ok<AGROW>
                else
                    representativeSpecies{matching} = ...
                        representativeSpecies{matching} + composition;
                    representativeMoments(matching, :) = [NaN, NaN, NaN];
                    representativeLabels(matching) = label;
                end
            end
            if obj.feature_flags.magcif && ...
                    any(isnan(representativeMoments), "all")
                error("KSSOLV:Matgenlab:CifParser:DisorderedMagnetic", ...
                    "Disordered magnetic structures are not supported upstream.");
            end

            allSpecies = cell(1, 0);
            allCoords = zeros(0, 3);
            allLabels = strings(1, 0);
            allMoments = zeros(0, 3);
            allHydrogens = zeros(1, 0);
            equivalentIndex = zeros(1, 0);
            for representative = 1:size(representativeCoords, 1)
                [coords, moments] = obj.uniqueCoords( ...
                    representativeCoords(representative, :), ...
                    representativeMoments(representative, :), lattice);
                for expanded = 1:size(coords, 1)
                    existing = obj.findExactCoordinate(allCoords, coords(expanded, :));
                    if existing > 0 && ...
                            allSpecies{existing} == representativeSpecies{representative}
                        continue
                    end
                    allSpecies{end + 1} = representativeSpecies{representative}; %#ok<AGROW>
                    allCoords(end + 1, :) = coords(expanded, :); %#ok<AGROW>
                    allLabels(end + 1) = representativeLabels(representative); %#ok<AGROW>
                    allMoments(end + 1, :) = moments(expanded, :); %#ok<AGROW>
                    allHydrogens(end + 1) = implicitHydrogens(representative); %#ok<AGROW>
                    equivalentIndex(end + 1) = representative; %#ok<AGROW>
                end
            end
            rawOccupancies = false;
            for index = 1:numel(allSpecies)
                total = allSpecies{index}.num_atoms;
                if total > 1
                    obj.addWarning(sprintf("Some occupancies (%g) sum to > 1.", total), true);
                    if checkOccu && total > obj.occupancy_tolerance
                        error("KSSOLV:Matgenlab:CifParser:OccupancyTolerance", ...
                            "Occupancy %g exceeded tolerance %g.", ...
                            total, obj.occupancy_tolerance);
                    end
                    if checkOccu
                        allSpecies{index} = allSpecies{index} / total;
                    else
                        rawOccupancies = true;
                    end
                end
            end
            siteProperties = struct();
            if any(allHydrogens), siteProperties.implicit_hydrogens = allHydrogens; end
            if obj.feature_flags.magcif
                siteProperties.magmom = num2cell(allMoments, 2);
            end
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, allSpecies, allCoords, ...
                site_properties = siteProperties, labels = allLabels, ...
                skip_checks = rawOccupancies);
            if symmetrized
                structure = obj.wrapSymmetrized(structure, equivalentIndex);
            elseif primitive
                structure = obj.toPrimitive(structure);
            elseif checkOccu
                structure = structure.get_sorted_structure();
            end
            if obj.check_cif
                failure = obj.check(structure);
                if failure ~= "", obj.addWarning(failure, true); end
            end
        end

        function output = toPrimitive(obj, structure)
            [types, representatives] = obj.structureTypes(structure);
            try
                [newLattice, positions, newTypes, count] = ...
                    kssolv.analysis.spglib.Spglib.findPrimitive( ...
                    structure.lattice.matrix, structure.frac_coords, types, ...
                    int32(structure.num_sites), ...
                    max(obj.site_tolerance, 1e-5));
                count = double(count);
                if count <= 0
                    error("KSSOLV:Matgenlab:CifParser:PrimitiveCell", ...
                        "spglib could not find a primitive cell.");
                end
                positions = positions(1:count, :);
                newTypes = newTypes(1:count);
                species = cell(1, count);
                labels = strings(1, count);
                names = fieldnames(structure.site_properties);
                properties = struct();
                for nameIndex = 1:numel(names)
                    name = names{nameIndex};
                    old = structure.site_properties.(name);
                    if iscell(old), properties.(name) = cell(1, count);
                    elseif isvector(old), properties.(name) = zeros(1, count);
                    else, properties.(name) = zeros(count, size(old, 2));
                    end
                end
                for index = 1:count
                    source = representatives(newTypes(index));
                    site = structure.get_site(source);
                    species{index} = site.species;
                    labels(index) = site.label;
                    for nameIndex = 1:numel(names)
                        name = names{nameIndex};
                        value = site.site_properties.(name);
                        if iscell(properties.(name))
                            properties.(name){index} = value;
                        elseif isvector(properties.(name))
                            properties.(name)(index) = value;
                        else
                            properties.(name)(index, :) = value;
                        end
                    end
                end
                output = kssolv.analysis.matgenlab.core.Structure( ...
                    kssolv.analysis.matgenlab.core.Lattice(newLattice), ...
                    species, positions, site_properties = properties, ...
                    labels = labels, skip_checks = true);
            catch exception
                obj.addWarning("Primitive-cell conversion unavailable: " + ...
                    string(exception.message), false);
                output = structure;
            end
        end

        function output = wrapSymmetrized(obj, structure, equivalentIndex)
            symmetrizedClasses = [
                "kssolv.analysis.matgenlab.symmetry.SymmetrizedStructure"
                "kssolv.analysis.matgenlab.symmetry.structure.SymmetrizedStructure"
                ];
            operationClasses = [
                "kssolv.analysis.matgenlab.symmetry.SpacegroupOperations"
                "kssolv.analysis.matgenlab.symmetry.groups.SpacegroupOperations"
                ];
            symClass = "";
            opClass = "";
            for candidate = symmetrizedClasses.'
                if ~isempty(meta.class.fromName(char(candidate)))
                    symClass = candidate;
                    break
                end
            end
            for candidate = operationClasses.'
                if ~isempty(meta.class.fromName(char(candidate)))
                    opClass = candidate;
                    break
                end
            end
            if symClass == "" || opClass == ""
                error("KSSOLV:Matgenlab:CifParser:SymmetryDependency", ...
                    "symmetrized=true requires SymmetrizedStructure and SpacegroupOperations.");
            end
            operations = feval(char(opClass), "Not Parsed", -1, ...
                obj.symmetry_operations);
            wyckoffs = repmat("Not Parsed", 1, structure.num_sites);
            output = feval(char(symClass), structure, operations, ...
                equivalentIndex, wyckoffs);
        end

        function [coordinates, moments] = uniqueCoords(obj, coordinate, ...
                moment, lattice)
            coordinates = zeros(0, 3);
            moments = zeros(0, 3);
            unitAxes = lattice.matrix ./ vecnorm(lattice.matrix, 2, 2);
            momentCartesian = moment * unitAxes;
            for index = 1:numel(obj.symmetry_operations)
                operation = obj.symmetry_operations{index};
                value = mod(operation.operate(coordinate), 1);
                if obj.findExactCoordinate(coordinates, value) > 0, continue; end
                coordinates(end + 1, :) = value; %#ok<AGROW>
                transformed = momentCartesian;
                if isa(operation, "kssolv.analysis.matgenlab.core.MagSymmOp")
                    cartRotation = lattice.matrix.' * operation.rotation_matrix / ...
                        lattice.matrix.';
                    transformed = (cartRotation * momentCartesian.').' * ...
                        det(cartRotation) * operation.time_reversal;
                end
                moments(end + 1, :) = transformed; %#ok<AGROW>
            end
        end

        function index = findRepresentative(obj, representatives, coordinate)
            index = 0;
            for candidate = 1:size(representatives, 1)
                for operationIndex = 1:numel(obj.symmetry_operations)
                    transformed = obj.symmetry_operations{operationIndex}.operate(coordinate);
                    delta = representatives(candidate, :) - transformed;
                    delta = delta - round(delta);
                    if all(abs(delta) <= obj.site_tolerance)
                        index = candidate;
                        return
                    end
                end
            end
        end

        function index = findExactCoordinate(obj, coordinates, coordinate)
            index = 0;
            for candidate = 1:size(coordinates, 1)
                delta = coordinates(candidate, :) - coordinate;
                delta = delta - round(delta);
                if all(abs(delta) <= obj.site_tolerance)
                    index = candidate;
                    return
                end
            end
        end

        function species = speciesWithOxidation(~, symbol, rawSymbol, states)
            if ~isempty(states)
                state = 0;
                if isKey(states, char(rawSymbol)), state = states(char(rawSymbol));
                elseif isKey(states, char(symbol)), state = states(char(symbol));
                end
                try
                    species = kssolv.analysis.matgenlab.core.Species(symbol, state);
                catch
                    species = kssolv.analysis.matgenlab.core.DummySpecies(symbol, state);
                end
            else
                species = kssolv.analysis.matgenlab.core.getElSp(symbol);
            end
        end

        function symbol = parseSymbol(obj, input)
            raw = char(string(input));
            specialKeys = ["Hw", "Ow", "Wat", "wat", "OH", "OH2", "NO3"];
            specialValues = ["H", "O", "O", "O", "", "", "N"];
            symbol = "";
            matchedSpecial = false;
            for index = 1:numel(specialKeys)
                if startsWith(raw, specialKeys(index))
                    symbol = specialValues(index);
                    matchedSpecial = true;
                    break
                end
            end
            if ~matchedSpecial
                if numel(raw) >= 2 && ...
                        kssolv.analysis.matgenlab.core.Element. ...
                        is_valid_symbol(string([upper(raw(1)), lower(raw(2))]))
                    symbol = string([upper(raw(1)), lower(raw(2))]);
                elseif ~isempty(raw) && ...
                        kssolv.analysis.matgenlab.core.Element. ...
                        is_valid_symbol(string(upper(raw(1))))
                    symbol = string(upper(raw(1)));
                else
                    match = regexp(raw, "w?[A-Z][a-z]*", "match", "once");
                    if ~isempty(match), symbol = string(match); end
                end
            end
            if symbol ~= "" && ~startsWith(raw, regexptranslate("escape", char(symbol)))
                obj.addWarning(string(raw) + " parsed as " + symbol, true);
            end
        end

        function count = implicitHydrogenCount(~, symbol)
            raw = char(string(symbol));
            count = 0;
            if any(startsWith(string(raw), ["Wat", "wat"])), count = 2;
            elseif startsWith(raw, "O-H"), count = 1;
            end
        end

        function [number, symbol, source] = spaceGroupIdentity(~, data)
            number = [];
            symbol = "";
            source = "";
            numberKeys = ["_space_group_IT_number", "_space_group_IT_number_", ...
                "_symmetry_Int_Tables_number", "_symmetry_Int_Tables_number_"];
            for key = numberKeys
                if isKey(data.data, char(key))
                    try
                        number = round(kssolv.analysis.matgenlab.io.cif. ...
                            CifParser.str2float(data.data(char(key))));
                        source = key;
                        break
                    catch
                    end
                end
            end
            symbolKeys = ["_symmetry_space_group_name_H-M", ...
                "_symmetry_space_group_name_H_M", "_space_group_name_Hall", ...
                "_space_group_name_H-M_alt", "_symmetry_space_group_name_hall", ...
                "_symmetry_space_group_name_h-m"];
            for key = symbolKeys
                if isKey(data.data, char(key))
                    symbol = string(data.data(char(key)));
                    if source == "", source = key; end
                    break
                end
            end
        end

        function hall = findHallNumber(~, number, symbol)
            hall = [];
            persistent cache
            try
                if isempty(cache)
                    cache = repmat(struct("number", 0, "symbols", ""), 1, 530);
                    for index = 1:530
                        item = kssolv.analysis.spglib.Spglib.getSpacegroupType(int32(index));
                        cache(index).number = double(item.number);
                        candidates = strings(1, 0);
                        for field = ["international_short", "international_full", ...
                                "international", "hall_symbol", "schoenflies"]
                            if isfield(item, char(field))
                                candidates(end + 1) = ...
                                    kssolv.analysis.matgenlab.io.cif.CifParser. ...
                                    normalizeSpaceGroup(item.(char(field))); %#ok<AGROW>
                            end
                        end
                        cache(index).symbols = candidates;
                    end
                end
                if ~isempty(number)
                    location = find([cache.number] == number, 1);
                else
                    normalized = kssolv.analysis.matgenlab.io.cif. ...
                        CifParser.normalizeSpaceGroup(symbol);
                    location = find(arrayfun(@(item) ...
                        any(item.symbols == normalized), cache), 1);
                end
                if ~isempty(location), hall = location; end
            catch
                hall = [];
            end
        end

        function [uni, parent] = findMagneticGroup(~, bnsNumber)
            uni = [];
            parent = [];
            persistent bnsNumbers parentNumbers
            try
                if isempty(bnsNumbers)
                    bnsNumbers = strings(1, 1651);
                    parentNumbers = zeros(1, 1651);
                    for index = 1:1651
                        item = kssolv.analysis.spglib.Spglib. ...
                            getMagneticSpacegroupType(int32(index));
                        bnsNumbers(index) = string(item.bns_number);
                        parentNumbers(index) = double(item.number);
                    end
                end
                location = find(bnsNumbers == strtrim(string(bnsNumber)), 1);
                if ~isempty(location)
                    uni = location;
                    parent = parentNumbers(location);
                end
            catch
                uni = [];
                parent = [];
            end
        end

        function lattice = latticeFromCrystalSystem(~, data, type)
            type = lower(string(type));
            get = @(name) kssolv.analysis.matgenlab.io.cif.CifParser. ...
                str2float(data("_cell_" + name));
            switch type
                case "cubic"
                    lattice = kssolv.analysis.matgenlab.core.Lattice.cubic( ...
                        get("length_a"));
                case "tetragonal"
                    lattice = kssolv.analysis.matgenlab.core.Lattice.tetragonal( ...
                        get("length_a"), get("length_c"));
                case {"orthorhombic", "orthorombic"}
                    lattice = kssolv.analysis.matgenlab.core.Lattice.orthorhombic( ...
                        get("length_a"), get("length_b"), get("length_c"));
                case "hexagonal"
                    lattice = kssolv.analysis.matgenlab.core.Lattice.hexagonal( ...
                        get("length_a"), get("length_c"));
                case {"rhombohedral", "trigonal"}
                    lattice = kssolv.analysis.matgenlab.core.Lattice.rhombohedral( ...
                        get("length_a"), get("angle_alpha"));
                case "monoclinic"
                    lattice = kssolv.analysis.matgenlab.core.Lattice.monoclinic( ...
                        get("length_a"), get("length_b"), get("length_c"), ...
                        get("angle_beta"));
                otherwise
                    lattice = kssolv.analysis.matgenlab.core.Lattice. ...
                        from_parameters(get("length_a"), get("length_b"), ...
                        get("length_c"), get("angle_alpha"), ...
                        get("angle_beta"), get("angle_gamma"));
            end
        end

        function tf = hasTagPrefix(obj, prefixes)
            tf = false;
            for header = obj.cif.headers
                block = obj.cif.data(char(header));
                names = string(keys(block.data));
                for prefix = prefixes
                    if any(contains(names, prefix)), tf = true; return; end
                end
            end
        end

        function addWarning(obj, message, emit)
            obj.warnings(end + 1) = string(message);
            if emit
                warning("KSSOLV:Matgenlab:CifParser:ParseWarning", "%s", message);
            end
        end

        function values = requiredList(obj, data, key)
            if ~isKey(data.data, key)
                error("KSSOLV:Matgenlab:CifParser:MissingTag", ...
                    "Required CIF tag '%s' is missing.", key);
            end
            values = obj.asList(data.data(key));
        end

        function values = asList(~, value)
            values = kssolv.analysis.matgenlab.io.cif.CifParser.staticAsList(value);
        end

        function requireEqualLengths(~, varargin)
            sizes = cellfun(@numel, varargin);
            if any(sizes ~= sizes(1))
                error("KSSOLV:Matgenlab:CifParser:LoopLength", ...
                    "Atom-site loop columns have unequal lengths.");
            end
        end

        function value = firstValueIgnoreCase(obj, block, candidates)
            value = "";
            names = string(keys(block.data));
            for candidate = reshape(string(candidates), 1, [])
                location = find(lower(names) == lower(candidate), 1);
                if isempty(location), continue; end
                values = obj.asList(block.data(char(names(location))));
                if ~isempty(values), value = string(values{1}); return; end
            end
        end

        function [types, representatives] = structureTypes(~, structure)
            names = strings(1, structure.num_sites);
            for index = 1:structure.num_sites
                names(index) = structure.get_site(index).species_string;
            end
            uniqueNames = unique(names, "stable");
            types = zeros(structure.num_sites, 1, "int32");
            representatives = zeros(1, numel(uniqueNames));
            for index = 1:numel(uniqueNames)
                locations = find(names == uniqueNames(index));
                types(locations) = int32(index);
                representatives(index) = locations(1);
            end
        end
    end

    methods (Static, Access = private)
        function values = staticAsList(value)
            if iscell(value), values = reshape(value, 1, []);
            elseif isstring(value) && ~isscalar(value)
                values = cellstr(reshape(value, 1, []));
            elseif isnumeric(value) && ~isscalar(value)
                values = num2cell(reshape(value, 1, []));
            else, values = {value};
            end
        end

        function value = normalizeSpaceGroup(input)
            value = lower(regexprep(char(string(input)), "[\s_']", ""));
        end
    end
end
