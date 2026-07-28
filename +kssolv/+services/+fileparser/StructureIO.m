classdef StructureIO < handle
    %STRUCTUREIO Bridge matgenlab structure I/O and KSSOLV objects.
    %
    % matgenlab uses Angstrom for lattice vectors and Cartesian
    % coordinates. KSSOLV Crystal/Molecule uses Bohr for both.

    properties (SetAccess = private)
        filePath string
        KSSOLVSetupObject struct
        MatgenlabObject
        rawFileContent string
    end

    properties (Dependent, SetAccess = private)
        KSSOLVObject
    end

    properties (Hidden, SetAccess = private)
        fileContent
        fileType string
        KSSOLVObjectCache = []
        sourceObjectName string
    end

    methods
        function this = StructureIO(filePath, format)
            arguments
                filePath {mustBeTextScalar}
                format {mustBeTextScalar} = ""
            end

            this.filePath = string(filePath);
            this.readFile();
            try
                [this.MatgenlabObject, this.fileType] = ...
                    kssolv.services.fileparser.StructureIO. ...
                    readMatgenlabObject(this.filePath, string(format));
                this.sourceObjectName = ...
                    kssolv.services.fileparser.StructureIO. ...
                    sourceName(this.filePath);
                this.KSSOLVSetupObject = ...
                    kssolv.services.fileparser.StructureIO.toSetupObject( ...
                        this.MatgenlabObject, ...
                        name = this.sourceObjectName);
            catch exception
                error("KSSOLV:FileParser:StructureIO:ParseFileError", ...
                    "Error extracting data from %s: %s", ...
                    this.filePath, exception.message);
            end
        end

        function readFile(this)
            %READFILE Refresh raw text when the source is not compressed.
            if ~isfile(this.filePath)
                error("KSSOLV:FileParser:StructureIO:OpenFileError", ...
                    "Cannot open structure file: %s", this.filePath);
            end
            if endsWith(lower(this.filePath), [".gz", ".bz2"])
                this.rawFileContent = "";
                this.fileContent = cell(0, 1);
                return
            end
            this.rawFileContent = string(fileread(this.filePath));
            this.fileContent = cellstr(splitlines(this.rawFileContent));
        end

        function value = get.KSSOLVObject(this)
            if isempty(this.KSSOLVObjectCache)
                this.KSSOLVObjectCache = ...
                    kssolv.services.fileparser.StructureIO. ...
                    fromMatgenlab(this.MatgenlabObject, ...
                        name = this.sourceObjectName);
            end
            value = this.KSSOLVObjectCache;
        end

        function [content, format] = getDisplayData(this)
            if isa(this.MatgenlabObject, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                format = "cif";
            else
                format = "xyz";
            end
            content = this.MatgenlabObject.to("", format);
        end

        function value = toInfoStruct(this)
            %TOINFOSTRUCT Return the JSON-safe subset used by Info Browser.
            value = struct( ...
                "filePath", this.filePath, ...
                "KSSOLVSetupObject", this.KSSOLVSetupObject, ...
                "rawFileContent", this.rawFileContent);
        end
    end

    methods (Static)
        function [kssolvObject, matgenlabObject, format] = read(filePath, format, options)
            arguments
                filePath {mustBeTextScalar}
                format {mustBeTextScalar} = ""
                options.vacuum (1, 1) double {mustBePositive} = 10
            end

            filePath = string(filePath);
            if ~isfile(filePath)
                error("KSSOLV:FileParser:StructureIO:MissingFile", ...
                    "Structure file '%s' does not exist.", filePath);
            end

            [matgenlabObject, format] = ...
                kssolv.services.fileparser.StructureIO. ...
                readMatgenlabObject(filePath, string(format));
            name = kssolv.services.fileparser.StructureIO. ...
                sourceName(filePath);
            kssolvObject = ...
                kssolv.services.fileparser.StructureIO.fromMatgenlab( ...
                    matgenlabObject, name = name, vacuum = options.vacuum);
        end

        function kssolvObject = fromMatgenlab(value, options)
            arguments
                value
                options.name {mustBeTextScalar} = ""
                options.vacuum (1, 1) double {mustBePositive} = 10
            end

            if isa(value, "kssolv.analysis.matgenlab.core.IStructure")
                setup = kssolv.services.fileparser.StructureIO. ...
                    structureSetup(value, string(options.name));
                kssolvObject = Crystal( ...
                    'name', char(setup.name), ...
                    'supercell', setup.C, ...
                    'atomlist', setup.atomListObjects, ...
                    'xyzlist', setup.xyzList);
                return
            end

            if isa(value, "kssolv.analysis.matgenlab.core.IMolecule")
                setup = kssolv.services.fileparser.StructureIO. ...
                    moleculeSetup(value, string(options.name), options.vacuum);
                kssolvObject = Molecule( ...
                    'name', char(setup.name), ...
                    'supercell', setup.C, ...
                    'atomlist', setup.atomListObjects, ...
                    'xyzlist', setup.xyzList);
                return
            end

            error("KSSOLV:FileParser:StructureIO:MatgenlabType", ...
                "Expected a matgenlab IStructure or IMolecule, received '%s'.", ...
                class(value));
        end

        function value = toMatgenlab(kssolvObject, options)
            arguments
                kssolvObject
                options.periodic = []
            end

            if ~isa(kssolvObject, "Molecule")
                error("KSSOLV:FileParser:StructureIO:KSSOLVType", ...
                    "Expected a KSSOLV Crystal or Molecule, received '%s'.", ...
                    class(kssolvObject));
            end

            if isempty(options.periodic)
                periodic = isa(kssolvObject, "Crystal");
            else
                periodic = logical(options.periodic);
                if ~isscalar(periodic)
                    error("KSSOLV:FileParser:StructureIO:Periodic", ...
                        "periodic must be a logical scalar.");
                end
            end

            factor = kssolv.analysis.matgenlab.core.UnitConstants. ...
                ang_to_bohr;
            species = arrayfun(@(atom) string(atom.symbol), ...
                kssolvObject.atomlist);
            coordinates = double(kssolvObject.xyzlist) / factor;

            objectProperties = struct("name", string(kssolvObject.name));
            if periodic
                lattice = double(kssolvObject.supercell) / factor;
                value = kssolv.analysis.matgenlab.core.Structure( ...
                    lattice, species, coordinates, ...
                    coords_are_cartesian = true, ...
                    properties = objectProperties);
            else
                value = kssolv.analysis.matgenlab.core.Molecule( ...
                    species, coordinates, properties = objectProperties);
            end
        end

        function text = write(kssolvObject, filePath, format)
            arguments
                kssolvObject
                filePath {mustBeTextScalar}
                format {mustBeTextScalar} = ""
            end

            filePath = string(filePath);
            format = string(format);
            [handler, kind] = ...
                kssolv.services.fileparser.StructureIO. ...
                resolveWritableFormat(filePath, format, kssolvObject);

            if kind == "molecule"
                value = kssolv.services.fileparser.StructureIO. ...
                    toMatgenlab(kssolvObject, periodic = false);
            else
                value = kssolv.services.fileparser.StructureIO. ...
                    toMatgenlab(kssolvObject, periodic = true);
            end
            text = value.to(filePath, handler.name);
        end

        function setup = toSetupObject(value, options)
            arguments
                value
                options.name {mustBeTextScalar} = ""
                options.vacuum (1, 1) double {mustBePositive} = 10
            end

            if isa(value, "kssolv.analysis.matgenlab.core.IStructure")
                setup = kssolv.services.fileparser.StructureIO. ...
                    structureSetup(value, string(options.name));
            elseif isa(value, "kssolv.analysis.matgenlab.core.IMolecule")
                setup = kssolv.services.fileparser.StructureIO. ...
                    moleculeSetup(value, string(options.name), options.vacuum);
            else
                error("KSSOLV:FileParser:StructureIO:MatgenlabType", ...
                    "Expected a matgenlab IStructure or IMolecule, received '%s'.", ...
                    class(value));
            end
            setup = rmfield(setup, "atomListObjects");
        end

        function formats = supportedFormats()
            structureFormats = ...
                kssolv.analysis.matgenlab.io.list_structure_formats();
            moleculeFormats = ...
                kssolv.analysis.matgenlab.io.list_molecule_formats();
            formats = struct( ...
                "structureRead", ...
                    kssolv.services.fileparser.StructureIO. ...
                    formatNames(structureFormats, "read"), ...
                "structureWrite", ...
                    kssolv.services.fileparser.StructureIO. ...
                    formatNames(structureFormats, "write"), ...
                "moleculeRead", ...
                    kssolv.services.fileparser.StructureIO. ...
                    formatNames(moleculeFormats, "read"), ...
                "moleculeWrite", ...
                    kssolv.services.fileparser.StructureIO. ...
                    formatNames(moleculeFormats, "write"));
        end
    end

    methods (Static, Access = private)
        function [value, format] = readMatgenlabObject(filePath, requestedFormat)
            structureHandler = [];
            moleculeHandler = [];
            if requestedFormat == ""
                try
                    structureHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_structure_format("filename", filePath);
                catch exception
                    if ~contains(exception.identifier, ...
                            "KSSOLV:Matgenlab:Registry")
                        rethrow(exception)
                    end
                end
                try
                    moleculeHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_molecule_format("filename", filePath);
                catch exception
                    if ~contains(exception.identifier, ...
                            "KSSOLV:Matgenlab:Registry")
                        rethrow(exception)
                    end
                end
            else
                try
                    structureHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_structure_format("name", requestedFormat);
                catch exception
                    if ~contains(exception.identifier, ...
                            "KSSOLV:Matgenlab:Registry")
                        rethrow(exception)
                    end
                end
                try
                    moleculeHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_molecule_format("name", requestedFormat);
                catch exception
                    if ~contains(exception.identifier, ...
                            "KSSOLV:Matgenlab:Registry")
                        rethrow(exception)
                    end
                end
            end

            structureError = [];
            if kssolv.services.fileparser.StructureIO.canRead( ...
                    structureHandler)
                try
                    if ~isempty(structureHandler.read_file)
                        value = feval(structureHandler.read_file, filePath);
                    else
                        value = kssolv.analysis.matgenlab.core.Structure. ...
                            from_file(filePath, structureHandler.name);
                    end
                    if isa(value, ...
                            "kssolv.analysis.matgenlab.core.IStructure") && ...
                            ~isa(value, ...
                            "kssolv.analysis.matgenlab.core.Structure")
                        value = kssolv.analysis.matgenlab.core.Structure. ...
                            from_sites(value.sites, ...
                            properties = value.structure_properties);
                    end
                    format = structureHandler.name;
                    return
                catch structureError
                    % Ambiguous JSON/YAML inputs may contain a Molecule.
                end
            end

            if kssolv.services.fileparser.StructureIO.canRead( ...
                    moleculeHandler)
                try
                    if ~isempty(moleculeHandler.read_file)
                        value = feval(moleculeHandler.read_file, filePath);
                    else
                        value = kssolv.analysis.matgenlab.core.Molecule. ...
                            from_file(filePath, moleculeHandler.name);
                    end
                    if isa(value, ...
                            "kssolv.analysis.matgenlab.core.IMolecule") && ...
                            ~isa(value, ...
                            "kssolv.analysis.matgenlab.core.Molecule")
                        value = kssolv.analysis.matgenlab.core.Molecule. ...
                            from_sites(value.sites, charge = value.charge, ...
                            spin_multiplicity = value.spin_multiplicity, ...
                            properties = value.molecule_properties);
                    end
                    format = moleculeHandler.name;
                    return
                catch moleculeError
                    if isempty(structureError)
                        rethrow(moleculeError)
                    end
                end
            end

            if ~isempty(structureError)
                rethrow(structureError)
            end
            if requestedFormat == ""
                description = sprintf("filename '%s'", filePath);
            else
                description = sprintf("format '%s'", requestedFormat);
            end
            error("KSSOLV:FileParser:StructureIO:UnsupportedFormat", ...
                "No readable matgenlab structure or molecule handler for %s.", ...
                description);
        end

        function [handler, kind] = resolveWritableFormat( ...
                filePath, requestedFormat, kssolvObject)
            structureHandler = [];
            moleculeHandler = [];
            if requestedFormat == ""
                try
                    structureHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_structure_format("filename", filePath);
                catch
                end
                try
                    moleculeHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_molecule_format("filename", filePath);
                catch
                end
            else
                try
                    structureHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_structure_format("name", requestedFormat);
                catch
                end
                try
                    moleculeHandler = ...
                        kssolv.analysis.matgenlab.io. ...
                        get_molecule_format("name", requestedFormat);
                catch
                end
            end

            moleculeWritable = ...
                kssolv.services.fileparser.StructureIO.canWrite( ...
                    moleculeHandler);
            structureWritable = ...
                kssolv.services.fileparser.StructureIO.canWrite( ...
                    structureHandler);
            if ~isa(kssolvObject, "Crystal") && moleculeWritable
                handler = moleculeHandler;
                kind = "molecule";
            elseif structureWritable
                handler = structureHandler;
                kind = "structure";
            elseif moleculeWritable
                handler = moleculeHandler;
                kind = "molecule";
            else
                error("KSSOLV:FileParser:StructureIO:UnsupportedFormat", ...
                    "No writable matgenlab handler for '%s'.", ...
                    kssolv.services.fileparser.StructureIO. ...
                    formatDescription(filePath, requestedFormat));
            end
        end

        function setup = structureSetup(value, name)
            factor = kssolv.analysis.matgenlab.core.UnitConstants. ...
                ang_to_bohr;
            [symbols, atoms] = ...
                kssolv.services.fileparser.StructureIO.atomData(value);
            setup = struct( ...
                "name", ...
                    kssolv.services.fileparser.StructureIO. ...
                    objectName(value, name, "Crystal"), ...
                "atomList", {cellstr(symbols)}, ...
                "atomListObjects", atoms, ...
                "xyzList", double(value.cart_coords) * factor, ...
                "C", double(value.lattice.matrix) * factor);
        end

        function setup = moleculeSetup(value, name, vacuum)
            factor = kssolv.analysis.matgenlab.core.UnitConstants. ...
                ang_to_bohr;
            [symbols, atoms] = ...
                kssolv.services.fileparser.StructureIO.atomData(value);
            coordinates = double(value.cart_coords);
            minimum = min(coordinates, [], 1);
            maximum = max(coordinates, [], 1);
            cellLengths = maximum - minimum + vacuum;
            coordinates = coordinates - minimum + vacuum / 2;
            setup = struct( ...
                "name", ...
                    kssolv.services.fileparser.StructureIO. ...
                    objectName(value, name, "Molecule"), ...
                "atomList", {cellstr(symbols)}, ...
                "atomListObjects", atoms, ...
                "xyzList", coordinates * factor, ...
                "C", diag(cellLengths * factor));
        end

        function [symbols, atoms] = atomData(value)
            count = value.num_sites;
            symbols = strings(1, count);
            atoms(1, count) = Atom();
            warned = false;
            for index = 1:count
                site = value.get_site(index);
                if site.is_ordered
                    specie = site.specie;
                else
                    [species, occupancies] = site.species.items();
                    [~, selected] = max(occupancies);
                    specie = species{selected};
                    warned = true;
                end
                if ~isprop(specie, "symbol")
                    error("KSSOLV:FileParser:StructureIO:UnsupportedSpecies", ...
                        "KSSOLV cannot represent site %d species '%s'.", ...
                        index, site.species_string);
                end
                symbols(index) = string(specie.symbol);
                try
                    atoms(index) = Atom(char(symbols(index)));
                catch exception
                    error("KSSOLV:FileParser:StructureIO:UnsupportedSpecies", ...
                        "KSSOLV cannot represent site %d species '%s': %s", ...
                        index, symbols(index), exception.message);
                end
            end
            if warned
                warning("KSSOLV:FileParser:StructureIO:DisorderedSites", ...
                    "KSSOLV Atom cannot store partial occupancies; each " + ...
                    "disordered site was mapped to its highest-occupancy species.");
            end
        end

        function name = objectName(value, requestedName, fallback)
            name = string(requestedName);
            if name ~= "", return; end
            if isprop(value, "structure_properties") && ...
                    isfield(value.structure_properties, "name")
                name = string(value.structure_properties.name);
            elseif isprop(value, "molecule_properties") && ...
                    isfield(value.molecule_properties, "name")
                name = string(value.molecule_properties.name);
            elseif isprop(value, "formula")
                name = string(value.formula);
            else
                name = string(fallback);
            end
            if name == "", name = string(fallback); end
        end

        function result = canRead(handler)
            result = ~isempty(handler) && ...
                (~isempty(handler.read_str) || ~isempty(handler.read_file));
        end

        function result = canWrite(handler)
            result = ~isempty(handler) && ...
                (~isempty(handler.write_str) || ~isempty(handler.write_file));
        end

        function names = formatNames(formats, direction)
            names = strings(1, 0);
            for index = 1:numel(formats)
                handler = formats{index};
                if direction == "read"
                    selected = ...
                        kssolv.services.fileparser.StructureIO. ...
                        canRead(handler);
                else
                    selected = ...
                        kssolv.services.fileparser.StructureIO. ...
                        canWrite(handler);
                end
                if selected, names(end + 1) = handler.name; end %#ok<AGROW>
            end
            names = sort(unique(names));
        end

        function value = formatDescription(filePath, requestedFormat)
            if requestedFormat == ""
                value = string(filePath);
            else
                value = string(requestedFormat);
            end
        end

        function name = sourceName(filePath)
            [~, name, extension] = fileparts(string(filePath));
            if any(lower(extension) == [".gz", ".bz2"])
                [~, name] = fileparts(name);
            end
            name = string(name);
        end
    end
end
