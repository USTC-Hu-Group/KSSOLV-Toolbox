classdef MPRester < handle
    %MPRESTER Native MATLAB client mirroring pymatgen.ext.matproj.MPRester.
    %
    % Network access is isolated behind injectable REST and S3 transports.
    % A transport accepts one request struct and returns a response struct
    % with status_code plus text/content fields. This makes the complete
    % request contract deterministic and testable without credentials.
    %
    % Example (compatible with the official mp-api summary search):
    %   mpr = kssolv.analysis.matgenlab.ext.matproj.MPRester();
    %   docs = mpr.summary_search("elements", ["Li", "Fe", "O"], ...
    %       "_fields", ["material_id", "formula_pretty"]);
    %   structure = mpr.get_structure_by_material_id("mp-19017");
    %
    % Configure credentials in KSSOLV settings or through the MP_API_KEY,
    % PMG_MAPI_KEY, or MAPI_KEY environment variables.

    properties (Constant)
        MATERIALS_DOCS = [ ...
            "summary", "core", "elasticity", "phonon", "eos", ...
            "similarity", "xas", "grain_boundaries", ...
            "electronic_structure", "tasks", "substrates", ...
            "surface_properties", "robocrys", "synthesis", ...
            "magnetism", "insertion_electrodes", ...
            "conversion_electrodes", "oxidation_states", ...
            "provenance", "alloys", "absorption", "chemenv", ...
            "bonds", "piezoelectric", "dielectric"]
        CHUNK_SIZE = 200
    end

    properties (SetAccess = private)
        api_key (1,1) string
        preamble (1,1) string
        session (1,1) struct
        materials
        summary
        core
        elasticity
        phonon
        eos
        similarity
        xas
        grain_boundaries
        electronic_structure
        tasks
        substrates
        surface_properties
        robocrys
        synthesis
        magnetism
        insertion_electrodes
        conversion_electrodes
        oxidation_states
        provenance
        alloys
        absorption
        chemenv
        bonds
        piezoelectric
        dielectric
    end

    properties (Access = private)
        transport
        s3_transport
        compatibility_processor
    end

    methods
        function obj = MPRester(apiKey, includeUserAgent, varargin)
            if nargin < 1 || isempty(apiKey)
                apiKey = kssolv.analysis.matgenlab.ext.matproj. ...
                    MPRester.default_api_key();
            end
            if nargin < 2 || isempty(includeUserAgent)
                includeUserAgent = true;
            end
            options = struct("transport", [], "s3_transport", [], ...
                "preamble", kssolv.analysis.matgenlab.core.Settings.get( ...
                "PMG_MAPI_ENDPOINT", "https://api.materialsproject.org/"), ...
                "compatibility_processor", []);
            options = parseOptions(options, varargin);

            obj.api_key = string(apiKey);
            if strlength(obj.api_key) ~= 32
                error("KSSOLV:Matgenlab:MPRester:InvalidApiKey", ...
                    "Invalid or old API key. Please obtain an updated " + ...
                    "API key at https://materialsproject.org/dashboard.");
            end
            obj.preamble = string(options.preamble);
            headers = struct("x_api_key", obj.api_key);
            if logical(includeUserAgent)
                release = string(version("-release"));
                headers.user_agent = "matgenlab/MATLAB-" + release + ...
                    " (" + string(computer) + ")";
            end
            obj.session = struct("headers", headers, "closed", false);
            obj.transport = options.transport;
            obj.s3_transport = options.s3_transport;
            obj.compatibility_processor = options.compatibility_processor;

            obj.materials = kssolv.analysis.matgenlab.ext.matproj. ...
                MPMaterials(obj);
            names = obj.MATERIALS_DOCS;
            for index = 1:numel(names)
                name = char(names(index));
                obj.(name) = kssolv.analysis.matgenlab.ext.matproj. ...
                    MPDocumentEndpoint(obj, names(index));
            end
        end

        function close(obj)
            obj.session.closed = true;
        end

        function delete(obj)
            obj.close();
        end

        function [allData, metadata] = request(obj, subUrl, payload, method, ...
                mpDecode, timeout)
            if nargin < 3, payload = []; end
            if nargin < 4 || isempty(method), method = "GET"; end
            if nargin < 5 || isempty(mpDecode), mpDecode = true; end
            if nargin < 6 || isempty(timeout), timeout = 60; end
            url = obj.preamble + string(subUrl);
            perPage = 1000;
            page = 1;
            allData = cell(1, 0);
            metadata = struct();
            paginationDisabled = ~isempty(regexp(url, ...
                "[?&]_(?:limit|skip|page|per_page)=", "once"));
            while true
                if paginationDisabled
                    actualUrl = url;
                else
                    actualUrl = appendQuery(url, "_per_page", perPage);
                    actualUrl = appendQuery(actualUrl, "_page", page);
                end
                requestData = struct( ...
                    "url", actualUrl, ...
                    "method", upper(string(method)), ...
                    "payload", payload, ...
                    "headers", obj.session.headers, ...
                    "verify", true, ...
                    "timeout", double(timeout));
                try
                    response = obj.invokeTransport(requestData, false);
                    status = responseStatus(response);
                    if ~any(status == [200, 400])
                        detail = "";
                        if any(status == [401, 403])
                            detail = strip(responseText(response));
                        end
                        errorMessage = "REST query returned with error " + ...
                            "status code " + status;
                        if detail ~= ""
                            errorMessage = errorMessage + ". " + detail;
                        end
                        obj.raiseRest(errorMessage);
                    end
                    data = decodeResponse(response, logical(mpDecode));
                    detail = fieldOr(data, "detail", []);
                    if ~paginationDisabled && status == 400 && ...
                            (ischar(detail) || isstring(detail)) && ...
                            contains(string(detail), "_per_page") && ...
                            contains(string(detail), "_page")
                        paginationDisabled = true;
                        page = 1;
                        allData = cell(1, 0);
                        metadata = struct();
                        continue
                    end
                    if ~isstruct(data) || ~isfield(data, "data")
                        obj.raiseRest(responseText(response));
                    end
                    batch = toCell(data.data);
                    if isempty(fieldnames(metadata)) && isfield(data, "meta")
                        metadata = data.meta;
                    end
                    allData = [allData, reshape(batch, 1, [])]; %#ok<AGROW>
                    if paginationDisabled || numel(batch) < perPage
                        break
                    end
                    page = page + 1;
                catch exception
                    if exception.identifier == "KSSOLV:Matgenlab:MPRestError"
                        rethrow(exception);
                    end
                    content = "";
                    if exist("response", "var") && isstruct(response) && ...
                            isfield(response, "content")
                        content = ". Content: " + contentText(response.content);
                    end
                    obj.raiseRest(string(exception.message) + content);
                end
            end
        end

        function [value, metadata] = search(obj, document, varargin)
            kwargs = keywordStruct(varargin);
            names = fieldnames(kwargs);
            criteria = struct();
            query = strings(1, 0);
            hasFields = false;
            for index = 1:numel(names)
                rawName = string(names{index});
                name = restoreKeyword(rawName);
                item = commaCat(kwargs.(names{index}));
                if startsWith(name, "_")
                    if name == "_fields"
                        hasFields = true;
                    else
                        query(end + 1) = name + "=" + item; %#ok<AGROW>
                    end
                else
                    criteria.(char(name)) = item;
                end
            end
            if ~hasFields
                query(end + 1) = "_all_fields=True";
            else
                fieldName = names{find(arrayfun(@(name) ...
                    restoreKeyword(string(name)) == "_fields", ...
                    string(names)), 1)};
                query(end + 1) = "_fields=" + ...
                    commaCat(kwargs.(fieldName));
                query(end + 1) = "_all_fields=False";
            end
            [value, metadata] = obj.request( ...
                "materials/" + string(document) + ...
                "/?" + join(query, "&"), criteria);
        end

        function [value, metadata] = summary_search(obj, varargin)
            [value, metadata] = obj.search("summary", varargin{:});
        end

        function value = get_summary(obj, criteria, fields)
            if nargin < 3 || isempty(fields)
                query = "_all_fields=True";
            else
                query = "_fields=" + commaCat(fields);
            end
            value = obj.request("materials/summary/?" + query, criteria);
        end

        function value = get_summary_by_material_id(obj, materialId, fields)
            if nargin < 3 || isempty(fields)
                query = "_all_fields=True";
            else
                query = "_fields=" + commaCat(fields);
            end
            docs = obj.request("materials/summary/?" + query, ...
                struct("material_ids", string(materialId)));
            value = firstOrIndexError(docs);
        end

        function value = get_doc(obj, varargin)
            value = obj.get_summary_by_material_id(varargin{:});
        end

        function value = get_material_ids(obj, formula)
            docs = obj.get_summary(struct("formula", string(formula)), ...
                "material_id");
            value = strings(1, numel(docs));
            for index = 1:numel(docs)
                value(index) = string(docs{index}.material_id);
            end
        end

        function value = get_materials_ids(obj, varargin)
            value = obj.get_material_ids(varargin{:});
        end

        function value = get_structures(obj, chemsysFormula, final)
            if nargin < 3, final = true; end
            if contains(string(chemsysFormula), "-")
                query = "chemsys=" + string(chemsysFormula);
            else
                query = "formula=" + string(chemsysFormula);
            end
            if final, property = "structure";
            else, property = "initial_structure";
            end
            docs = obj.request("materials/summary/?" + query + ...
                "&_all_fields=false&_fields=" + property);
            value = cell(1, numel(docs));
            for index = 1:numel(docs)
                value{index} = ensureStructure(docs{index}.(property));
            end
        end

        function structure = get_structure_by_material_id(obj, ...
                materialId, conventionalUnitCell)
            if nargin < 3, conventionalUnitCell = false; end
            docs = obj.request("materials/summary?material_ids=" + ...
                string(materialId) + "&_fields=structure");
            doc = firstOrIndexError(docs);
            structure = ensureStructure(doc.structure);
            if conventionalUnitCell
                analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
                    SpacegroupAnalyzer(structure);
                structure = analyzer.get_conventional_standard_structure();
            end
        end

        function structures = get_initial_structures_by_material_id( ...
                obj, materialId, conventionalUnitCell)
            if nargin < 3, conventionalUnitCell = false; end
            docs = obj.request("materials/summary/" + string(materialId) + ...
                "/?_fields=initial_structures");
            doc = firstOrIndexError(docs);
            raw = toCell(doc.initial_structures);
            structures = cell(1, numel(raw));
            for index = 1:numel(raw)
                structures{index} = ensureStructure(raw{index});
                if conventionalUnitCell
                    analyzer = kssolv.analysis.matgenlab.symmetry. ...
                        analyzer.SpacegroupAnalyzer(structures{index});
                    structures{index} = ...
                        analyzer.get_conventional_standard_structure();
                end
            end
        end

        function entries = get_entries(obj, criteria, varargin)
            options = struct("compatible_only", true, ...
                "property_data", strings(1, 0), ...
                "summary_data", strings(1, 0), ...
                "inc_structure", [], ...
                "conventional_unit_cell", [], ...
                "sort_by_e_above_hull", []);
            options = parseOptions(options, varargin);
            deprecated = ["inc_structure", "conventional_unit_cell", ...
                "sort_by_e_above_hull"];
            for deprecatedIndex = 1:numel(deprecated)
                if ~isempty(options.(deprecated(deprecatedIndex)))
                    warning("KSSOLV:Matgenlab:MPRester:Deprecated", ...
                        "The inc_structure, conventional_unit_cell, and " + ...
                        "sort_by_e_above_hull arguments are deprecated. " + ...
                        "These arguments have no effect.");
                    break
                end
            end
            criteria = normalizeCriteria(criteria);
            if startsWith(criteria, "mp-")
                query = "material_ids=" + criteria;
            elseif contains(criteria, "-")
                query = "chemsys=" + criteria;
            else
                query = "formula=" + criteria;
            end
            propertyData = string(options.property_data);
            propertyData = reshape(propertyData(propertyData ~= ""), 1, []);
            fields = ["entries", propertyData];
            docs = obj.request("materials/thermo/?_fields=" + ...
                join(fields, ",") + "&" + query);
            entries = cell(1, 0);
            for docIndex = 1:numel(docs)
                doc = docs{docIndex};
                rawEntries = valuesOf(doc.entries);
                for entryIndex = 1:numel(rawEntries)
                    entry = ensureEntry(rawEntries{entryIndex});
                    for propIndex = 1:numel(propertyData)
                        prop = char(propertyData(propIndex));
                        entry.data.(prop) = doc.(prop);
                    end
                    entries{end + 1} = entry; %#ok<AGROW>
                end
            end
            if logical(options.compatible_only) && ~isempty(entries)
                processor = obj.compatibility_processor;
                if isempty(processor)
                    processor = kssolv.analysis.matgenlab.analysis. ...
                        compatibility.MaterialsProject2020Compatibility();
                end
                if isa(processor, "function_handle")
                    entries = processor(entries);
                else
                    entries = processor.process_entries( ...
                        entries, "clean", true);
                end
            end
            summaryData = string(options.summary_data);
            summaryData = reshape(summaryData(summaryData ~= ""), 1, []);
            for startIndex = 1:obj.CHUNK_SIZE:numel(entries)
                if isempty(summaryData), break; end
                stopIndex = min(startIndex + obj.CHUNK_SIZE - 1, ...
                    numel(entries));
                chunk = entries(startIndex:stopIndex);
                materialIds = strings(1, numel(chunk));
                for index = 1:numel(chunk)
                    materialIds(index) = string( ...
                        chunk{index}.data.material_id);
                end
                summaryDocs = obj.search("summary", ...
                    "material_ids", materialIds, "_fields", ...
                    [summaryData, "material_id"]);
                mapped = containers.Map("KeyType", "char", ...
                    "ValueType", "any");
                for index = 1:numel(summaryDocs)
                    doc = summaryDocs{index};
                    materialId = string(doc.material_id);
                    doc = rmfield(doc, "material_id");
                    mapped(char(materialId)) = doc;
                end
                for index = 1:numel(chunk)
                    materialId = char(string(chunk{index}.data.material_id));
                    entry = chunk{index};
                    entry.data.summary = mapped(materialId);
                    chunk{index} = entry;
                    entries{startIndex + index - 1} = entry;
                end
            end
            entries = uniqueEntries(entries);
        end

        function value = get_entry_by_material_id(obj, materialId, varargin)
            entries = obj.get_entries(materialId, varargin{:});
            value = firstOrIndexError(entries);
        end

        function value = get_entries_in_chemsys(obj, elements, varargin)
            if ischar(elements) || (isstring(elements) && isscalar(elements))
                elements = split(string(elements), "-");
            else
                elements = string(elements);
            end
            elements = reshape(elements, 1, []);
            systems = strings(1, 0);
            for sizeIndex = 1:numel(elements)
                combinations = nchoosek(1:numel(elements), sizeIndex);
                for row = 1:size(combinations, 1)
                    selected = sort(elements(combinations(row, :)));
                    systems(end + 1) = join(selected, "-"); %#ok<AGROW>
                end
            end
            value = obj.get_entries(join(systems, ","), varargin{:});
        end

        function value = get_phonon_bandstructure_by_material_id( ...
                obj, materialId)
            data = obj.retrieveObjectFromS3(materialId, ...
                "materialsproject-parsed", "ph-bandstructures/dfpt", 60);
            lattice = kssolv.analysis.matgenlab.core.Lattice( ...
                double(data.reciprocal_lattice));
            labels = normalizeLabels(fieldOr(data, "labels_dict", []));
            eigen = complexArray(data.eigendisplacements);
            structure = ensureStructure(data.structure);
            value = kssolv.analysis.matgenlab.phonon. ...
                PhononBandStructureSymmLine( ...
                double(data.qpoints), double(data.frequencies), ...
                lattice, logical(data.has_nac), eigen, labels, false, ...
                structure);
        end

        function value = get_phonon_dos_by_material_id(obj, materialId)
            data = obj.retrieveObjectFromS3(materialId, ...
                "materialsproject-parsed", "ph-dos/dfpt", 60);
            if isfield(data, "projected_densities")
                data.pdos = data.projected_densities;
                data = rmfield(data, "projected_densities");
            elseif ~isfield(data, "pdos")
                data.pdos = [];
            end
            value = kssolv.analysis.matgenlab.phonon. ...
                CompletePhononDos.from_dict(data);
        end
    end

    methods (Static)
        function value = default_api_key()
            %DEFAULT_API_KEY Resolve official and pymatgen-compatible keys.
            value = "";
            try
                applicationSettings = kssolv.settings.Settings.load();
                value = string( ...
                    applicationSettings.MaterialsProjectAPIKey);
            catch
                % Settings are optional for headless/library-only use.
            end
            if value == ""
                value = string( ...
                    kssolv.analysis.matgenlab.core.Settings.get( ...
                    "MP_API_KEY", ""));
            end
            if value == ""
                value = string( ...
                    kssolv.analysis.matgenlab.core.Settings.get( ...
                    "PMG_MAPI_KEY", ""));
            end
            if value == ""
                value = string(getenv("MP_API_KEY"));
            end
            if value == ""
                value = string(getenv("PMG_MAPI_KEY"));
            end
            if value == ""
                value = string(getenv("MAPI_KEY"));
            end
        end
    end

    methods (Access = private)
        function response = invokeTransport(obj, request, isS3)
            if isS3, selected = obj.s3_transport;
            else, selected = obj.transport;
            end
            if isempty(selected)
                response = nativeTransport(request);
            elseif isa(selected, "function_handle")
                response = selected(request);
            elseif ismethod(selected, "request")
                response = selected.request(request);
            elseif ismethod(selected, "send")
                response = selected.send(request);
            else
                error("KSSOLV:Matgenlab:MPRester:Transport", ...
                    "Transport must be a function handle or request/send object.");
            end
        end

        function data = retrieveObjectFromS3(obj, materialId, bucket, ...
                prefix, timeout)
            url = "https://s3.us-east-1.amazonaws.com/" + ...
                string(bucket) + "/" + string(prefix) + "/" + ...
                string(materialId) + ".json.gz";
            requestData = struct("url", url, "method", "GET", ...
                "payload", [], "headers", struct(), "verify", true, ...
                "timeout", double(timeout));
            response = obj.invokeTransport(requestData, true);
            status = responseStatus(response);
            if ~any(status == [200, 400])
                reason = string(fieldOr(response, "reason", ""));
                obj.raiseRest("Failed to retrieve data from OpenData with " + ...
                    "status code " + status + ":" + newline + reason);
            end
            if isfield(response, "data")
                data = response.data;
                return
            end
            content = fieldOr(response, "content", uint8([]));
            if ischar(content) || isstring(content)
                text = string(content);
            else
                text = gzipText(uint8(content));
            end
            data = jsondecode(char(text));
            data = kssolv.analysis.matgenlab.util.fromDict( ...
                data, "Strict", false);
        end

        function raiseRest(~, message)
            throwAsCaller(kssolv.analysis.matgenlab.ext.matproj. ...
                MPRestError(message));
        end
    end
