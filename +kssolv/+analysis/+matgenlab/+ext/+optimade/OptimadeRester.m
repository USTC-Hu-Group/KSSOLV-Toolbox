classdef OptimadeRester < handle
    %OPTIMADERESTER Native, transport-injected OPTIMADE v1 client.
    %
    % No implicit network implementation is installed. Supply a function
    % handle or object with a request(requestStruct) method as "transport".

    properties (Constant)
        mandatory_response_fields = [ ...
            "lattice_vectors", "cartesian_site_positions", ...
            "species", "species_at_sites"]
    end

    properties
        aliases
        resources
    end

    properties (SetAccess = private)
        providers
        timeout (1,1) double = 5
        closed (1,1) logical = false
    end

    properties (Access = private)
        transport
    end

    methods
        function obj = OptimadeRester(aliasesOrUrls, refreshAliases, ...
                timeout, varargin)
            if nargin < 1, aliasesOrUrls = []; end
            if nargin < 2 || isempty(refreshAliases), refreshAliases = false; end
            if nargin < 3 || isempty(timeout), timeout = 5; end
            options = parseOptions(varargin);
            obj.transport = options.transport;
            obj.timeout = double(timeout);
            if ~isscalar(obj.timeout) || ~isfinite(obj.timeout) || obj.timeout <= 0
                error("KSSOLV:Matgenlab:OptimadeRester:Timeout", ...
                    "timeout must be a positive finite scalar.");
            end
            if isempty(options.aliases)
                obj.aliases = obj.default_aliases();
            else
                obj.aliases = options.aliases;
            end
            if logical(refreshAliases)
                obj.refresh_aliases(options.providers_url);
            end
            obj.ensureAliasSlashes();
            obj.resources = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            obj.providers = containers.Map( ...
                "KeyType", "char", "ValueType", "any");

            requested = normalizeStrings(aliasesOrUrls);
            if isempty(requested)
                requested = string(keys(obj.aliases));
            end
            for index = 1:numel(requested)
                requestedValue = requested(index);
                requestedKey = char(requestedValue);
                if isKey(obj.aliases, requestedKey)
                    resource = string(obj.aliases(requestedKey));
                    obj.resources(requestedKey) = resource;
                else
                    provider = obj.validate_provider(requestedValue);
                    if isempty(provider)
                        continue
                    end
                    resource = appendSlash(requestedValue);
                    obj.resources(requestedKey) = resource;
                end
                obj.providers(char(resource)) = obj.validate_provider(resource);
            end
        end

        function text = char(obj)
            urls = string(values(obj.resources));
            text = char("OptimadeRester connected to: " + strjoin(urls, ", "));
        end

        function text = string(obj)
            text = string(char(obj));
        end

        function text = describe(obj)
            urls = keys(obj.providers);
            lines = strings(1, 0);
            for index = 1:numel(urls)
                provider = obj.providers(urls{index});
                if ~isempty(provider)
                    lines(end + 1) = string(provider); %#ok<AGROW>
                end
            end
            text = "OptimadeRester connected to:";
            if ~isempty(lines)
                text = text + newline + strjoin(lines, newline);
            end
        end

        function structures = get_structures(obj, elements, nelements, ...
                nsites, chemicalFormulaAnonymous, chemicalFormulaHill)
            if nargin < 2, elements = []; end
            if nargin < 3, nelements = []; end
            if nargin < 4, nsites = []; end
            if nargin < 5, chemicalFormulaAnonymous = []; end
            if nargin < 6, chemicalFormulaHill = []; end
            filter = obj.build_filter(elements, nelements, nsites, ...
                chemicalFormulaAnonymous, chemicalFormulaHill);
            structures = obj.get_structures_with_filter(filter);
        end

        function snls = get_snls(obj, elements, nelements, nsites, ...
                chemicalFormulaAnonymous, chemicalFormulaHill, ...
                additionalResponseFields)
            if nargin < 2, elements = []; end
            if nargin < 3, nelements = []; end
            if nargin < 4, nsites = []; end
            if nargin < 5, chemicalFormulaAnonymous = []; end
            if nargin < 6, chemicalFormulaHill = []; end
            if nargin < 7, additionalResponseFields = []; end
            filter = obj.build_filter(elements, nelements, nsites, ...
                chemicalFormulaAnonymous, chemicalFormulaHill);
            snls = obj.get_snls_with_filter(filter, additionalResponseFields);
        end

        function allStructures = get_structures_with_filter( ...
                obj, optimadeFilter)
            allSnls = obj.get_snls_with_filter(optimadeFilter);
            allStructures = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            providerIds = keys(allSnls);
            for providerIndex = 1:numel(providerIds)
                providerId = providerIds{providerIndex};
                snls = allSnls(providerId);
                structures = containers.Map( ...
                    "KeyType", "char", "ValueType", "any");
                identifiers = keys(snls);
                for structureIndex = 1:numel(identifiers)
                    identifier = identifiers{structureIndex};
                    structures(identifier) = snls(identifier).structure;
                end
                allStructures(providerId) = structures;
            end
        end

        function allSnls = get_snls_with_filter(obj, optimadeFilter, ...
                additionalResponseFields)
            if nargin < 3, additionalResponseFields = []; end
            fields = obj.handle_response_fields(additionalResponseFields);
            allSnls = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            providerIds = keys(obj.resources);
            for providerIndex = 1:numel(providerIds)
                providerId = providerIds{providerIndex};
                resource = string(obj.resources(providerId));
                url = appendSlash(resource) + "v1/structures?filter=" + ...
                    string(optimadeFilter) + "&response_fields=" + fields;
                try
                    response = obj.get_json(url);
                    structures = obj.get_snls_from_resource( ...
                        response, url, providerId);
                    while isstruct(response) && isfield(response, "links") && ...
                            isfield(response.links, "next") && ...
                            ~isempty(response.links.next)
                        nextLink = response.links.next;
                        if isstruct(nextLink) && isfield(nextLink, "href")
                            nextLink = nextLink.href;
                        end
                        response = obj.get_json(string(nextLink));
                        additional = obj.get_snls_from_resource( ...
                            response, url, providerId);
                        additionalIds = keys(additional);
                        for index = 1:numel(additionalIds)
                            id = additionalIds{index};
                            structures(id) = additional(id);
                        end
                    end
                    if structures.Count > 0
                        allSnls(providerId) = structures;
                    end
                catch exception
                    warning("KSSOLV:Matgenlab:OptimadeRester:Provider", ...
                        "Could not retrieve provider %s: %s", ...
                        providerId, exception.message);
                end
            end
        end

        function refresh_aliases(obj, providersUrl)
            if nargin < 2 || isempty(providersUrl)
                providersUrl = "https://providers.optimade.org/providers.json";
            end
            registry = obj.get_json(string(providersUrl));
            discovered = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            data = toCell(registry.data);
            for index = 1:numel(data)
                entry = data{index};
                if ~isfield(entry, "attributes") || ...
                        ~isfield(entry.attributes, "base_url") || ...
                        isempty(entry.attributes.base_url)
                    continue
                end
                childProviders = obj.parse_provider( ...
                    string(entry.id), string(entry.attributes.base_url));
                ids = keys(childProviders);
                for childIndex = 1:numel(ids)
                    id = ids{childIndex};
                    discovered(id) = childProviders(id).base_url;
                end
            end
            obj.aliases = discovered;
            obj.ensureAliasSlashes();
        end

        function close(obj)
            obj.closed = true;
            if isobject(obj.transport) && ismethod(obj.transport, "close")
                obj.transport.close();
            end
        end

        function delete(obj)
            obj.close();
        end

        function provider = validate_provider(obj, providerUrl)
            provider = [];
            providerUrl = appendSlash(string(providerUrl));
            if ~isHttpUrl(providerUrl)
                return
            end
            try
                info = obj.get_json(providerUrl + "v1/info");
                metadata = struct();
                if isfield(info, "meta") && isfield(info.meta, "provider")
                    metadata = info.meta.provider;
                end
                provider = kssolv.analysis.matgenlab.ext.optimade.Provider( ...
                    fieldOr(metadata, "name", "Unknown"), providerUrl, ...
                    fieldOr(metadata, "description", "Unknown"), ...
                    fieldOr(metadata, "homepage", ""), ...
                    fieldOr(metadata, "prefix", "Unknown"));
            catch
                provider = [];
            end
        end

        function providers = parse_provider(obj, providerId, providerUrl)
            providers = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            providerUrl = appendSlash(string(providerUrl));
            try
                response = obj.get_json(providerUrl + "v1/links");
                data = toCell(response.data);
                for index = 1:numel(data)
                    link = data{index};
                    attributes = link.attributes;
                    if string(attributes.link_type) ~= "child" || ...
                            ~isfield(attributes, "base_url") || ...
                            isempty(attributes.base_url)
                        continue
                    end
                    linkId = string(link.id);
                    if linkId == string(providerId)
                        key = string(providerId);
                    else
                        key = string(providerId) + "." + linkId;
                    end
                    providers(char(key)) = ...
                        kssolv.analysis.matgenlab.ext.optimade.Provider( ...
                        attributes.name, attributes.base_url, ...
                        attributes.description, ...
                        fieldOr(attributes, "homepage", ""), ...
                        fieldOr(attributes, "prefix", ""));
                end
            catch
                return
            end
        end

        function fields = handle_response_fields(obj, additionalFields)
            extras = normalizeStrings(additionalFields);
            allFields = unique([obj.mandatory_response_fields, extras], ...
                "stable");
            fields = strjoin(allFields, ",");
        end

        function response = get_json(obj, url)
            if isempty(obj.transport)
                error("KSSOLV:Matgenlab:OptimadeRester:TransportRequired", ...
                    "Network access requires an explicit OPTIMADE transport.");
            end
            request = struct("url", string(url), "method", "GET", ...
                "timeout", obj.timeout, ...
                "headers", struct("accept", "application/json"), ...
                "verify", true);
            if isa(obj.transport, "function_handle")
                response = obj.transport(request);
            elseif isobject(obj.transport) && ismethod(obj.transport, "request")
                response = obj.transport.request(request);
            else
                error("KSSOLV:Matgenlab:OptimadeRester:TransportType", ...
                    "transport must be a function handle or request-capable object.");
            end
            if ischar(response) || isstring(response)
                response = jsondecode(char(response));
            elseif isstruct(response) && isfield(response, "status_code")
                if double(response.status_code) < 200 || ...
                        double(response.status_code) >= 300
                    error("KSSOLV:Matgenlab:OptimadeRester:HTTP", ...
                        "OPTIMADE request failed with status %d.", ...
                        double(response.status_code));
                end
                if isfield(response, "json")
                    response = response.json;
                elseif isfield(response, "data") && ...
                        ~(isfield(response, "meta") || isfield(response, "links"))
                    response = response.data;
                elseif isfield(response, "text")
                    response = jsondecode(char(response.text));
                end
            end
            if ~isstruct(response)
                error("KSSOLV:Matgenlab:OptimadeRester:Response", ...
                    "transport must return decoded JSON or a JSON response.");
            end
        end
    end

    methods (Static)
        function filter = build_filter(elements, nelements, nsites, ...
                chemicalFormulaAnonymous, chemicalFormulaHill)
            if nargin < 1, elements = []; end
            if nargin < 2, nelements = []; end
            if nargin < 3, nsites = []; end
            if nargin < 4, chemicalFormulaAnonymous = []; end
            if nargin < 5, chemicalFormulaHill = []; end
            filters = strings(1, 0);
            elements = normalizeStrings(elements);
            if ~isempty(elements)
                quoted = compose('"%s"', elements);
                filters(end + 1) = "(elements HAS ALL " + ...
                    strjoin(quoted, ", ") + ")";
            end
            filters = appendNumericFilter(filters, "nsites", nsites);
            filters = appendNumericFilter(filters, "nelements", nelements);
            if ~isempty(chemicalFormulaAnonymous)
                filters(end + 1) = "(chemical_formula_anonymous='" + ...
                    string(chemicalFormulaAnonymous) + "')";
            end
            if ~isempty(chemicalFormulaHill)
                filters(end + 1) = "(chemical_formula_hill='" + ...
                    string(chemicalFormulaHill) + "')";
            end
            filter = strjoin(filters, " AND ");
        end

        function aliases = default_aliases()
            pairs = {
                "aflow", "https://aflow.org/API/optimade/";
                "alexandria", "https://alexandria.icams.rub.de/pbe";
                "alexandria.pbe", "https://alexandria.icams.rub.de/pbe";
                "alexandria.pbesol", "https://alexandria.icams.rub.de/pbesol";
                "cod", "https://www.crystallography.net/cod/optimade";
                "cmr", "https://cmr-optimade.fysik.dtu.dk";
                "mcloud.mc3d", "https://aiida.materialscloud.org/mc3d/optimade";
                "mcloud.mc2d", "https://aiida.materialscloud.org/mc2d/optimade";
                "mcloud.2dtopo", "https://aiida.materialscloud.org/2dtopo/optimade";
                "mcloud.tc-applicability", "https://aiida.materialscloud.org/tc-applicability/optimade";
                "mcloud.pyrene-mofs", "https://aiida.materialscloud.org/pyrene-mofs/optimade";
                "mcloud.curated-cofs", "https://aiida.materialscloud.org/curated-cofs/optimade";
                "mcloud.stoceriaitf", "https://aiida.materialscloud.org/stoceriaitf/optimade";
                "mcloud.scdm", "https://aiida.materialscloud.org/autowannier/optimade";
                "mcloud.tin-antimony-sulfoiodide", "https://aiida.materialscloud.org/tin-antimony-sulfoiodide/optimade";
                "mcloud.optimade-sample", "https://aiida.materialscloud.org/optimade-sample/optimade";
                "mp", "https://optimade.materialsproject.org";
                "mpdd", "http://mpddoptimade.phaseslab.org";
                "mpds", "https://api.mpds.io";
                "nmd", "https://nomad-lab.eu/prod/rae/optimade/";
                "odbx", "https://optimade.odbx.science";
                "odbx.odbx_misc", "https://optimade-misc.odbx.science";
                "odbx.gnome", "https://optimade-gnome.odbx.science";
                "omdb.omdb_production", "https://optimade.openmaterialsdb.se";
                "oqmd", "https://oqmd.org/optimade/";
                "jarvis", "https://jarvis.nist.gov/optimade/jarvisdft";
                "tcod", "https://www.crystallography.net/tcod/optimade";
                "twodmatpedia", "http://optimade.2dmatpedia.org"};
            aliases = containers.Map(cellstr(pairs(:, 1)), ...
                cellstr(pairs(:, 2)));
        end
    end

    methods (Access = private)
        function ensureAliasSlashes(obj)
            ids = keys(obj.aliases);
            for index = 1:numel(ids)
                obj.aliases(ids{index}) = appendSlash( ...
                    string(obj.aliases(ids{index})));
            end
        end

        function snls = get_snls_from_resource(~, response, url, identifier)
            snls = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            if ~isfield(response, "data"), return, end
            data = toCell(response.data);
            for index = 1:numel(data)
                entry = data{index};
                try
                    attributes = entry.attributes;
                    positions = double(attributes.cartesian_site_positions);
                    species = disorderedSpecies(attributes.species);
                    if numel(species) ~= size(positions, 1)
                        error("KSSOLV:Matgenlab:OptimadeRester:SpeciesCount", ...
                            "OPTIMADE species definitions do not match sites.");
                    end
                    structure = makeStructure(attributes, species);
                catch
                    try
                        attributes = entry.attributes;
                        structure = makeStructure( ...
                            attributes, normalizeSpeciesAtSites( ...
                            attributes.species_at_sites));
                    catch
                        continue
                    end
                end
                namespaced = containers.Map( ...
                    "KeyType", "char", "ValueType", "any");
                names = fieldnames(attributes);
                excluded = [ ...
                    "lattice_vectors", "species", ...
                    "cartesian_site_positions"];
                for nameIndex = 1:numel(names)
                    name = string(names{nameIndex});
                    if startsWith(name, "_") || ~any(name == excluded)
                        namespaced(char(name)) = attributes.(char(name));
                    end
                end
                history = {struct("name", string(identifier), ...
                    "url", string(url), ...
                    "description", struct("id", string(entry.id)))};
                metadata = containers.Map( ...
                    "KeyType", "char", "ValueType", "any");
                metadata("_optimade") = namespaced;
                snl = kssolv.analysis.matgenlab.util.StructureNL( ...
                    structure, {}, {}, "", {}, metadata, history);
                snls(char(string(entry.id))) = snl;
            end
        end
    end
