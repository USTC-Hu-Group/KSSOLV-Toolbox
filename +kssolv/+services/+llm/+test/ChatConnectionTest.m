classdef ChatConnectionTest < matlab.unittest.TestCase
    properties
        Endpoint
    end
    methods (TestMethodSetup)
        function isolateConfiguration(testCase)
            endpoint = string(getenv('KSSOLV_TEST_CHAT_API'));
            testCase.assumeNotEmpty(char(endpoint));
            testCase.Endpoint = endpoint + "/" + string(matlab.lang.internal.uuid);
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            values = {'KSSOLV_ONLINE','true'; 'KSSOLV_USER_DATA_DIR',folder.Folder; ...
                'KSSOLV_LOCALE','en_US'; 'OPENAI_API_KEY','fixture-only'};
            for index = 1:size(values,1)
                testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture( ...
                    values{index,1}, values{index,2}));
            end
            kssolv.settings.Preferences.write(struct('LLMType','OpenAICompatible', ...
                'OpenAIBaseURL',testCase.Endpoint,'OpenAIModel','fixture-deepseek'));
        end
    end
    methods (Test)
        function firstPromptHasNoHiddenInference(testCase)
            output = "";
            [bot,failure] = kssolv.services.llm.chatBot('', '', @collect);
            testCase.assertEmpty(failure);
            testCase.verifyEmpty(testCase.requests());
            bot.chat('hello', true);
            calls = testCase.requests();
            testCase.verifyNumElements(calls,1);
            testCase.verifyEqual(string(calls.model),"fixture-deepseek");
            testCase.verifyEqual(string(calls.messages.content),"hello");
            testCase.verifyTrue(calls.stream);
            testCase.verifyEqual(output,"reply from fixture-deepseek");
            testCase.verifyEqual(bot.responseModel,"fixture-deepseek");
            testCase.verifyNumElements(bot.messageHistory.Messages,2);
            function collect(text), output = output + string(text); end
        end

        function completedTurnsReleaseWorkerJobs(testCase)
            [bot,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            for index = 1:20, bot.chat('hello',false); end
            testCase.verifyNumElements(testCase.requests(),20);
        end

        function jsonContentIsNotMistakenForAToolCall(testCase)
            [bot,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            bot.chat('JSON reply',true);
            testCase.verifyEqual(string(bot.messageHistory.Messages{2}.content),string('{"answer":42}'));
        end

        function explicitToolRejectionFallsBackWithoutReplayingPartialReplies(testCase)
            [bot,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            bot.chat('reject tools',true);
            calls = testCase.requests();
            testCase.verifyNumElements(calls,2);
            testCase.verifyEqual([calls.tools],[true false]);
            testCase.verifyNumElements(bot.messageHistory.Messages,2);
        end

        function failedAndTruncatedRepliesDoNotCommitHistoryOrRetry(testCase)
            for prompt = ["unauthorized","truncated"]
                preferences = kssolv.settings.Preferences.read();
                preferences.OpenAIBaseURL = testCase.Endpoint + '/' + prompt;
                kssolv.settings.Preferences.write(preferences);
                [bot,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
                testCase.assertEmpty(failure);
                if prompt == "unauthorized", id = 'KSSOLV:LLM:HTTPError';
                else, id = 'KSSOLV:LLM:IncompleteStream'; end
                testCase.verifyError(@() bot.chat(prompt,true),id);
                testCase.verifyEmpty(bot.messageHistory.Messages);
            end
            testCase.verifyNumElements(testCase.requests(),2);
        end

        function uiCallbacksRunWhileWaitingForFirstToken(testCase)
            [bot,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            callbacks = 0;
            monitor = timer('ExecutionMode','fixedSpacing','Period',0.1, ...
                'TimerFcn',@countCallback);
            cleanup = onCleanup(@() delete(monitor));
            start(monitor);
            bot.chat('slow first token',false);
            stop(monitor);
            testCase.verifyGreaterThan(callbacks,5, ...
                'HTTP must service UI/timer callbacks before the first token.');
            testCase.verifyNumElements(testCase.requests(),1);
            function countCallback(~,~), callbacks = callbacks + 1; end
        end

        function endpointModelAndCredentialChangesInvalidateExistingClient(testCase)
            [bot,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            testCase.verifyTrue(bot.matchesSettings());
            preferences = kssolv.settings.Preferences.read();
            preferences.OpenAIModel = 'fixture-new';
            preferences.OpenAIBaseURL = testCase.Endpoint + '/other';
            kssolv.settings.Preferences.write(preferences);
            testCase.verifyFalse(bot.matchesSettings());
            bot.setStreamFunction(@(~) []);
            testCase.verifyEqual(bot.bot.ModelName,"fixture-deepseek");
            testCase.verifyEqual(bot.bot.BaseURL,testCase.Endpoint);
            [replacement,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            testCase.verifyTrue(replacement.matchesSettings());
            replacement.chat('new configuration',false);
            calls = testCase.requests();
            testCase.verifyNumElements(calls,1);
            testCase.verifyEqual(string(calls.model),"fixture-new");
            testCase.verifyEqual(string(calls.path),extractAfter(testCase.Endpoint,string(getenv('KSSOLV_TEST_CHAT_API'))) + '/other/chat/completions');
            setenv('OPENAI_API_KEY','changed-fixture-only');
            testCase.verifyFalse(replacement.matchesSettings());
        end

        function toolsExecuteOnActualTurnWithoutAProbe(testCase)
            [bot,failure] = kssolv.services.llm.chatBot('', '', @(~) []);
            testCase.assertEmpty(failure);
            entry = bot.registry('getCurrentGraph');
            entry.invoke = @() struct('fixture',true);
            bot.registry('getCurrentGraph') = entry;
            bot.chat('use fixture tool',true);
            calls = testCase.requests();
            testCase.verifyNumElements(calls,2);
            testCase.verifyTrue(all([calls.tools]));
            messages = bot.messageHistory.Messages;
            testCase.verifyNumElements(messages,4);
            testCase.verifyEqual(string(messages{3}.role),"tool");
            testCase.verifySubstring(string(messages{3}.content),'fixture');
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
