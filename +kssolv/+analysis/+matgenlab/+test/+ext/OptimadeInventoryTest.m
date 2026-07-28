classdef OptimadeInventoryTest < matlab.unittest.TestCase
    %OPTIMADEINVENTORYTEST Frozen, network-free ext.optimade parity checks.

    methods (Test)
        function filterAndProviderParity(testCase)
            import kssolv.analysis.matgenlab.ext.optimade.OptimadeRester
            import kssolv.analysis.matgenlab.ext.optimade.Provider
            oracle = loadOracle();
            first = OptimadeRester.build_filter( ...
                ["Ga", "N"], 2, [1, 100], "A2B", "GaN");
            second = OptimadeRester.build_filter( ...
                ["C", "H", "O"], [3, 4], [1, 100], ...
                "A4B3C", "C4H3O");
            testCase.verifyEqual(first, string(oracle.filters(1)));
            testCase.verifyEqual(second, string(oracle.filters(2)));
            testCase.verifyEqual( ...
                sort(OptimadeRester.mandatory_response_fields), ...
                reshape(string(oracle.mandatory_response_fields), 1, []));

            provider = Provider("Fixture", "https://fixture.test/", ...
                "Offline", "https://fixture.test/home", "fx");
            expected = "Provider(name='Fixture', " + ...
                "base_url='https://fixture.test/', " + ...
                "description='Offline', " + ...
                "homepage='https://fixture.test/home', prefix='fx')";
            testCase.verifyEqual(provider.name, "Fixture");
            testCase.verifyEqual(provider.base_url, "https://fixture.test/");
            testCase.verifyEqual(string(provider), expected);
            testCase.verifyEqual(string(oracle.provider_repr), expected);
        end

        function constructorDescribeAndSafeTransport(testCase)
            import kssolv.analysis.matgenlab.ext.optimade.OptimadeRester
            transport = mockTransport();
            rester = OptimadeRester("fixture", false, 7, ...
                "transport", transport, "aliases", fixtureAliases());
            testCase.verifyTrue(isKey(rester.resources, "fixture"));
            testCase.verifyEqual( ...
                string(rester.resources("fixture")), ...
                "https://fixture.test/");
            testCase.verifyEqual(transport.Requests{1}.url, ...
                "https://fixture.test/v1/info");
            testCase.verifyEqual(transport.Requests{1}.timeout, 7);
            testCase.verifyTrue(transport.Requests{1}.verify);
            description = rester.describe();
            testCase.verifySubstring(description, "Fixture");
            testCase.verifySubstring(string(rester), ...
                "https://fixture.test/");
            rester.close();
            testCase.verifyTrue(rester.closed);
            testCase.verifyTrue(transport.closed);

            noTransport = OptimadeRester("mp");
            testCase.verifyError(@() noTransport.get_json( ...
                "https://fixture.test/v1/info"), ...
                "KSSOLV:Matgenlab:OptimadeRester:TransportRequired");
            invalid = OptimadeRester("not a url", false, 5, ...
                "transport", transport);
            testCase.verifyEqual(double(invalid.resources.Count), 0);
        end

        function snlParsingPaginationAndMetadata(testCase)
            import kssolv.analysis.matgenlab.ext.optimade.OptimadeRester
            oracle = loadOracle();
            transport = mockTransport();
            rester = OptimadeRester("fixture", false, 5, ...
                "transport", transport, "aliases", fixtureAliases());
            allSnls = rester.get_snls_with_filter( ...
                'elements HAS ALL "Na", "Cl"', ["nsites", "nelements"]);
            testCase.verifyTrue(isKey(allSnls, "fixture"));
            snls = allSnls("fixture");
            testCase.verifyEqual(sort(string(keys(snls))), ...
                ["disordered-1", "ordered-2", "paged-3"]);

            first = snls("disordered-1");
            testCase.verifyEqual(first.structure.num_sites, 2);
            testCase.verifyEqual(first.structure.cart_coords, ...
                double(oracle.parsed.disordered_1.cart_coords), ...
                "AbsTol", 1e-12);
            testCase.verifyTrue(isKey(first.data, "_optimade"));
            optimadeData = first.data("_optimade");
            testCase.verifyEqual(optimadeData("nelements"), 2);
            testCase.verifyEqual( ...
                string(optimadeData("demo_quality")), "frozen");
            testCase.verifyEqual(first.history{1}.name, "fixture");
            testCase.verifyEqual(first.history{1}.description.id, ...
                "disordered-1");
            species = first.structure.sites{1}.species;
            [speciesValues, occupancies] = species.items();
            testCase.verifyEqual(occupancies, [0.75, 0.25], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(string(speciesValues{1}), "Na");
            testCase.verifyEqual(speciesValues{2}.symbol, "X_vacancy");

            second = snls("ordered-2");
            testCase.verifyEqual(second.structure.num_sites, 3);
            testCase.verifyEqual(second.structure.cart_coords, ...
                double(oracle.parsed.ordered_2.cart_coords), ...
                "AbsTol", 1e-12);
            testCase.verifyEqual( ...
                string(second.structure.sites{3}.specie), "Na");

            queryRequest = transport.Requests{2};
            testCase.verifySubstring(queryRequest.url, ...
                "filter=elements HAS ALL");
            for field = OptimadeRester.mandatory_response_fields
                testCase.verifySubstring(queryRequest.url, field);
            end
            testCase.verifySubstring(queryRequest.url, "nsites");
            testCase.verifySubstring(queryRequest.url, "nelements");
            testCase.verifyEqual(transport.Requests{3}.url, ...
                "https://fixture.test/page/2");
        end

        function convenienceStructuresAndResponseFields(testCase)
            import kssolv.analysis.matgenlab.ext.optimade.OptimadeRester
            transport = mockTransport();
            rester = OptimadeRester("fixture", false, 5, ...
                "transport", transport, "aliases", fixtureAliases());
            structures = rester.get_structures( ...
                ["Na", "Cl"], 2, [1, 4], [], []);
            testCase.verifyTrue(isKey(structures, "fixture"));
            providerStructures = structures("fixture");
            testCase.verifyClass(providerStructures("ordered-2"), ...
                "kssolv.analysis.matgenlab.core.Structure");
            testCase.verifySubstring(transport.Requests{2}.url, ...
                '(elements HAS ALL "Na", "Cl")');
            testCase.verifySubstring(transport.Requests{2}.url, ...
                "(nsites>=1 AND nsites<=4)");
            testCase.verifySubstring(transport.Requests{2}.url, ...
                "(nelements=2)");

            fields = rester.handle_response_fields( ...
                ["nsites", "species", "nsites"]);
            splitFields = sort(split(fields, ","));
            testCase.verifyEqual(splitFields, sort([ ...
                "lattice_vectors"; "cartesian_site_positions"; ...
                "species"; "species_at_sites"; "nsites"]));
        end

        function aliasRefreshAndChildProviderParity(testCase)
            import kssolv.analysis.matgenlab.ext.optimade.OptimadeRester
            transport = mockTransport();
            rester = OptimadeRester("fixture", false, 5, ...
                "transport", transport, "aliases", fixtureAliases());
            rester.refresh_aliases("https://registry.test/providers.json");
            testCase.verifyEqual(double(rester.aliases.Count), 2);
            testCase.verifyEqual(string(rester.aliases("fx")), ...
                "https://fixture.test/");
            testCase.verifyEqual(string(rester.aliases("fx.child")), ...
                "https://child.fixture.test/api/");
            requestUrls = string(cellfun(@(item) item.url, ...
                transport.Requests, "UniformOutput", false));
            testCase.verifyTrue(any(requestUrls == ...
                "https://registry.test/providers.json"));
            testCase.verifyTrue(any(requestUrls == ...
                "https://index.fixture.test/v1/links"));
        end

        function providerFailureIsolation(testCase)
            import kssolv.analysis.matgenlab.ext.optimade.OptimadeRester
            transport = mockTransport();
            rester = OptimadeRester(["fixture", "bad"], false, 5, ...
                "transport", transport, "aliases", fixtureAliases());
            testCase.verifyTrue(isKey(rester.resources, "fixture"));
            testCase.verifyTrue(isKey(rester.resources, "bad"));
            testCase.verifyEmpty(rester.providers("https://bad.test/"));
            failing = kssolv.analysis.matgenlab.test.ext.fixtures. ...
                OptimadeMockTransport(@alwaysFail);
            direct = OptimadeRester("https://down.test", false, 5, ...
                "transport", failing);
            testCase.verifyEqual(double(direct.resources.Count), 0);
        end
    end
end

function oracle = loadOracle()
root = fileparts(fileparts(fileparts(fileparts( ...
    fileparts(fileparts(mfilename("fullpath")))))));
oracle = jsondecode(fileread(fullfile(root, "dev", "matgenlab", ...
    "oracles", "optimade_2026.5.4.json")));
end

function transport = mockTransport()
import kssolv.analysis.matgenlab.test.ext.fixtures.OptimadeMockTransport
transport = OptimadeMockTransport(@respond);
end

function aliases = fixtureAliases()
aliases = containers.Map( ...
    {'fixture', 'bad'}, ...
    {'https://fixture.test', 'https://bad.test'});
end

function response = respond(request)
url = string(request.url);
oracle = loadOracle();
if endsWith(url, "/v1/info")
    if contains(url, "bad")
        error("KSSOLV:Matgenlab:OptimadeMock:Down", "Provider is down.");
    end
    response = struct("meta", struct("provider", struct( ...
        "name", "Fixture", "description", "Offline", ...
        "homepage", "https://fixture.test/home", "prefix", "fx")));
elseif contains(url, "/v1/structures?")
    response = oracle.resource;
    response.links.next = struct("href", "https://fixture.test/page/2");
elseif url == "https://fixture.test/page/2"
    attributes = oracle.resource.data(2).attributes;
    entry = struct("id", "paged-3", "type", "structures", ...
        "attributes", attributes);
    response = struct("meta", struct("data_returned", 1), ...
        "links", struct("next", []), "data", entry);
elseif url == "https://registry.test/providers.json"
    attributes = struct("base_url", "https://index.fixture.test");
    response = struct("data", struct("id", "fx", ...
        "attributes", attributes));
elseif url == "https://index.fixture.test/v1/links"
    parent = struct("id", "fx", "attributes", struct( ...
        "link_type", "child", "base_url", "https://fixture.test", ...
        "name", "Fixture", "description", "Primary", ...
        "homepage", "https://fixture.test", "prefix", "fx"));
    child = struct("id", "child", "attributes", struct( ...
        "link_type", "child", ...
        "base_url", "https://child.fixture.test/api", ...
        "name", "Child", "description", "Secondary", ...
        "homepage", "https://child.fixture.test", "prefix", "fx"));
    response = struct("data", [parent, child]);
else
    error("KSSOLV:Matgenlab:OptimadeMock:Unknown", ...
        "Unknown fixture URL: %s", url);
end
end

function response = alwaysFail(~)
response = struct(); %#ok<NASGU>
error("KSSOLV:Matgenlab:OptimadeMock:Down", "Provider is down.");
end