end

function options = parseOptions(values)
options = struct("transport", [], ...
    "aliases", [], ...
    "providers_url", "https://providers.optimade.org/providers.json");
if mod(numel(values), 2) ~= 0
    error("KSSOLV:Matgenlab:OptimadeRester:Arguments", ...
        "Options must be name-value pairs.");
end
for index = 1:2:numel(values)
    name = char(lower(string(values{index})));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:OptimadeRester:Option", ...
            "Unknown option '%s'.", name);
    end
    options.(name) = values{index + 1};
end
end

function values = normalizeStrings(input)
if isempty(input)
    values = strings(1, 0);
elseif ischar(input)
    values = string(input);
elseif isstring(input)
    values = reshape(input, 1, []);
elseif iscell(input)
    values = reshape(string(input), 1, []);
else
    values = reshape(string(input), 1, []);
end
end

function filters = appendNumericFilter(filters, name, value)
if isempty(value), return, end
value = double(value);
if numel(value) > 1
    filters(end + 1) = "(" + name + ">=" + min(value) + ...
        " AND " + name + "<=" + max(value) + ")";
else
    filters(end + 1) = "(" + name + "=" + value + ")";
end
end

function value = appendSlash(value)
value = string(value);
if ~endsWith(value, "/"), value = value + "/"; end
end

