classdef NativeChatConnectionTest < matlab.unittest.TestCase
    % Start scripts/docker/fixtures/chat_api.py and set KSSOLV_TEST_CHAT_API.
    properties
        Endpoint
    end
    methods (TestMethodSetup)
        function useNativeTransport(testCase)
            endpoint = string(getenv('KSSOLV_TEST_CHAT_API'));
            testCase.assumeNotEmpty(char(endpoint));
            testCase.Endpoint = endpoint + "/" + string(matlab.lang.internal.uuid);
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            values = {'KSSOLV_ONLINE', 'true'; 'KSSOLV_USER_DATA_DIR', folder.Folder; ...
                'KSSOLV_LOCALE', 'en_US'; 'OPENAI_API_KEY', 'fixture-only'; ...
                'KSSOLV_HTTP_WORKER_URL', ''; 'KSSOLV_HTTP_WORKER_TOKEN', ''; 'HTTPS_PROXY', ''};
            for index = 1:size(values, 1)
                testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture( ...
                    values{index, 1}, values{index, 2}));
            end
            kssolv.settings.Preferences.write(struct('LLMType', 'OpenAICompatible', ...
                'OpenAIBaseURL', testCase.Endpoint, 'OpenAIModel', 'fixture-deepseek'));
        end
    end
    methods (Test)
        function acceptedToolsUseOnlyTheActualRequest(testCase)
            output = "";
            [bot, failure] = kssolv.services.llm.chatBot('', '', @collect);
            testCase.assertEmpty(failure);
            testCase.verifyEmpty(testCase.requests());
            bot.chat('hello', true);
            testCase.verifyNumElements(testCase.requests(), 1);
            testCase.verifyEqual(output, "reply from fixture-deepseek");
            testCase.verifyNumElements(bot.messageHistory.Messages, 2);
            function collect(token), output = output + string(token); end
        end

        function unsupportedToolsKeepTheSamePromptAndConfiguration(testCase)
            output = "";
            [bot, failure] = kssolv.services.llm.chatBot('', '', @collect);
            testCase.assertEmpty(failure);
            for prompt = ["reject tools", "reject tools 422"]
                before = numel(testCase.requests());
                output = "";
                bot.chat(prompt, true);
                requests = testCase.requests();
                calls = requests(before + 1:end);
                testCase.verifyNumElements(calls, 2);
                testCase.verifyEqual([calls.tools], [true, false]);
                testCase.verifyEqual(calls(1).messages, calls(2).messages);
                testCase.verifyEqual(string(calls(1).model), "fixture-deepseek");
                testCase.verifyEqual(calls(1).model, calls(2).model);
                testCase.verifyEqual(calls(1).path, calls(2).path);
                testCase.verifyEqual(output, "reply from fixture-deepseek");
            end
            testCase.verifyNumElements(bot.messageHistory.Messages, 4);
            function collect(token), output = output + string(token); end
        end

        function authenticationRateLimitsAndMalformedToolsAreNotRetried(testCase)
            [bot, failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            for prompt = ["unauthorized", "limited", "invalid tools"]
                before = numel(testCase.requests());
                testCase.verifyError(@() bot.chat(prompt, true), 'llms:apiReturnedError');
                testCase.verifyNumElements(testCase.requests(), before + 1);
                testCase.verifyEmpty(bot.messageHistory.Messages);
            end
        end

        function incompleteStreamsNeverReplayOrCommitThePartialTurn(testCase)
            output = "";
            [bot, failure] = kssolv.services.llm.chatBot('', '', @collect);
            testCase.assertEmpty(failure);
            testCase.verifyError(@() bot.chat('truncated', true), 'KSSOLV:LLM:IncompleteStream');
            testCase.verifyEqual(output, "reply from fixture-deepseek");
            testCase.verifyNumElements(testCase.requests(), 1);
            testCase.verifyEmpty(bot.messageHistory.Messages);
            function collect(token), output = output + string(token); end
        end
    end
    methods (Access = private)
        function calls = requests(testCase)
            result = webread(string(getenv('KSSOLV_TEST_CHAT_API')) + '/calls');
            calls = result.calls;
            if isempty(calls), return, end
            calls = calls(startsWith(string({calls.path}), ...
                extractAfter(testCase.Endpoint, string(getenv('KSSOLV_TEST_CHAT_API')))));
        end
    end
end
