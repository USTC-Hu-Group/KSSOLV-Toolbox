function [response, streamedText] = sendRequest(parameters, token, endpoint, timeout, streamFunction)
%SENDREQUEST Compatibility entry point for saved callbacks and external callers.
[response, streamedText] = kssolv.services.llm.online.internal.sendRequest( ...
    parameters, token, endpoint, timeout, streamFunction);
end
