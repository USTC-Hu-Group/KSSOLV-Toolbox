classdef NamespaceCompatibilityTest < matlab.unittest.TestCase
    % The MAT fixture was generated with the production pre-move HTTP class
    % and named LLM/migration callbacks, before the compatibility shims existed.
    methods (Test)
        function oldMatObjectRunsAndRoundTripsAfterCompletion(testCase)
            installHTTPFixture(testCase);
            fixture = loadLegacyFixture(testCase);
            request = fixture.legacyRequest;
            testCase.verifyClass(request, 'kssolv.util.HTTPJSONRequest');
            testCase.verifyTrue(isa(request, 'kssolv.services.http.HTTPJSONRequest'));
            request.start();
            waitForCompletion(testCase, request);
            testCase.verifyEmpty(request.Error);
            result = jsondecode(request.OutputArguments{1});
            testCase.verifyEqual(result.data.id, 'legacy-model');
            expected = request.OutputArguments;
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'completed-legacy.mat');
            save(file, 'request');
            restored = load(file, 'request');
            testCase.addTeardown(@() delete(restored.request));
            testCase.verifyEqual(restored.request.State, 'finished');
            testCase.verifyEmpty(restored.request.Error);
            testCase.verifyEqual(restored.request.OutputArguments, expected);
            % Cleared headers in the implementation must not be restored from
            % a second credentials copy in the compatibility class.
            warnings = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnings));
            state = struct(restored.request);
            testCase.verifyEmpty(state.Headers);
            testCase.verifyEqual(func2str(state.Decode), 'jsonencode');
            testCase.verifyEqual(string(state.WorkerToken), "");
        end

        function newLegacyNameObjectsKeepTheCurrentMatLayout(testCase)
            installHTTPFixture(testCase);
            request = kssolv.util.HTTPJSONRequest( ...
                'https://fixture.invalid/v1/models', ...
                struct('Authorization', 'Bearer fixture-only'), @jsonencode, []);
            testCase.addTeardown(@() delete(request));
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'new-legacy-name.mat');
            save(file, 'request');
            restored = load(file, 'request');
            testCase.addTeardown(@() delete(restored.request));
            restored.request.start();
            waitForCompletion(testCase, restored.request);
            testCase.verifyEmpty(restored.request.Error);
            result = jsondecode(restored.request.OutputArguments{1});
            testCase.verifyEqual(result.data.id, 'legacy-model');
        end

        function oldNamedNativeTransportRetainsFallbackBehavior(testCase)
            fixture = loadLegacyFixture(testCase);
            calls = 0;
            parameters = struct('model', 'fixture-model', ...
                'tools', struct('type', 'function'), 'tool_choice', 'auto');
            [response, text] = fixture.legacyNative(parameters, 'fixture-key', ...
                'https://fixture.invalid/chat/completions', 30, [], @transport);
            testCase.verifyEqual(calls, 2);
            testCase.verifyEqual(response.StatusCode, 200);
            testCase.verifyEqual(text, 'legacy reply');

            function [response, text] = transport(parameters, ~, ~, ~, ~)
                calls = calls + 1;
                if calls == 1
                    testCase.verifyTrue(isfield(parameters, 'tools'));
                    response = struct('StatusCode', 400, 'Body', struct('Data', ...
                        struct('error', struct('message', 'tools are unsupported'))));
                    text = '';
                else
                    testCase.verifyFalse(isfield(parameters, 'tools'));
                    testCase.verifyFalse(isfield(parameters, 'tool_choice'));
                    response = struct('StatusCode', 200);
                    text = 'legacy reply';
                end
            end
        end

        function inFlightLegacyStateIsNotReplayedAfterLoading(testCase)
            callbacks = 0;
            state = struct('URL', 'https://fixture.invalid/v1/models', ...
                'Headers', struct(), 'Decode', @jsonencode, 'Complete', @complete, ...
                'WorkerURL', "", 'WorkerToken', "", 'State', 'running');
            request = kssolv.util.HTTPJSONRequest.loadobj(state);
            testCase.addTeardown(@() delete(request));
            testCase.verifyEqual(request.State, 'finished');
            testCase.verifyEqual(request.Error.identifier, 'KSSOLV:HTTP:InterruptedRequest');
            testCase.verifyEmpty(request.OutputArguments);
            testCase.verifyEqual(callbacks, 0);

            function complete(~)
                callbacks = callbacks + 1;
            end
        end

        function oldNamedWorkerTransportRetainsStreamingBehavior(testCase)
            installHTTPFixture(testCase);
            testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture( ...
                'KSSOLV_HTTP_WORKER_URL', 'http://worker.fixture.invalid'));
            fixture = loadLegacyFixture(testCase);
            output = '';
            [response, text] = fixture.legacyWorker( ...
                struct('model', 'fixture-model'), 'fixture-key', ...
                'https://fixture.invalid/chat/completions', 30, @collect);
            testCase.verifyEqual(double(response.StatusCode), 200);
            testCase.verifyEqual(text, 'legacy reply');
            testCase.verifyEqual(output, 'legacy reply');

            function collect(token)
                output = [output token];
            end
        end

        function oldNamedMigrationCallbackStillAcceptsProjectTrees(testCase)
            fixture = loadLegacyFixture(testCase);
            project = kssolv.services.filemanager.Project();
            item = kssolv.services.filemanager.Workflow();
            item.graphJSON = jsonencode(struct('cells', struct('id', 'n', ...
                'shape', 'dag-node', 'data', struct('label', 'Node', 'status', 'default'))));
            node = item.graph.Nodes('n');
            node.task.usedParallelType = 'Threads';
            project.children{1}.addChildrenItem(item);
            fixture.legacyMigration(project);
            testCase.verifyEqual(node.task.usedParallelType, 'None');
            testCase.verifyFalse(node.task.taskUICreated);
        end
    end