end

function options = parseOptions(options, arguments)
if isscalar(arguments) && isstruct(arguments{1})
    incoming = arguments{1};
    names = fieldnames(incoming);
    for index = 1:numel(names)
        options.(names{index}) = incoming.(names{index});
    end
    return
end
if rem(numel(arguments), 2) ~= 0
    error("KSSOLV:Matgenlab:MPRester:Arguments", ...
        "Name-value arguments must occur in pairs.");
end
for index = 1:2:numel(arguments)
    name = char(string(arguments{index}));
    if ~isfield(options, name)
        error("KSSOLV:Matgenlab:MPRester:Arguments", ...
            "Unknown option '%s'.", name);
    end
    options.(name) = arguments{index + 1};
end
end

function value = keywordStruct(arguments)
if isscalar(arguments) && isstruct(arguments{1})
    value = arguments{1};
    return
end
if rem(numel(arguments), 2) ~= 0
    error("KSSOLV:Matgenlab:MPRester:Arguments", ...
        "Search arguments must be a struct or name-value pairs.");
end
value = struct();
for index = 1:2:numel(arguments)
    name = string(arguments{index});
    if startsWith(name, "_")
        field = "x" + name;
    else
        field = name;
    end
    value.(char(field)) = arguments{index + 1};
end
end

