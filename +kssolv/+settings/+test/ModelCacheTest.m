classdef ModelCacheTest < matlab.unittest.TestCase
    % Discovered lists remain authoritative when settings are reopened.
    properties
        Endpoint
    end
    methods (TestClassSetup)
        function isolateUserSettings(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            values = {'KSSOLV_ONLINE','true'; 'KSSOLV_USER_DATA_DIR',folder.Folder; ...
                'KSSOLV_LOCALE','en_US'; 'OPENAI_MODEL_LIST','gpt-5-mini'};
            for index = 1:size(values,1)
                testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture( ...
                    values{index,1}, values{index,2}));
            end
        end
    end
    methods (TestMethodSetup)
        function configureEndpoint(testCase)
            testCase.Endpoint = "https://models.example.invalid/" + string(matlab.lang.internal.uuid);
            kssolv.settings.Preferences.write(struct('LLMType','OpenAICompatible', ...
                'OpenAIBaseURL',testCase.Endpoint,'OpenAIModel','gpt-5-mini', ...
                'OllamaServerURL',testCase.Endpoint,'OllamaModel','deepseek-r1:7b'));
        end
    end
    methods (Test)
        function discoveredModelsReplaceStaleDefaultAndEnvironmentList(testCase)
            models = {'deepseek-flash','deepseek-v4-pro'};
            kssolv.settings.Settings.cacheModels('OpenAICompatible',testCase.Endpoint,models);
            settings = kssolv.settings.Settings.load();
            testCase.verifyEqual(settings.OpenAIModels,models);
            testCase.verifyEqual(settings.OpenAIModel,"deepseek-flash");
        end

        function availableSavedSelectionIsKeptWithoutAddingModels(testCase)
            models = {'deepseek-flash','deepseek-v4-pro'};
            preferences = kssolv.settings.Preferences.read();
            preferences.OpenAIModel = 'deepseek-v4-pro';
            kssolv.settings.Preferences.write(preferences);
            kssolv.settings.Settings.cacheModels('OpenAICompatible',testCase.Endpoint,models);
            settings = kssolv.settings.Settings.load();
            testCase.verifyEqual(sort(settings.OpenAIModels),sort(models));
            testCase.verifyEqual(settings.OpenAIModel,"deepseek-v4-pro");
        end

        function aDifferentEndpointDoesNotUseTheDiscoveredList(testCase)
            kssolv.settings.Settings.cacheModels('OpenAICompatible', ...
                testCase.Endpoint + "/other",{'deepseek-flash'});
            settings = kssolv.settings.Settings.load();
            testCase.verifyEqual(settings.OpenAIModels,{'gpt-5-mini'});
            testCase.verifyEqual(settings.OpenAIModel,"gpt-5-mini");
        end

        function ollamaAlsoDropsAnUnavailableDefault(testCase)
            models = {'local-chat:latest','local-code:latest'};
            kssolv.settings.Settings.cacheModels('Ollama',testCase.Endpoint,models);
            settings = kssolv.settings.Settings.load();
            testCase.verifyEqual(settings.OllamaModels,models);
            testCase.verifyEqual(settings.OllamaModel,"local-chat:latest");
        end
    end
end