end

function fixture = loadLegacyFixture(testCase)
fixture = [];
testCase.verifyWarningFree(@readFixture);
testCase.addTeardown(@() delete(fixture.legacyRequest));
    function readFixture()
        file = fullfile(fileparts(mfilename('fullpath')), ...
            '+fixtures', 'legacy-http-and-llm.mat');
        fixture = load(file);
    end
end

function waitForCompletion(testCase, request)
started = tic;
while ~strcmp(request.State, 'finished')
    testCase.assertLessThan(toc(started), 12, 'The HTTP request did not finish.');
    pause(0.05);
end
end

function installHTTPFixture(testCase)
% Stub only the HTTP wire boundary; constructors, the background pool,
% request timer, callbacks and persistence use the production implementations.
folder = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
writelines([ ...
    "function result = webread(url, varargin)"; ...
    "if strcmp(url, 'https://fixture.invalid/v1/models')"; ...
    "    options = varargin{1};"; ...
    "    assert(isequal(options.HeaderFields, {'Authorization','Bearer fixture-only'}));"; ...
    "    result = struct('data', struct('id', 'legacy-model'));"; ...
    "else"; ...
    "    assert(strcmp(url, 'http://worker.fixture.invalid/requests/legacy-job'));"; ...
    "    result = struct('state','finished','tokens',{{'legacy ','reply'}}, ..."; ...
    "        'response',struct('choices',struct('message',struct('content','legacy reply'))));"; ...
    "end"; ...
    "end"], fullfile(folder, 'webread.m'));
writelines([ ...
    "function result = webwrite(url, data, varargin)"; ...
    "if strcmp(url, 'http://worker.fixture.invalid/chat')"; ...
    "    assert(data.parameters.stream);"; ...
    "    assert(strcmp(data.headers.Authorization, 'Bearer fixture-key'));"; ...
    "    result = struct('id', 'legacy-job');"; ...
    "else"; ...
    "    assert(strcmp(url, 'http://worker.fixture.invalid/requests/legacy-job'));"; ...
    "    result = struct();"; ...
    "end"; ...
    "end"], fullfile(folder, 'webwrite.m'));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture( ...
    'KSSOLV_HTTP_WORKER_URL', ''));
end
