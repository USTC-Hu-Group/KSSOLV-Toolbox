classdef OptimadeMockTransport < handle
    %OPTIMADEMOCKTRANSPORT Stateful offline OPTIMADE request fixture.

    properties
        Callback = []
        Requests cell = cell(1, 0)
        closed (1,1) logical = false
    end

    methods
        function obj = OptimadeMockTransport(callback)
            if nargin > 0, obj.Callback = callback; end
        end

        function response = request(obj, request)
            obj.Requests{end + 1} = request;
            if isempty(obj.Callback)
                error("KSSOLV:Matgenlab:OptimadeMock:NoResponse", ...
                    "No mock response configured for %s.", request.url);
            end
            response = obj.Callback(request);
        end

        function close(obj)
            obj.closed = true;
        end
    end
end
