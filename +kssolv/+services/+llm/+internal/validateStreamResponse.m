function validateStreamResponse(response)
%VALIDATESTREAMRESPONSE Reject an OpenAI stream that ended without completion.
% The Add-On returns received SSE bytes even when the connection is truncated.
% Check the protocol terminator rather than Content-Length: a consumer may
% deliberately stop reading after the final choice, before the HTTP body ends.

if response.StatusCode ~= "OK"
    return
end
data = response.Body.Data;
if isstruct(data)
    return % Ordinary, non-streaming JSON response.
elseif isnumeric(data)
    text = string(native2unicode(uint8(data(:).'), 'UTF-8'));
elseif ischar(data) || isstring(data)
    text = string(data);
else
    error('KSSOLV:LLM:IncompleteStream', ...
        'The model response ended before completion. Please retry.');
end

for rawLine = splitlines(text).'
    line = strip(rawLine);
    if ~startsWith(line, 'data:')
        continue
    end
    payload = strip(extractAfter(line, 'data:'));
    if payload == "[DONE]"
        return
    end
    try
        chunk = jsondecode(payload);
    catch
        continue
    end
    if isstruct(chunk) && isfield(chunk, 'choices')
        for choice = reshape(chunk.choices, 1, [])
            if isfield(choice, 'finish_reason') && ...
                    (ischar(choice.finish_reason) || isstring(choice.finish_reason))
                reason = string(choice.finish_reason);
                if any(reason == ["stop", "tool_calls", "function_call"])
                    return
                elseif strlength(reason) > 0
                    error('KSSOLV:LLM:IncompleteStream', ...
                        'The model response stopped with reason "%s". Please retry.', reason);
                end
            end
        end
    end
end
error('KSSOLV:LLM:IncompleteStream', ...
    'The model connection ended before completion. Please retry.');
end