function value = restoreKeyword(name)
if startsWith(name, "x_"), value = extractAfter(name, 1);
else, value = name;
end
end

function value = commaCat(input)
if iscell(input)
    value = join(string(input), ",");
elseif isstring(input) && ~isscalar(input)
    value = join(input, ",");
elseif isnumeric(input) || islogical(input)
    if isscalar(input)
        if islogical(input)
            if input, value = "True";
            else, value = "False";
            end
        else
            value = string(input);
        end
    else
        value = join(string(input), ",");
    end
else
    value = string(input);
end
end

function value = responseStatus(response)
if ~isstruct(response) || ~isfield(response, "status_code")
    error("KSSOLV:Matgenlab:MPRester:TransportResponse", ...
        "Transport response requires status_code.");
end
value = double(response.status_code);
end

function value = decodeResponse(response, mpDecode)
if isfield(response, "data") && isstruct(response.data)
    value = response.data;
    if mpDecode
        value = kssolv.analysis.matgenlab.util.fromDict( ...
            value, "Strict", false);
    end
    return
end
text = responseText(response);
value = jsondecode(char(text));
if mpDecode
    value = kssolv.analysis.matgenlab.util.fromDict( ...
        value, "Strict", false);
end
end

function value = responseText(response)
if isfield(response, "text")
    value = string(response.text);
