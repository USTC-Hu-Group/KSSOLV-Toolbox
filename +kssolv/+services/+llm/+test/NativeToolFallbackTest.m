classdef NativeToolFallbackTest < matlab.unittest.TestCase
    methods (Test)
        function explicitRejectionRetriesOnlyWithoutTools(testCase)
            for status = [400, 422]
                [calls, response, text] = exercise(rejection(status));
                testCase.verifyNumElements(calls, 2);
                first = calls{1};
                second = calls{2};
                testCase.verifyEqual(second.parameters, ...
                    rmfield(first.parameters, {'tools', 'tool_choice'}));
                testCase.verifyEqual(second.token, first.token);
                testCase.verifyEqual(second.endpoint, first.endpoint);
                testCase.verifyEqual(second.timeout, first.timeout);
                testCase.verifyEqual(response.StatusCode, 200);
                testCase.verifyEqual(text, 'reply');
            end
        end

        function unrelatedFailuresAndSuccessfulStreamsAreNeverRetried(testCase)
            for status = [200, 401, 403, 429, 500]
                calls = exercise(rejection(status));
                testCase.verifyNumElements(calls, 1);
            end
            response = rejection(400);
            response.Body.Data.error.message = 'Invalid model name.';
            testCase.verifyNumElements(exercise(response), 1);
            response = rejection(400);
            response.Body.Data.error.param = 'max_tokens';
            testCase.verifyNumElements(exercise(response), 1);
        end

        function partialOutputAndToolDeltasAreNeverReplayed(testCase)
            [calls, ~, ~, output] = exercise(rejection(400), 'partial');
            testCase.verifyNumElements(calls, 1);
            testCase.verifyEqual(output, 'partial');
            calls = exercise(rejection(400), '', '{"tool_calls":[]}');
            testCase.verifyNumElements(calls, 1);
        end

        function transportErrorsPropagateWithoutRetry(testCase)
            attempts = 0;
            testCase.verifyError(@() kssolv.services.llm.online.internal.sendNativeRequest( ...
                parameters(), 'fixture-key', 'https://fixture.invalid', 30, [], @fail), ...
                'KSSOLV:Test:TransportFailure');
            testCase.verifyEqual(attempts, 1);
            function [response, text] = fail(varargin) %#ok<STOUT>
                attempts = attempts + 1;
                error('KSSOLV:Test:TransportFailure', 'Connection ended.');
            end
        end

        function retryIsBoundedAndRequiresActualTools(testCase)
            calls = exercise(rejection(400), '', '', true);
            testCase.verifyNumElements(calls, 2);
            request = parameters();
            request.tools = [];
            calls = exercise(rejection(400), '', '', false, request);
            testCase.verifyNumElements(calls, 1);
            request = rmfield(request, 'tools');
            calls = exercise(rejection(400), '', '', false, request);
            testCase.verifyNumElements(calls, 1);
        end

        function rawErrorBodiesAndNonStreamingRequestsAreSupported(testCase)
            response = rejection(422);
            body = jsonencode(response.Body.Data);
            for value = {body, unicode2native(body, 'UTF-8'), 'not JSON'}
                response.Body.Data = value{1};
                calls = exercise(response);
                testCase.verifyNumElements(calls, 1 + ~strcmp(value{1}, 'not JSON'));
            end
            attempts = 0;
            kssolv.services.llm.online.internal.sendNativeRequest(parameters(), 'key', ...
                'https://fixture.invalid', 30, [], @send);
            testCase.verifyEqual(attempts, 2);
            function [reply, text] = send(~, ~, ~, ~, callback)
                testCase.verifyEmpty(callback);
                attempts = attempts + 1;
                reply = rejection(400);
                text = '';
            end
        end
    end
end

function value = parameters()
value = struct('model', 'fixture-model', 'messages', {{struct( ...
    'role', 'user', 'content', 'hello')}}, 'stream', true, ...
    'temperature', 0.6, 'tools', struct('type', 'function'), 'tool_choice', 'auto');
end

function response = rejection(status)
response = struct('StatusCode', status, 'Body', struct('Data', ...
    struct('error', struct('message', 'tools are not supported'))));
end

function [calls, response, text, output] = exercise(firstResponse, emitted, firstText, rejectAgain, request)
if nargin < 2, emitted = ''; end
if nargin < 3, firstText = ''; end
if nargin < 4, rejectAgain = false; end
if nargin < 5, request = parameters(); end
calls = {};
output = '';
[response, text] = kssolv.services.llm.online.internal.sendNativeRequest( ...
    request, 'fixture-key', 'https://fixture.invalid/chat/completions', 30, @collect, @send);
    function [reply, streamed] = send(params, token, endpoint, timeout, callback)
        calls{end + 1} = struct('parameters', params, 'token', token, ...
            'endpoint', endpoint, 'timeout', timeout);
        if isscalar(calls) || rejectAgain
            reply = firstResponse;
            streamed = firstText;
            if ~isempty(emitted), callback(emitted); end
        else
            reply = rejection(200);
            streamed = 'reply';
        end
    end
    function collect(token)
        output = [output token];
    end
end
