function [response, streamedText] = sendNativeRequest( ...
        parameters, token, endpoint, timeout, streamFunction, transport)
%SENDNATIVEREQUEST Retry only an explicit rejection of optional tools.
% Inspect the native HTTP response before the Add-On turns it into an
% exception. Never replay a successful/partial stream or a transport error.
emitted = false;
callback = streamFunction;
if ~isempty(streamFunction)
    callback = @collect;
end
[response, streamedText] = transport(parameters, token, endpoint, timeout, callback);
if emitted || any(strlength(string(streamedText)) > 0, 'all') || ...
        ~isfield(parameters, 'tools') || isempty(parameters.tools) || ...
        ~rejectsTools(response)
    return
end
parameters = rmfield(parameters, intersect(fieldnames(parameters), {'tools', 'tool_choice'}));
[response, streamedText] = transport(parameters, token, endpoint, timeout, callback);

    function collect(text)
        emitted = emitted || any(strlength(string(text)) > 0);
        streamFunction(text);
    end
end

function rejected = rejectsTools(response)
rejected = false;
if ~any(double(response.StatusCode) == [400, 422])
    return
end
data = response.Body.Data;
if isnumeric(data)
    data = native2unicode(uint8(data(:).'), 'UTF-8');
end
if ischar(data) || isstring(data)
    try
        data = jsondecode(data);
    catch
        return
    end
end
if ~isstruct(data) || ~isscalar(data) || ~isfield(data, 'error') || ...
        ~isstruct(data.error) || ~isscalar(data.error) || ...
        ~isfield(data.error, 'message') || ...
        ~(ischar(data.error.message) || isstring(data.error.message))
    return
end
message = lower(string(data.error.message));
if ~isscalar(message)
    return
end
if isfield(data.error, 'param') && ~isempty(data.error.param)
    parameter = string(data.error.param);
    if ~isscalar(parameter) || ~any(parameter == ["tools", "tool_choice"])
        return
    end
end
rejected = contains(message, 'tool') && any(contains(message, ...
    ["unsupported", "not support", "not allowed", "unknown parameter", "unrecognized"]));
end
