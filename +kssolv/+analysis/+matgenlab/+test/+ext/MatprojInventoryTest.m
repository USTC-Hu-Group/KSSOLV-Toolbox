classdef MatprojInventoryTest < matlab.unittest.TestCase
    %MATPROJINVENTORYTEST Frozen, network-free ext.matproj parity checks.

    properties (Constant)
        Key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    end

    methods (Test)
        function constructorAndEndpointParity(testCase)
            import kssolv.analysis.matgenlab.ext.matproj.MPRester
            transport = fixtureTransport();
            rester = MPRester(testCase.Key, false, ...
                "transport", transport);
            testCase.verifyEqual(rester.api_key, testCase.Key);
            testCase.verifyEqual(rester.preamble, ...
                "https://api.materialsproject.org/");
            testCase.verifyEqual(string(fieldnames(rester.session.headers)), ...
                "x_api_key");
            oracle = loadOracle();
            testCase.verifyEqual(MPRester.MATERIALS_DOCS, ...
                reshape(string(oracle.materials_docs), 1, []));
            for name = MPRester.MATERIALS_DOCS
                direct = rester.(char(name));
                nested = rester.materials.(char(name));
                testCase.verifyClass(direct, ...
                    "kssolv.analysis.matgenlab.ext.matproj.MPDocumentEndpoint");
                testCase.verifyEqual(direct.document, name);
                testCase.verifyEqual(nested.document, name);
            end
            testCase.verifyError(@() MPRester("short"), ...
                "KSSOLV:Matgenlab:MPRester:InvalidApiKey");
            rester.close();
            testCase.verifyTrue(rester.session.closed);
        end

        function searchAndConvenienceRequestParity(testCase)
            import kssolv.analysis.matgenlab.ext.matproj.MPRester
            transport = fixtureTransport();
            structure = simpleStructure();
            transport.Callback = @(request) contractResponse( ...
                request, structure);
            rester = MPRester(testCase.Key, false, ...
                "transport", transport);

            rester.search("summary", "material_ids", ["mp-1", "mp-2"], ...
                "nsites", "1,4", "_fields", ...
                ["material_id", "formula_pretty"]);
            rester.summary_search("formula", "Fe2O3");
            rester.get_summary(struct("formula", "Fe2O3"));
            rester.get_summary(struct("formula", "Al2O3"), "material_id");
            rester.get_summary_by_material_id("mp-19770", ...
                "formula_pretty");
            ids = rester.get_material_ids("Al2O3");
            testCase.verifyEqual(ids, "mp-1143");
            final = rester.get_structures("Mn3O4");
            initial = rester.get_structures("Li-Fe-O", false);
            testCase.verifyEqual(final{1}, structure);
            testCase.verifyEqual(initial{1}, structure);
            testCase.verifyEqual( ...
                rester.get_structure_by_material_id("mp-1"), structure);
            initials = rester.get_initial_structures_by_material_id("mp-1");
            testCase.verifyEqual(numel(initials), 2);

            oracle = loadOracle();
            expected = oracle.method_calls(1:10);
            testCase.verifyEqual(numel(transport.Requests), numel(expected));
            for index = 1:numel(expected)
                request = transport.Requests{index};
                expectedUrl = "https://api.materialsproject.org/" + ...
                    string(expected(index).sub_url) + ...
                    "&_per_page=1000&_page=1";
                testCase.verifyEqual(request.url, expectedUrl);
                testCase.verifyEqual(request.method, ...
                    string(expected(index).method));
                testCase.verifyEqual(request.timeout, ...
                    double(expected(index).timeout));
                verifyPayload(testCase, request.payload, ...
                    expected(index).payload);
            end

            aliasDoc = rester.get_doc("mp-19770", "formula_pretty");
            testCase.verifyEqual(aliasDoc.material_id, "mp-19770");
            aliasIds = rester.get_materials_ids("Al2O3");
            testCase.verifyEqual(aliasIds, "mp-1143");
            direct = rester.summary.search("formula", "Fe2O3");
            nested = rester.materials.summary.search( ...
                "formula", "Fe2O3");
            testCase.verifyEqual(direct, nested);
        end

        function paginationFallbackDecodeAndErrors(testCase)
            import kssolv.analysis.matgenlab.ext.matproj.MPRester
            first = arrayfun(@(index) struct("index", index), ...
                0:999, "UniformOutput", false);
            second = {struct("index", 1000), struct("index", 1001)};
            transport = fixtureTransport({response(first), response(second)});
            rester = MPRester(testCase.Key, false, ...
                "transport", transport);
            docs = rester.request( ...
                "materials/summary/?_all_fields=True", ...
                struct("formula", "Fe"));
            testCase.verifyNumElements(docs, 1002);
            oracle = loadOracle();
            calls = oracle.pagination.paged_calls;
            for index = 1:2
                testCase.verifyEqual(transport.Requests{index}.url, ...
                    string(calls(index).url));
                testCase.verifyEqual( ...
                    transport.Requests{index}.payload.formula, "Fe");
            end

            detail = struct("detail", ...
                "Extra inputs are not permitted: _per_page and _page");
            retry = fixtureTransport({rawResponse(400, detail), ...
                response({struct("material_id", "mp-13")})});
            rester = MPRester(testCase.Key, false, "transport", retry);
            docs = rester.request("materials/core/?_all_fields=True");
            testCase.verifyEqual(docs{1}.material_id, "mp-13");
            retryCalls = oracle.pagination.retry_calls;
            testCase.verifyEqual(retry.Requests{1}.url, ...
                string(retryCalls(1).url));
            testCase.verifyEqual(retry.Requests{2}.url, ...
                string(retryCalls(2).url));

            bad = fixtureTransport({rawResponse(503, ...
                struct("detail", "down"))});
            rester = MPRester(testCase.Key, false, "transport", bad);
            testCase.verifyError(@() rester.request( ...
                "materials/core/?_all_fields=True"), ...
                "KSSOLV:Matgenlab:MPRestError");
            try
                rester.request("materials/core/?_all_fields=True");
            catch exception
                testCase.verifyEqual(string(exception.message), ...
                    string(oracle.pagination.error));
            end

            structure = simpleStructure();
            envelope = struct("data", ...
                {{struct("structure", structure.as_dict())}});
            textTransport = fixtureTransport({struct( ...
                "status_code", 200, "text", jsonencode(envelope))});
            rester = MPRester(testCase.Key, false, ...
                "transport", textTransport);
            decoded = rester.request("materials/summary/?x=1");
            testCase.verifyClass(decoded{1}.structure, ...
                "kssolv.analysis.matgenlab.core.Structure");
        end

        function entriesAndChemsysParity(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.ext.matproj.MPRester
            first = ComputedEntry("Fe", -1, ...
                "data", struct("material_id", "mp-13"), ...
                "entry_id", "task-1");
            second = ComputedEntry("LiFeO2", -10, ...
                "data", struct("material_id", "mp-100"), ...
                "entry_id", "task-2");
            entryMap = containers.Map("KeyType", "char", ...
                "ValueType", "any");
            entryMap("task-1") = first;
            entryMap("task-2") = second;
            thermo = struct("entries", entryMap, ...
                "formation_energy_per_atom", -0.25);
            summaries = { ...
                struct("material_id", "mp-13", "band_gap", 0.0), ...
                struct("material_id", "mp-100", "band_gap", 1.5)};
            transport = fixtureTransport( ...
                {response({thermo}), response(summaries)});
            rester = MPRester(testCase.Key, false, ...
                "transport", transport);
            entries = rester.get_entries("Li-Fe-O", ...
                "compatible_only", false, ...
                "property_data", "formation_energy_per_atom", ...
                "summary_data", "band_gap");
            testCase.verifyNumElements(entries, 2);
            testCase.verifyEqual( ...
                entries{1}.data.formation_energy_per_atom, -0.25);
            testCase.verifyTrue(isfield(entries{2}.data, "summary"));
            testCase.verifyEqual(entries{2}.data.summary.band_gap, 1.5);
            testCase.verifyEqual(transport.Requests{1}.url, ...
                "https://api.materialsproject.org/" + ...
                "materials/thermo/?_fields=entries," + ...
                "formation_energy_per_atom&chemsys=Fe-Li-O" + ...
                "&_per_page=1000&_page=1");
            testCase.verifyEqual(transport.Requests{2}.url, ...
                "https://api.materialsproject.org/" + ...
                "materials/summary/?_fields=band_gap,material_id" + ...
                "&_all_fields=False&_per_page=1000&_page=1");
            testCase.verifyEqual( ...
                transport.Requests{2}.payload.material_ids, ...
                "mp-13,mp-100");

            emptyTransport = fixtureTransport();
            rester = MPRester(testCase.Key, false, ...
                "transport", emptyTransport);
            rester.get_entries(["Fe2O3", "Li-Fe-O"], ...
                "compatible_only", false);
            rester.get_entries_in_chemsys(["Li", "Fe", "O"], ...
                "compatible_only", false);
            oracle = loadOracle();
            testCase.verifyEqual(emptyTransport.Requests{1}.url, ...
                "https://api.materialsproject.org/" + ...
                string(oracle.method_calls(12).sub_url) + ...
                "&_per_page=1000&_page=1");
            testCase.verifyEqual(emptyTransport.Requests{2}.url, ...
                "https://api.materialsproject.org/" + ...
                string(oracle.method_calls(13).sub_url) + ...
                "&_per_page=1000&_page=1");
            testCase.verifyError(@() rester.get_entry_by_material_id( ...
                "mp-does-not-exist", "compatible_only", false), ...
                "KSSOLV:Matgenlab:MPRester:IndexError");
            testCase.verifyWarning(@() rester.get_entries("Li", ...
                "compatible_only", false, "inc_structure", true), ...
                "KSSOLV:Matgenlab:MPRester:Deprecated");
        end

        function compatibilityAndPhononParity(testCase)
            import kssolv.analysis.matgenlab.core.ComputedEntry
            import kssolv.analysis.matgenlab.ext.matproj.MPRester
            entry = ComputedEntry("Fe", -1, ...
                "data", struct("material_id", "mp-13"), ...
                "entry_id", "task-1");
            entryMap = containers.Map("task-1", entry);
            thermo = struct("entries", entryMap);
            transport = fixtureTransport({response({thermo})});
            processor = @(entries) entries;
            rester = MPRester(testCase.Key, false, ...
                "transport", transport, ...
                "compatibility_processor", processor);
            processed = rester.get_entries("Fe");
            testCase.verifyEqual(processed{1}.entry_id, "task-1");

            structure = simpleStructure();
            bandData = struct( ...
                "reciprocal_lattice", eye(3), ...
                "qpoints", [0, 0, 0; 0.5, 0, 0], ...
                "frequencies", [1, 2; 3, 4; 5, 6], ...
                "has_nac", false, ...
                "eigendisplacements", {nestedEigenStrings()}, ...
                "structure", structure, ...
                "labels_dict", struct("x_Gamma", [0, 0, 0]));
            dosData = struct( ...
                "structure", structure.as_dict(), ...
                "frequencies", [0, 1, 2], ...
                "densities", [1, 2, 1], ...
                "projected_densities", [1, 2, 1]);
            s3 = fixtureTransport({dataResponse(bandData), ...
                dataResponse(dosData)});
            rester = MPRester(testCase.Key, false, ...
                "transport", fixtureTransport(), "s3_transport", s3);
            band = rester.get_phonon_bandstructure_by_material_id("mp-661");
            dos = rester.get_phonon_dos_by_material_id("mp-661");
            testCase.verifyClass(band, ...
                "kssolv.analysis.matgenlab.phonon." + ...
                "PhononBandStructureSymmLine");
            testCase.verifyEqual(band.bands, bandData.frequencies);
            testCase.verifySize(band.eigendisplacements, [3, 2, 1, 3]);
            testCase.verifyEqual(band.eigendisplacements(3, 2, 1, 1), ...
                complex(3, -2));
            testCase.verifyTrue(isKey(band.labels_dict, "\Gamma"));
            testCase.verifyClass(dos, ...
                "kssolv.analysis.matgenlab.phonon.CompletePhononDos");
            testCase.verifyEqual(dos.densities, [1; 2; 1]);
            testCase.verifyEqual(s3.Requests{1}.url, ...
                "https://s3.us-east-1.amazonaws.com/" + ...
                "materialsproject-parsed/ph-bandstructures/dfpt/" + ...
                "mp-661.json.gz");
            oracle = loadOracle();
            testCase.verifyEqual(s3.Requests{2}.url, ...
                string(oracle.s3.calls.url));
        end
    end
end

function transport = fixtureTransport(responses)
if nargin < 1, responses = cell(1, 0); end
transport = kssolv.analysis.matgenlab.test.ext.fixtures. ...
    MatprojMockTransport(responses);
end

function value = response(docs)
envelope = struct();
envelope.data = docs;
value = struct("status_code", 200, "data", envelope);
end

function value = rawResponse(status, data)
value = struct("status_code", status, "data", data, ...
    "text", jsonencode(data));
end

function value = dataResponse(data)
value = struct("status_code", 200, "data", data);
end

function value = contractResponse(request, structure)
url = string(request.url);
if contains(url, "_fields=initial_structures")
    docs = {struct("initial_structures", {{structure, structure}})};
elseif contains(url, "_fields=initial_structure")
    docs = {struct("initial_structure", structure)};
elseif contains(url, "_fields=structure")
    docs = {struct("structure", structure)};
elseif isstruct(request.payload) && ...
        isfield(request.payload, "material_ids")
    docs = {struct("material_id", request.payload.material_ids)};
elseif isstruct(request.payload) && isfield(request.payload, "formula") && ...
        string(request.payload.formula) == "Al2O3"
    docs = {struct("material_id", "mp-1143")};
else
    docs = cell(1, 0);
end
value = response(docs);
end

function value = simpleStructure()
value = kssolv.analysis.matgenlab.core.Structure( ...
    eye(3) * 4, {"Cs"}, [0, 0, 0]);
end

function value = nestedEigenStrings()
value = cell(3, 1);
for mode = 1:3
    value{mode} = cell(2, 1);
    for point = 1:2
        value{mode}{point} = cell(1, 1);
        value{mode}{point}{1} = { ...
            "(" + mode + "-" + point + "j)"; "(0+0j)"; "(0+0j)"};
    end
end
end

function value = loadOracle()
here = fileparts(mfilename("fullpath"));
root = fileparts(fileparts(fileparts(fileparts(fileparts(here)))));
value = jsondecode(fileread(fullfile(root, "dev", "matgenlab", ...
    "oracles", "ext_matproj_2026.5.4.json")));
end

function verifyPayload(testCase, actual, expected)
if isempty(expected)
    testCase.verifyEmpty(actual);
    return
end
names = fieldnames(expected);
testCase.verifyEqual(string(fieldnames(actual)), string(names));
for index = 1:numel(names)
    testCase.verifyEqual(string(actual.(names{index})), ...
        string(expected.(names{index})));
end
end
