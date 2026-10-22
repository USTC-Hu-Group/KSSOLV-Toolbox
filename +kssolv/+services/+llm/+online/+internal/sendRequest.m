function [response, streamedText] = sendRequest(parameters, token, endpoint, ~, streamFunction)
%SENDREQUEST Poll the authenticated loopback worker without blocking UI events.
% llms-with-matlab 4.9 exposes sendRequestFcn for transport injection. Native
% desktop clients retain its original transport; Online uses the supervisor's
% existing Python worker. Keys and prompts remain in memory, never in logs.
worker = string(getenv('KSSOLV_HTTP_WORKER_URL'));
options = weboptions('Timeout',2,'MediaType','application/json','ContentType','json', ...
    'HeaderFields',{'Authorization',char("Bearer " + getenv('KSSOLV_HTTP_WORKER_TOKEN'))});
parameters.stream = true;
data = struct('url',char(endpoint),'headers',struct('Authorization',"Bearer " + token), ...
    'parameters',parameters);
job = webwrite(worker + '/chat',data,options);
cleanup = onCleanup(@() cancelJob(worker,string(job.id),options));
started = tic;
while true
    pause(0.05); % Process layout, painting and other UI callbacks between polls.
    if toc(started) > 190
        error('KSSOLV:LLM:Timeout','The model request timed out.');
    end
    reply = webread(worker + '/requests/' + string(job.id),options);
    if isfield(reply,'tokens') && ~isempty(streamFunction)
        for text = reshape(string(reply.tokens),1,[])
            streamFunction(char(text));
        end
    end
    if string(reply.state) ~= "finished", continue, end
    if isfield(reply,'error')
        kind = string(reply.error.kind);
        if kind == "http"
            error('KSSOLV:LLM:HTTPError','The model service returned HTTP %d.',reply.error.status);
        elseif kind == "incomplete"
            error('KSSOLV:LLM:IncompleteStream','The model connection ended before completion.');
        elseif kind == "timeout"
            error('KSSOLV:LLM:Timeout','The model request timed out.');
        else
            error('KSSOLV:LLM:ConnectionFailed','The model connection failed.');
        end
    end
    response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK, ...
        matlab.net.http.HeaderField('Content-Type','application/json'), ...
        matlab.net.http.MessageBody(reply.response));
    message = reply.response.choices(1).message;
    if isfield(message,'tool_calls') && ~isempty(message.tool_calls)
        calls = message.tool_calls;
        if iscell(calls), calls = [calls{:}]; end
        streamedText = jsonencode(calls);
    else
        streamedText = char(string(message.content));
    end
    return
end
end

function cancelJob(worker, jobId, options)
try
    options.RequestMethod = 'delete';
    webwrite(worker + '/requests/' + jobId,struct(),options);
catch
    % The worker bounds lifetime and cancels all jobs on shutdown.
end
end
