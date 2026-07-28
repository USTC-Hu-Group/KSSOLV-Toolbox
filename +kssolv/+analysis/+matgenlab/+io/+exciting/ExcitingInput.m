classdef ExcitingInput
    %EXCITINGINPUT Read and write the exciting XML structure input format.

    properties (SetAccess = private)
        structure
        title string
    end

    properties (Dependent)
        lockxyz
    end

    properties (Constant)
        bohr2ang = ...
            kssolv.analysis.matgenlab.core.Constants.value( ...
            "Bohr radius") / ...
            kssolv.analysis.matgenlab.core.Constants.value( ...
            "Angstrom star")
    end

    methods
        function obj = ExcitingInput(structure, title, lockxyz)
            if nargin < 2 || isempty(title), title = structure.formula; end
            if nargin < 3, lockxyz = []; end
            if ~isa(structure, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                error("KSSOLV:Matgenlab:ExcitingInput:Structure", ...
                    "structure must be a Structure or IStructure.");
            end
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:ExcitingInput:Disordered", ...
                    "Structures with partial occupancies are unsupported.");
            end
            properties = struct();
            if ~isempty(lockxyz)
                lockxyz = obj.validateLock(lockxyz, ...
                    structure.num_sites);
                properties.selective_dynamics = ...
                    num2cell(lockxyz, 2).';
            end
            obj.structure = structure.copy(properties);
            obj.title = string(title);
        end

        function value = get.lockxyz(obj)
            properties = obj.structure.site_properties;
            if ~isfield(properties, "selective_dynamics")
                value = [];
                return
            end
            entries = properties.selective_dynamics;
            if iscell(entries), value = vertcat(entries{:});
            else, value = entries;
            end
            value = logical(value);
        end

        function obj = set.lockxyz(obj, value)
            value = obj.validateLock(value, obj.structure.num_sites);
            obj.structure = obj.structure.add_site_property( ...
                "selective_dynamics", num2cell(value, 2).');
        end

        function element = write_etree(obj, celltype, varargin)
            text = obj.buildString(celltype, varargin{:});
            parser = matlab.io.xml.dom.Parser;
            document = parser.parseString(char(text));
            element = document.getDocumentElement();
        end

        function text = write_string(obj, celltype, varargin)
            text = obj.buildString(celltype, varargin{:});
        end

        function write_file(obj, celltype, filename, varargin)
            text = obj.buildString(celltype, varargin{:});
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename, text);
        end

        function value = as_dict(obj)
            value = struct( ...
                "x_module", "pymatgen.io.exciting.inputs", ...
                "x_class", "ExcitingInput", ...
                "structure", obj.structure.as_dict(), ...
                "title", obj.title, "lockxyz", obj.lockxyz);
        end
    end

    methods (Static)
        function obj = from_str(data)
            text = string(data);
            structureBlock = regexp(text, ...
                "(?s)<structure([^>]*)>(.*?)</structure>", ...
                "tokens", "once");
            if isempty(structureBlock)
                error("KSSOLV:Matgenlab:ExcitingInput:MissingStructure", ...
                    "No structure was found in the exciting input.");
            end
            titleToken = regexp(text, ...
                "(?s)<title>(.*?)</title>", "tokens", "once");
            if isempty(titleToken)
                error("KSSOLV:Matgenlab:ExcitingInput:MissingTitle", ...
                    "The exciting input must define a title.");
            end
            title = kssolv.analysis.matgenlab.io.exciting. ...
                ExcitingInput.xmlUnescape( ...
                strtrim(string(titleToken{1})));
            structureAttributes = string(structureBlock{1});
            body = string(structureBlock{2});
            cartesian = ~isempty(regexp(structureAttributes, ...
                "cartesian\s*=\s*[""'](?:true|True|1)[""']", ...
                "once"));
            crystal = regexp(body, ...
                "(?s)<crystal([^>]*)>(.*?)</crystal>", ...
                "tokens", "once");
            if isempty(crystal)
                error("KSSOLV:Matgenlab:ExcitingInput:MissingCrystal", ...
                    "The exciting structure must define a crystal.");
            end
            crystalAttributes = string(crystal{1});
            scaleToken = regexp(crystalAttributes, ...
                "scale\s*=\s*[""']([^""']+)[""']", ...
                "tokens", "once");
            if isempty(scaleToken)
                scale = kssolv.analysis.matgenlab.io.exciting. ...
                    ExcitingInput.bohr2ang;
            else
                scale = str2double(scaleToken{1}) * ...
                    kssolv.analysis.matgenlab.io.exciting. ...
                    ExcitingInput.bohr2ang;
            end
            stretchToken = regexp(crystalAttributes, ...
                "stretch\s*=\s*[""']([^""']+)[""']", ...
                "tokens", "once");
            stretch = ones(1, 3);
            if ~isempty(stretchToken)
                stretch = sscanf(stretchToken{1}, "%f").';
                if numel(stretch) ~= 3
                    error("KSSOLV:Matgenlab:ExcitingInput:Stretch", ...
                        "crystal stretch must contain three values.");
                end
            end
            vectorTokens = regexp(string(crystal{2}), ...
                "(?s)<basevect>(.*?)</basevect>", "tokens");
            if numel(vectorTokens) ~= 3
                error("KSSOLV:Matgenlab:ExcitingInput:Basis", ...
                    "crystal must contain three base vectors.");
            end
            lattice = zeros(3, 3);
            for index = 1:3
                row = sscanf(vectorTokens{index}{1}, "%f").';
                if numel(row) ~= 3
                    error("KSSOLV:Matgenlab:ExcitingInput:Basis", ...
                        "Each base vector must contain three values.");
                end
                lattice(index, :) = row .* stretch * scale;
            end
            speciesBlocks = regexp(body, ...
                "(?s)<species([^>]*)>(.*?)</species>", ...
                "tokens");
            species = cell(1, 0);
            positions = zeros(0, 3);
            locks = false(0, 3);
            for blockIndex = 1:numel(speciesBlocks)
                attributes = string(speciesBlocks{blockIndex}{1});
                fileToken = regexp(attributes, ...
                    "speciesfile\s*=\s*[""']([^""']+)[""']", ...
                    "tokens", "once");
                if isempty(fileToken)
                    error("KSSOLV:Matgenlab:ExcitingInput:SpeciesFile", ...
                        "Each species element needs speciesfile.");
                end
                [~, symbol] = fileparts(string(fileToken{1}));
                symbol = extractBefore(symbol + "_", "_");
                try
                    element = ...
                        kssolv.analysis.matgenlab.core.Element(symbol);
                catch
                    error("KSSOLV:Matgenlab:ExcitingInput:Element", ...
                        "Unknown exciting element '%s'.", symbol);
                end
                atoms = regexp(string(speciesBlocks{blockIndex}{2}), ...
                    "<atom([^>]*)/?>", "tokens");
                for atomIndex = 1:numel(atoms)
                    atomAttributes = string(atoms{atomIndex}{1});
                    coordinateToken = regexp(atomAttributes, ...
                        "coord\s*=\s*[""']([^""']+)[""']", ...
                        "tokens", "once");
                    if isempty(coordinateToken)
                        error("KSSOLV:Matgenlab:ExcitingInput:Coordinate", ...
                            "Each atom must define coord.");
                    end
                    row = sscanf(coordinateToken{1}, "%f").';
                    if numel(row) ~= 3
                        error("KSSOLV:Matgenlab:ExcitingInput:Coordinate", ...
                            "Atom coordinates must contain three values.");
                    end
                    if cartesian
                        row = row * ...
                            kssolv.analysis.matgenlab.io.exciting. ...
                            ExcitingInput.bohr2ang;
                    end
                    species{end + 1} = element; %#ok<AGROW>
                    positions(end + 1, :) = row; %#ok<AGROW>
                    lockToken = regexp(atomAttributes, ...
                        "lockxyz\s*=\s*[""']([^""']+)[""']", ...
                        "tokens", "once");
                    if isempty(lockToken)
                        locks(end + 1, :) = false; %#ok<AGROW>
                    else
                        values = lower(split(strtrim( ...
                            string(lockToken{1}))));
                        if numel(values) ~= 3
                            error("KSSOLV:Matgenlab:ExcitingInput:Lock", ...
                                "lockxyz must contain three booleans.");
                        end
                        locks(end + 1, :) = ...
                            reshape(values == "true", 1, 3); %#ok<AGROW>
                    end
                end
            end
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, species, positions, ...
                coords_are_cartesian = cartesian);
            obj = kssolv.analysis.matgenlab.io.exciting.ExcitingInput( ...
                structure, title, locks);
        end

        function obj = from_file(filename)
            text = string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
            obj = ...
                kssolv.analysis.matgenlab.io.exciting.ExcitingInput. ...
                from_str(text);
        end

        function obj = from_dict(value)
            structure = kssolv.analysis.matgenlab.util.decode( ...
                value.structure);
            lock = [];
            if isfield(value, "lockxyz"), lock = value.lockxyz; end
            obj = kssolv.analysis.matgenlab.io.exciting.ExcitingInput( ...
                structure, string(value.title), lock);
        end
    end

    methods (Access = private)
        function text = buildString(obj, celltype, varargin)
            options = obj.parseOptions(varargin{:});
            celltype = lower(string(celltype));
            analyzer = ...
                kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(obj.structure, ...
                options.symprec, options.angle_tolerance);
            switch celltype
                case "unchanged"
                    selected = obj.structure;
                case "primitive"
                    selected = analyzer. ...
                        get_primitive_standard_structure(false);
                case "conventional"
                    selected = analyzer. ...
                        get_conventional_standard_structure(false);
                otherwise
                    error("KSSOLV:Matgenlab:ExcitingInput:CellType", ...
                        "Type of unit cell not recognized.");
            end
            if options.bandstr && celltype ~= "primitive"
                error("KSSOLV:Matgenlab:ExcitingInput:BandCell", ...
                    "Bandstructure is only supported for the standard " + ...
                    "primitive cell.");
            end
            lines = [ ...
                "<input xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" " + ...
                "xsi:noNamespaceSchemaLocation=""http://xml.exciting-code.org/" + ...
                "excitinginput.xsd"">"
                "  <title>" + obj.xmlEscape(obj.title) + "</title>"];
            if options.cartesian
                lines(end + 1) = ...
                    "  <structure cartesian=""true"" speciespath=""./"">";
            else
                lines(end + 1) = "  <structure speciespath=""./"">";
            end
            scale = 1 / obj.bohr2ang;
            lines(end + 1) = ...
                "    <crystal scale=""" + sprintf("%.16g", scale) + """>";
            basis = selected.lattice.matrix;
            for axis = 1:3
                lines(end + 1) = "      <basevect>" + sprintf( ...
                    "%16.8f %16.8f %16.8f", basis(axis, :)) + ...
                    "</basevect>"; %#ok<AGROW>
            end
            lines(end + 1) = "    </crystal>";
            types = selected.types_of_species;
            electronegativity = cellfun(@(entry) entry.X, types);
            [~, order] = sort(electronegativity);
            for typeIndex = order
                element = types{typeIndex};
                lines(end + 1) = "    <species speciesfile=""" + ...
                    element.symbol + ".xml"">"; %#ok<AGROW>
                indices = selected.indices_from_symbol(element.symbol);
                for siteIndex = reshape(indices, 1, [])
                    fractional = selected(siteIndex).frac_coords;
                    if options.cartesian
                        coordinate = zeros(1, 3);
                        for axis = 1:3
                            coordinate(axis) = fractional(axis) * ...
                                sum(basis(:, axis)) * scale;
                        end
                    else
                        coordinate = fractional;
                    end
                    lines(end + 1) = "      <atom coord=""" + ...
                        sprintf("%16.8f %16.8f %16.8f", coordinate) + ...
                        """ />"; %#ok<AGROW>
                end
                lines(end + 1) = "    </species>"; %#ok<AGROW>
            end
            lines(end + 1) = "  </structure>";
            if options.bandstr
                path = kssolv.analysis.matgenlab.symmetry.HighSymmKpath( ...
                    selected, false, [], ...
                    "setyawan_curtarolo", ...
                    options.symprec, options.angle_tolerance);
                lines(end + 1) = "  <properties>";
                lines(end + 1) = "    <bandstructure>";
                for pathIndex = 1:numel(path.kpath.path)
                    lines(end + 1) = "      <plot1d>"; %#ok<AGROW>
                    lines(end + 1) = ...
                        "        <path steps=""100"">"; %#ok<AGROW>
                    labels = path.kpath.path{pathIndex};
                    for labelIndex = 1:numel(labels)
                        label = string(labels{labelIndex});
                        coordinate = path.kpath.kpoints(char(label));
                        outputLabel = replace(label, ...
                            ["\Gamma", "\Sigma", "\Delta", "\Lambda"], ...
                            ["GAMMA", "SIGMA", "DELTA", "LAMBDA"]);
                        lines(end + 1) = "          <point coord=""" + ...
                            sprintf("%16.8f %16.8f %16.8f", coordinate) + ...
                            """ label=""" + outputLabel + """ />"; %#ok<AGROW>
                    end
                    lines(end + 1) = "        </path>"; %#ok<AGROW>
                    lines(end + 1) = "      </plot1d>"; %#ok<AGROW>
                end
                lines(end + 1) = "    </bandstructure>";
                lines(end + 1) = "  </properties>";
            end
            extra = obj.structToXml(options.extra, 1);
            if ~isempty(extra), lines = [lines; extra(:)]; end
            lines(end + 1) = "</input>";
            text = strjoin(lines, newline) + newline;
        end

        function options = parseOptions(~, varargin)
            options = struct("cartesian", false, "bandstr", false, ...
                "symprec", 0.4, "angle_tolerance", 5, ...
                "extra", struct());
            if mod(numel(varargin), 2) ~= 0
                error("KSSOLV:Matgenlab:ExcitingInput:Options", ...
                    "Options must be supplied as name/value pairs.");
            end
            for index = 1:2:numel(varargin)
                name = char(string(varargin{index}));
                value = varargin{index + 1};
                if isfield(options, name) && name ~= "extra"
                    options.(name) = value;
                elseif name == "extra"
                    options.extra = value;
                else
                    options.extra.(name) = value;
                end
            end
        end

        function lines = structToXml(obj, value, level)
            lines = strings(0, 1);
            names = fieldnames(value);
            for index = 1:numel(names)
                name = string(names{index});
                entry = value.(names{index});
                rendered = obj.renderXmlNode(name, entry, level);
                lines = [lines; rendered(:)]; %#ok<AGROW>
            end
        end

        function lines = renderXmlNode(obj, name, value, level)
            lines = strings(0, 1);
            if iscell(value)
                for index = 1:numel(value)
                    rendered = obj.renderXmlNode( ...
                        name, value{index}, level);
                    lines = [lines; rendered(:)]; %#ok<AGROW>
                end
                return
            end
            if ~isstruct(value) || ~isscalar(value)
                warning("KSSOLV:Matgenlab:ExcitingInput:XmlValue", ...
                    "Cannot convert %s to exciting XML.", name);
                return
            end
            indent = string(repmat('  ', 1, level));
            attributes = "";
            children = struct();
            textContent = "";
            names = fieldnames(value);
            for index = 1:numel(names)
                fieldName = names{index};
                entry = value.(fieldName);
                if ischar(entry) || (isstring(entry) && isscalar(entry))
                    if strcmp(fieldName, "text") || ...
                            strcmp(fieldName, "text_")
                        textContent = string(entry);
                    else
                        attributes = attributes + " " + fieldName + "=""" + ...
                            obj.xmlEscape(string(entry)) + """";
                    end
                else
                    children.(fieldName) = entry;
                end
            end
            if isempty(fieldnames(children)) && textContent == ""
                lines = indent + "<" + name + attributes + " />";
                return
            end
            lines(end + 1) = indent + "<" + name + attributes + ">";
            if textContent ~= ""
                lines(end + 1) = indent + "  " + ...
                    obj.xmlEscape(textContent);
            end
            childLines = obj.structToXml(children, level + 1);
            lines = [lines; childLines(:)];
            lines(end + 1) = indent + "</" + name + ">";
        end
    end

    methods (Static, Access = private)
        function value = validateLock(value, count)
            if ~islogical(value), value = logical(value); end
            if ~isequal(size(value), [count, 3])
                error("KSSOLV:Matgenlab:ExcitingInput:LockShape", ...
                    "lockxyz must be an N-by-3 logical array.");
            end
        end

        function value = xmlEscape(value)
            value = replace(string(value), ...
                ["&", "<", ">", """", "'"], ...
                ["&amp;", "&lt;", "&gt;", "&quot;", "&apos;"]);
        end

        function value = xmlUnescape(value)
            value = replace(string(value), ...
                ["&lt;", "&gt;", "&quot;", "&apos;", "&amp;"], ...
                ["<", ">", """", "'", "&"]);
        end
    end
end