elseif isfield(response, "content")
    value = contentText(response.content);
else
    value = "";
end
end

function value = contentText(content)
if isstring(content), value = content;
elseif ischar(content), value = string(content);
else, value = string(native2unicode(uint8(content), "UTF-8"));
end
end

function value = fieldOr(input, name, default)
if isstruct(input) && isfield(input, name)
    value = input.(name);
else
    value = default;
end
end

function value = toCell(input)
if isempty(input), value = cell(1, 0);
elseif iscell(input), value = input;
elseif isstruct(input), value = num2cell(input);
else, value = num2cell(input);
end
end

function value = firstOrIndexError(values)
if isempty(values)
    error("KSSOLV:Matgenlab:MPRester:IndexError", ...
        "list index out of range");
end
if iscell(values), value = values{1};
else, value = values(1);
end
end

function value = ensureStructure(input)
if isa(input, "kssolv.analysis.matgenlab.core.Structure")
    value = input;
else
    value = kssolv.analysis.matgenlab.core.Structure.from_dict(input);
end
end

function value = ensureEntry(input)
if isa(input, "kssolv.analysis.matgenlab.core.ComputedEntry")
    value = input;
    return
end
className = string(fieldOr(input, "x_class", ...
    fieldOr(input, "class", "ComputedEntry")));
