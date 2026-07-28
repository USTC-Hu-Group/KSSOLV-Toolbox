classdef OptimadeStructureAdapter
    %OPTIMADESTRUCTUREADAPTER Convert native structures to/from OPTIMADE.

    methods (Static)
        function resource = get_optimade_structure(structure, varargin)
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:Optimade:Disordered", ...
                    "OPTIMADE Adapter currently only supports ordered structures");
            end
            symbols = strings(1, structure.num_sites);
            for index = 1:structure.num_sites
                symbols(index) = structure.species{index}.symbol;
            end
            elements = sort(unique(symbols));
            species = repmat(struct("name", "", ...
                "chemical_symbols", strings(1, 0), ...
                "concentration", zeros(1, 0)), numel(elements), 1);
            for index = 1:numel(elements)
                species(index).name = elements(index);
                species(index).chemical_symbols = elements(index);
                species(index).concentration = 1;
            end
            amounts = arrayfun(@(element) sum(symbols == element), ...
                elements);
            divisor = gcdVector(amounts);
            reduced = amounts ./ divisor;
            reducedFormula = formulaString(elements, reduced);
            anonymousCounts = sort(reduced, "descend");
            anonymousNames = arrayfun(@anonymousElement, ...
                1:numel(anonymousCounts));
            anonymousFormula = formulaString(anonymousNames, ...
                anonymousCounts);

            attributes = struct();
            attributes.cartesian_site_positions = structure.cart_coords;
            attributes.lattice_vectors = structure.lattice.matrix;
            attributes.species_at_sites = symbols;
            attributes.species = species;
            attributes.dimension_types = double(structure.lattice.pbc);
            attributes.nperiodic_dimensions = ...
                sum(attributes.dimension_types);
            attributes.nelements = numel(elements);
            attributes.chemical_formula_anonymous = anonymousFormula;
            attributes.elements = elements;
            attributes.chemical_formula_reduced = reducedFormula;
            attributes.chemical_formula_descriptive = ...
                structure.composition.formula;
            attributes.elements_ratios = amounts ./ sum(amounts);
            attributes.nsites = structure.num_sites;
            attributes.last_modified = [];
            attributes.immutable_id = [];
            attributes.structure_features = strings(1, 0);
            resource = struct("attributes", attributes);
        end

        function structure = get_structure(resource)
            if ischar(resource) || (isstring(resource) && isscalar(resource))
                try
                    resource = jsondecode(resource);
                catch exception
                    error("KSSOLV:Matgenlab:Optimade:JSON", ...
                        "Could not decode the input OPTIMADE resource as JSON: %s", ...
                        exception.message);
                end
            end
            if ~isstruct(resource)
                error("KSSOLV:Matgenlab:Optimade:Resource", ...
                    "OPTIMADE resource must be a struct or JSON string.");
            end
            if ~isfield(resource, "attributes")
                resource = struct("attributes", resource);
            end
            identifier = [];
            if isfield(resource, "id"), identifier = resource.id; end
            attributes = resource.attributes;
            properties = struct("optimade_id", identifier);
            names = string(fieldnames(attributes));
            custom = names(startsWith(names, "_") | ...
                startsWith(names, "x_"));
            if ~isempty(custom)
                values = struct();
                for index = 1:numel(custom)
                    name = char(custom(index));
                    values.(name) = attributes.(name);
                end
                properties.optimade_attributes = values;
            end
            lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                double(attributes.lattice_vectors), ...
                logical(reshape(attributes.dimension_types, 1, [])));
            species = reshape(string(attributes.species_at_sites), 1, []);
            if any(species == "vacancy")
                error("KSSOLV:Matgenlab:Optimade:VacancySite", ...
                    "A site cannot consist solely of vacancy.");
            end
            structure = kssolv.analysis.matgenlab.core.Structure( ...
                lattice, cellstr(species), ...
                double(attributes.cartesian_site_positions), ...
                coords_are_cartesian = true, properties = properties);
        end
    end
end

function divisor = gcdVector(values)
values = round(values);
divisor = values(1);
for index = 2:numel(values)
    divisor = gcd(divisor, values(index));
end
end

function formula = formulaString(symbols, counts)
pieces = strings(1, numel(symbols));
for index = 1:numel(symbols)
    suffix = "";
    if counts(index) ~= 1, suffix = string(counts(index)); end
    pieces(index) = symbols(index) + suffix;
end
formula = strjoin(pieces, "");
end

function symbol = anonymousElement(index)
if index <= 26
    symbol = string(char('A' + index - 1));
    return
end
offset = index - 27;
first = floor(offset / 26);
second = mod(offset, 26);
symbol = string(char('A' + first)) + string(char('a' + second));
end
