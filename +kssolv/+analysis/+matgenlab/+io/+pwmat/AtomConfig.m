classdef AtomConfig < kssolv.analysis.matgenlab.util.MSONable
    %ATOMCONFIG PWmat atom.config/final.config representation.

    properties (SetAccess = private)
        structure
        true_names (1,1) string
    end

    methods
        function obj = AtomConfig(structure, sortStructure)
            if nargin < 2, sortStructure = false; end
            obj.structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_sites(structure.sites, charge = structure.charge, ...
                properties = structure.structure_properties);
            if sortStructure
                obj.structure = obj.structure.get_sorted_structure();
            end
            if ~obj.structure.is_ordered
                error("KSSOLV:Matgenlab:PWmat:Disordered", ...
                    "AtomConfig requires an ordered structure.");
            end
            obj.true_names = trueNames(obj.structure);
        end

        function value = get_str(obj, varargin)
            if ~isempty(varargin)
                error("KSSOLV:Matgenlab:PWmat:AtomConfigOption", ...
                    "AtomConfig.get_str does not accept options.");
            end
            lattice = obj.structure.lattice.matrix;
            if det(lattice) < 0, lattice = -lattice; end
            value = string(sprintf("\t%d atoms\nLattice vector\n", ...
                obj.structure.num_sites));
            for row = 1:3
                value = value + sprintf("%15f%15f%15f\n", ...
                    lattice(row, :));
            end
            value = value + "Position, move_x, move_y, move_z" + newline;
            for index = 1:obj.structure.num_sites
                site = obj.structure(index);
                value = value + sprintf( ...
                    "%4d%15f%15f%15f   1   1   1\n", ...
                    site.specie.Z, site.frac_coords);
            end
            firstProperties = obj.structure(1).site_properties;
            if isfield(firstProperties, "magmom")
                value = value + "MAGNETIC" + newline;
                for index = 1:obj.structure.num_sites
                    site = obj.structure(index);
                    if ~isfield(site.site_properties, "magmom")
                        error("KSSOLV:Matgenlab:PWmat:Magmom", ...
                            "Every site must define magmom when the first site does.");
                    end
                    value = value + sprintf("%4d%15f\n", ...
                        site.specie.Z, site.site_properties.magmom);
                end
            end
            value = string(value);
        end

        function value = char(obj)
            value = char(obj.get_str());
        end

        function value = string(obj)
            value = obj.get_str();
        end

        function write_file(obj, filename, varargin)
            kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                write_text(filename, obj.get_str(varargin{:}));
        end

        function value = as_dict(obj)
            value = struct("x_module", "pymatgen.io.pwmat.inputs", ...
                "x_class", "AtomConfig", ...
                "structure", obj.structure.as_dict(), ...
                "true_names", obj.true_names);
        end

        function value = asDict(obj)
            value = obj.as_dict();
        end
    end

    methods (Static)
        function obj = from_str(data, mag)
            if nargin < 2, mag = false; end
            extractor = ...
                kssolv.analysis.matgenlab.io.pwmat.ACstrExtractor(data);
            lattice = reshape(extractor.get_lattice(), 3, 3).';
            numbers = extractor.get_types();
            species = arrayfun(@(number) ...
                kssolv.analysis.matgenlab.core.Element.from_Z(number), ...
                numbers, "UniformOutput", false);
            coordinates = reshape(extractor.get_coords(), 3, []).';
            siteProperties = struct();
            if mag
                siteProperties.magmom = extractor.get_magmoms();
            end
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, species, coordinates, ...
                site_properties = siteProperties);
            obj = kssolv.analysis.matgenlab.io.pwmat.AtomConfig(structure);
        end

        function obj = from_file(filename, mag)
            if nargin < 2, mag = false; end
            obj = kssolv.analysis.matgenlab.io.pwmat.AtomConfig. ...
                from_str( ...
                kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(filename), mag);
        end

        function obj = from_dict(value)
            structure = value.structure;
            if ~isa(structure, ...
                    "kssolv.analysis.matgenlab.core.Structure")
                structure = ...
                    kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(structure);
            end
            obj = kssolv.analysis.matgenlab.io.pwmat.AtomConfig( ...
                structure);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.AtomConfig. ...
                from_dict(value);
        end
    end
end

function value = trueNames(structure)
species = structure.species;
identifiers = string(cellfun(@string, species, "UniformOutput", false));
[uniqueIdentifiers, first] = unique(identifiers, "stable");
uniqueSpecies = species(first);
counts = arrayfun(@(identifier) sum(identifiers == identifier), ...
    uniqueIdentifiers);
for outer = 2:numel(uniqueSpecies)
    inner = outer;
    while inner > 1 && uniqueSpecies{inner} < uniqueSpecies{inner - 1}
        uniqueSpecies([inner - 1, inner]) = ...
            uniqueSpecies([inner, inner - 1]);
        counts([inner - 1, inner]) = counts([inner, inner - 1]);
        inner = inner - 1;
    end
end
pieces = strings(1, numel(uniqueSpecies));
for index = 1:numel(uniqueSpecies)
    pieces(index) = string(uniqueSpecies{index}) + ...
        string(counts(index));
end
value = join(pieces, "");
end