if className == "ComputedStructureEntry" || isfield(input, "structure")
    value = kssolv.analysis.matgenlab.core.ComputedStructureEntry. ...
        from_dict(input);
else
    value = kssolv.analysis.matgenlab.core.ComputedEntry.from_dict(input);
end
end

function values = valuesOf(input)
if isa(input, "containers.Map")
    values = input.values;
elseif iscell(input)
    values = input;
elseif isstruct(input)
    if ~isscalar(input)
        values = num2cell(input);
    else
        names = fieldnames(input);
        values = cell(1, numel(names));
        for index = 1:numel(names)
            values{index} = input.(names{index});
        end
    end
else
    values = num2cell(input);
end
end

function value = normalizeCriteria(criteria)
if iscell(criteria), criteria = string(criteria); end
criteria = string(criteria);
if isscalar(criteria), criteria = split(criteria, ","); end
criteria = reshape(criteria, 1, []);
for index = 1:numel(criteria)
    item = criteria(index);
    if startsWith(item, "mp-")
        continue
    elseif contains(item, "-")
        item = join(sort(split(item, "-")), "-");
    else
        composition = kssolv.analysis.matgenlab.core.Composition(item);
        if numel(composition.elements) > 1
            item = composition.reduced_formula;
        end
    end
    criteria(index) = item;
