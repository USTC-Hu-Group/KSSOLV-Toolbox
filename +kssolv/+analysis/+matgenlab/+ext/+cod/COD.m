classdef COD
    %COD Interface to the Crystallography Open Database.

    properties
        timeout (1, 1) double = 60
        url (1, 1) string = "https://www.crystallography.net"
        api_url (1, 1) string = ...
            "https://www.crystallography.net/cod/result"
        transport = []
    end

    methods
        function obj = COD(timeout, transport)
            if nargin >= 1 && ~isempty(timeout), obj.timeout = timeout; end
            if nargin >= 2, obj.transport = transport; end
        end

        function ids = get_cod_ids(obj, formula)
            composition = kssolv.analysis.matgenlab.core.Composition(formula);
            request = struct("method", "GET", "url", obj.api_url, ...
                "params", struct("formula", composition.hill_formula, ...
                "format", "json"), "timeout", obj.timeout);
            entries = decodeJsonResponse(obj.fetch(request));
            if isempty(entries)
                ids = zeros(1, 0);
            else
                ids = arrayfun(@(entry) str2double(string(entry.file)), ...
                    entries);
                ids = reshape(ids, 1, []);
            end
        end

        function structure = get_structure_by_id(obj, cod_id, ...
                timeout, varargin)
            if nargin < 3 || isempty(timeout), timeout = obj.timeout; end
            request = struct("method", "GET", ...
                "url", obj.url + "/cod/" + string(cod_id) + ".cif", ...
                "params", struct(), "timeout", timeout);
            response = obj.fetch(request);
            text = responseText(response);
            structure = kssolv.analysis.matgenlab.core.Structure. ...
                from_str(text, "cif", varargin{:});
        end

        function structures = get_structure_by_formula(obj, formula, varargin)
            composition = kssolv.analysis.matgenlab.core.Composition(formula);
            request = struct("method", "GET", "url", obj.api_url, ...
                "params", struct("formula", composition.hill_formula, ...
                "format", "json"), "timeout", obj.timeout);
            entries = decodeJsonResponse(obj.fetch(request));
            structures = cell(1, numel(entries));
            for index = 1:numel(entries)
                codId = str2double(string(entries(index).file));
                spaceGroup = [];
                if isfield(entries, "sg"), spaceGroup = entries(index).sg; end
                structure = obj.get_structure_by_id(codId, [], varargin{:});
                structures{index} = struct("structure", structure, ...
                    "cod_id", codId, "sg", spaceGroup);
            end
        end
    end

    methods (Access = private)
        function response = fetch(obj, request)
            if isempty(obj.transport)
                error("KSSOLV:Matgenlab:COD:TransportRequired", ...
                    "COD requests require an explicitly supplied MATLAB transport.");
            end
            response = obj.transport(request);
            if isstruct(response) && isfield(response, "status") && ...
                    (response.status < 200 || response.status >= 300)
                error("KSSOLV:Matgenlab:COD:HTTP", ...
                    "COD request failed with HTTP status %d.", response.status);
            end
        end
    end
end

function decoded = decodeJsonResponse(response)
if isstruct(response) && isfield(response, "json")
    decoded = response.json;
else
    decoded = jsondecode(responseText(response));
end
end

function text = responseText(response)
if isstruct(response) && isfield(response, "text")
    text = string(response.text);
elseif ischar(response) || isstring(response)
    text = string(response);
else
    error("KSSOLV:Matgenlab:COD:Response", ...
        "COD transport response must contain text or json.");
end
end