function tf = isHttpUrl(value)
tf = ~isempty(regexp(char(value), '^https?://[^/]+', "once"));
end

function value = fieldOr(data, name, fallback)
if isstruct(data) && isfield(data, name) && ~isempty(data.(name))
    value = data.(name);
else
    value = fallback;
end
end

function values = toCell(value)
if isempty(value)
    values = cell(1, 0);
elseif iscell(value)
    values = reshape(value, 1, []);
elseif isstruct(value)
    values = num2cell(reshape(value, 1, []));
else
    values = {value};
end
end

function species = disorderedSpecies(definitions)
definitions = toCell(definitions);
species = cell(1, numel(definitions));
for index = 1:numel(definitions)
    definition = definitions{index};
    symbols = normalizeStrings(definition.chemical_symbols);
    concentrations = reshape(double(definition.concentration), 1, []);
    if numel(symbols) ~= numel(concentrations)
        error("KSSOLV:Matgenlab:OptimadeRester:Concentration", ...
            "chemical_symbols and concentration lengths differ.");
    end
    mapping = cell(numel(symbols), 2);
    for symbolIndex = 1:numel(symbols)
        symbol = symbols(symbolIndex);
        if symbol == "vacancy"
            value = kssolv.analysis.matgenlab.core.DummySpecies( ...
                "X_vacancy", []);
        elseif symbol == "X"
            value = kssolv.analysis.matgenlab.core.DummySpecies("X", []);
        else
            value = symbol;
        end
        mapping{symbolIndex, 1} = value;
        mapping{symbolIndex, 2} = concentrations(symbolIndex);
    end
    species{index} = mapping;
end
end

function species = normalizeSpeciesAtSites(value)
species = num2cell(reshape(string(value), 1, []));
for index = 1:numel(species)
    if string(species{index}) == "vacancy"
        species{index} = ...
            kssolv.analysis.matgenlab.core.DummySpecies("X_vacancy", []);
    elseif string(species{index}) == "X"
        species{index} = ...
            kssolv.analysis.matgenlab.core.DummySpecies("X", []);
    end
end
end

function structure = makeStructure(attributes, species)
structure = kssolv.analysis.matgenlab.core.Structure( ...
    double(attributes.lattice_vectors), species, ...
    double(attributes.cartesian_site_positions), ...
    coords_are_cartesian = true);
end