end
value = join(criteria, ",");
end

function values = uniqueEntries(values)
seen = containers.Map("KeyType", "char", "ValueType", "logical");
keep = false(1, numel(values));
for index = 1:numel(values)
    entry = values{index};
    if ~isempty(entry.entry_id)
        key = "id:" + string(entry.entry_id);
    else
        key = "entry:" + entry.reduced_formula + ":" + ...
            compose("%.15g", entry.energy);
    end
    if ~isKey(seen, char(key))
        seen(char(key)) = true;
        keep(index) = true;
    end
end
values = values(keep);
end

function labels = normalizeLabels(input)
labels = containers.Map("KeyType", "char", "ValueType", "any");
if isempty(input), return; end
if isa(input, "containers.Map"), labels = input; return; end
names = fieldnames(input);
for index = 1:numel(names)
    name = string(names{index});
    if name == "x_Gamma", name = "\Gamma"; end
    labels(char(name)) = double(input.(names{index}));
end
end

function value = complexArray(input)
if isnumeric(input)
    value = double(input);
elseif isstruct(input) && isfield(input, "real")
    value = double(input.real) + 1i * double(input.imag);
elseif iscell(input) || isstring(input) || ischar(input)
    shape = nestedShape(input);
    flattened = flattenNested(input);
    parsed = cellfun(@parseComplexScalar, flattened);
    if isempty(shape)
        value = parsed;
    else
        reversed = reshape(parsed, fliplr(shape));
        value = permute(reversed, numel(shape):-1:1);
    end
