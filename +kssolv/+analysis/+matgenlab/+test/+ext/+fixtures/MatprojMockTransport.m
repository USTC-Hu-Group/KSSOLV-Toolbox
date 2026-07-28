classdef MatprojMockTransport < handle
    %MATPROJMOCKTRANSPORT Deterministic queue/callback transport for tests.

    properties
        Requests cell = cell(1, 0)
        Responses cell = cell(1, 0)
        Callback = []
    end

    methods
        function obj = MatprojMockTransport(responses)
            if nargin > 0, obj.Responses = responses; end
        end

        function response = request(obj, request)
            obj.Requests{end + 1} = request;
            if ~isempty(obj.Callback)
                response = obj.Callback(request);
            elseif isempty(obj.Responses)
                response = makeResponse(cell(1, 0));
            else
                response = obj.Responses{1};
                obj.Responses(1) = [];
            end
        end
    end
end

function response = makeResponse(docs)
envelope = struct();
envelope.data = docs;
response = struct("status_code", 200, "data", envelope);
end
