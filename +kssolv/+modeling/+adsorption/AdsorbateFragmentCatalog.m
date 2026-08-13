classdef AdsorbateFragmentCatalog
    %ADSORBATEFRAGMENTCATALOG Serialize user fragments for direct 3-D placement.

    properties (Constant)
        SchemaVersion = 1
    end

    methods (Static)
        function payload = userFragments(options)
            arguments
                options.StorePath {mustBeTextScalar} = ""
            end
            entries = kssolv.modeling.fragments.FragmentLibrary.list( ...
                "", includeUser = true, storePath = options.StorePath);
            entries = entries(arrayfun(@(entry) ...
                string(entry.source) == "user", entries));
            payload = emptyPayload();
            for entry = reshape(entries, 1, [])
                ports = entry.ports;
                ports = ports(arrayfun(@(port) ...
                    ~isempty(port.headIndices), ports));
                for port = reshape(ports, 1, [])
                    item = struct( ...
                        "id", "user-" + slug(entry.name) + "-" + ...
                            slug(port.id), ...
                        "label", string(entry.name) + " · " + ...
                            string(port.label), ...
                        "formula", formula(entry.species), ...
                        "species", reshape(string(entry.species), 1, []), ...
                        "coordinates", double(entry.coordinates), ...
                        "bonds", zeroBasedBonds(entry.bonds), ...
                        "anchorAtomIndex", double(port.headIndices(1) - 1), ...
                        "orientation", normalizedOrientation(port.orientation), ...
                        "defaultHostBondLength", 2, ...
                        "source", "user", ...
                        "fragmentName", string(entry.name), ...
                        "portId", string(port.id), ...
                        "schemaVersion", ...
                            kssolv.modeling.adsorption. ...
                            AdsorbateFragmentCatalog.SchemaVersion);
                    payload(end + 1, 1) = item; %#ok<AGROW>
                end
            end
        end
    end
end

function payload = emptyPayload()
payload = struct("id", {}, "label", {}, "formula", {}, ...
    "species", {}, "coordinates", {}, "bonds", {}, ...
    "anchorAtomIndex", {}, "orientation", {}, ...
    "defaultHostBondLength", {}, "source", {}, ...
    "fragmentName", {}, "portId", {}, "schemaVersion", {});
end

function value = slug(input)
value = lower(regexprep(string(input), "[^A-Za-z0-9]+", "-"));
value = strip(value, "-");
if value == "", value = "fragment"; end
end

function value = formula(species)
species = reshape(string(species), 1, []);
symbols = unique(species, "stable");
terms = strings(size(symbols));
for index = 1:numel(symbols)
    count = sum(species == symbols(index));
    terms(index) = symbols(index);
    if count > 1, terms(index) = terms(index) + string(count); end
end
value = join(terms, "");
end

function bonds = zeroBasedBonds(input)
bonds = reshape(double(input), [], 3);
if ~isempty(bonds), bonds(:, 1:2) = bonds(:, 1:2) - 1; end
end

function value = normalizedOrientation(input)
value = reshape(double(input), 1, 3);
if any(~isfinite(value)) || norm(value) <= 1e-12
    value = [0, 0, 1];
else
    value = value / norm(value);
end
end