else
    value = input;
end
end

function shape = nestedShape(input)
shape = zeros(1, 0);
while iscell(input)
    shape(end + 1) = numel(input); %#ok<AGROW>
    if isempty(input), return; end
    input = input{1};
end
end

function values = flattenNested(input)
if ~iscell(input)
    values = {input};
    return
end
values = cell(1, 0);
for index = 1:numel(input)
    values = [values, flattenNested(input{index})]; %#ok<AGROW>
end
end

function value = parseComplexScalar(input)
if isnumeric(input)
    value = double(input);
    return
end
text = string(input);
if startsWith(text, "(") && endsWith(text, ")")
    text = extractBetween(text, 2, strlength(text) - 1);
end
token = regexp(text, ...
    "^(?<real>[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)" + ...
    "(?<imag>[-+](?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)j$", ...
    "names", "once");
if isempty(token)
    token = regexp(text, ...
        "^(?<imag>[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)j$", ...
        "names", "once");
    if isempty(token)
        value = str2double(text);
        if isnan(value)
            error("KSSOLV:Matgenlab:MPRester:ComplexValue", ...
                "Invalid OpenData complex value '%s'.", text);
        end
        return
    end
    value = complex(0, str2double(token.imag));
else
    value = complex(str2double(token.real), str2double(token.imag));
end
end

function response = nativeTransport(request)
import matlab.net.URI
import matlab.net.http.HTTPOptions
import matlab.net.http.HeaderField
import matlab.net.http.MessageBody
import matlab.net.http.RequestMessage
import matlab.net.http.RequestMethod
url = string(request.url);
if upper(string(request.method)) == "GET" && isstruct(request.payload)
    names = fieldnames(request.payload);
    for index = 1:numel(names)
        url = appendQuery(url, names{index}, ...
            request.payload.(names{index}));
    end
end
headerNames = fieldnames(request.headers);
headers = matlab.net.http.HeaderField.empty(0, numel(headerNames));
for index = 1:numel(headerNames)
    wireName = replace(string(headerNames{index}), "_", "-");
    headers(index) = HeaderField(wireName, ...
        string(request.headers.(headerNames{index})));
end
method = upper(string(request.method));
if method == "POST"
    body = MessageBody(request.payload);
    message = RequestMessage(RequestMethod.POST, headers, body);
else
    message = RequestMessage(RequestMethod.GET, headers);
end
reply = message.send(URI(url), ...
    HTTPOptions("ConnectTimeout", request.timeout));
bodyData = reply.Body.Data;
if ischar(bodyData) || isstring(bodyData)
    text = string(bodyData);
    content = uint8(unicode2native(char(text), "UTF-8"));
elseif isa(bodyData, "uint8")
    text = string(native2unicode(bodyData, "UTF-8"));
    content = bodyData;
else
    text = jsonencode(bodyData);
    content = uint8(unicode2native(char(text), "UTF-8"));
end
response = struct("status_code", double(reply.StatusCode), ...
    "text", text, "content", content, ...
    "reason", string(reply.StatusLine.ReasonPhrase));
end

function url = appendQuery(url, name, value)
url = string(url);
if contains(url, "?")
    separator = "&";
else
    separator = "?";
end
url = url + separator + percentEncode(name) + "=" + ...
    percentEncode(commaCat(value));
end

function value = percentEncode(input)
bytes = unicode2native(char(string(input)), "UTF-8");
safe = (bytes >= uint8('A') & bytes <= uint8('Z')) | ...
    (bytes >= uint8('a') & bytes <= uint8('z')) | ...
    (bytes >= uint8('0') & bytes <= uint8('9')) | ...
    ismember(bytes, uint8('-._~'));
parts = strings(1, numel(bytes));
for index = 1:numel(bytes)
    if safe(index), parts(index) = char(bytes(index));
    else, parts(index) = "%" + upper(dec2hex(bytes(index), 2));
    end
end
value = join(parts, "");
end

function text = gzipText(content)
archive = string(tempname) + ".json.gz";
folder = string(tempname);
mkdir(folder);
cleanup = onCleanup(@() cleanupFiles(archive, folder));
handle = fopen(archive, "w");
if handle < 0
    error("KSSOLV:Matgenlab:MPRester:Gzip", ...
        "Cannot create temporary gzip archive.");
end
fileCleanup = onCleanup(@() fclose(handle));
fwrite(handle, content, "uint8");
clear fileCleanup
files = gunzip(archive, folder);
text = string(fileread(files{1}));
clear cleanup
end

function cleanupFiles(archive, folder)
if isfile(archive), delete(archive); end
if isfolder(folder), rmdir(folder, "s"); end
end
