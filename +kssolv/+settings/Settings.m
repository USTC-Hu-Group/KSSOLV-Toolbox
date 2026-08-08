classdef Settings
    %SETTINGS KSSOLV 用户设置的持久化、缓存读取和配置合并。
    %
    % 稳定的用户选择保存到 MATLAB preferences。服务端模型列表属于可
    % 丢弃数据，保存到 Cache，并按服务类型、端点和有效期进行校验。

    % 开发者：杨柳
    % 版权 2025-2026 合肥瀚海量子科技有限公司

    properties (Constant, Access = private)
        PreferenceGroup = 'KSSOLVToolbox'
        ModelCacheTTLDays = 7
    end

    methods (Static)
        function settings = load()
            %LOAD 合并 preferences、部署环境和有效的模型列表缓存。
            settings = kssolv.settings.Settings.defaults();
            environment = kssolv.settings.Environment.read();

            preferenceNames = { ...
                'Locale', 'LLMType', 'OllamaServerURL', 'OllamaModel', ...
                'OpenAIBaseURL', 'OpenAIModel'};
            for i = 1:numel(preferenceNames)
                name = preferenceNames{i};
                if ispref(kssolv.settings.Settings.PreferenceGroup, name)
                    settings.(name) = getpref( ...
                        kssolv.settings.Settings.PreferenceGroup, name);
                end
            end

            % 普通环境变量仅在对应首选项尚未保存时生效。API Key 优先
            % 读取用户在设置对话框中保存的加密副本，环境变量仅作为
            % 回退；绝不以明文写入 preferences 或 Cache。
            settings.Locale = ...
                kssolv.settings.Settings.valueFromEnvironmentWhenUnset( ...
                'Locale', settings.Locale, environment.Locale);
            settings.LLMType = ...
                kssolv.settings.Settings.valueFromEnvironmentWhenUnset( ...
                'LLMType', settings.LLMType, environment.LLMType);
            settings.OllamaServerURL = ...
                kssolv.settings.Settings.valueFromEnvironmentWhenUnset( ...
                'OllamaServerURL', settings.OllamaServerURL, ...
                environment.OllamaServerURL);
            settings.OpenAIBaseURL = ...
                kssolv.settings.Settings.valueFromEnvironmentWhenUnset( ...
                'OpenAIBaseURL', settings.OpenAIBaseURL, environment.OpenAIBaseURL);
            storedAPIKey = ...
                kssolv.settings.EncryptedStore.readOpenAIAPIKey();
            if strlength(storedAPIKey) > 0
                settings.OpenAIAPIKey = storedAPIKey;
            else
                settings.OpenAIAPIKey = environment.OpenAIAPIKey;
            end
            storedMaterialsProjectAPIKey = kssolv.settings.EncryptedStore. ...
                readMaterialsProjectAPIKey();
            if strlength(storedMaterialsProjectAPIKey) > 0
                settings.MaterialsProjectAPIKey = ...
                    storedMaterialsProjectAPIKey;
            else
                settings.MaterialsProjectAPIKey = ...
                    environment.MaterialsProjectAPIKey;
            end

            runtimeModel = environment.LLMModel;
            if strlength(runtimeModel) > 0
                if strcmpi(settings.LLMType, 'OpenAICompatible')
                    settings.OpenAIModel = ...
                        kssolv.settings.Settings.valueFromEnvironmentWhenUnset( ...
                        'OpenAIModel', settings.OpenAIModel, runtimeModel);
                else
                    settings.OllamaModel = ...
                        kssolv.settings.Settings.valueFromEnvironmentWhenUnset( ...
                        'OllamaModel', settings.OllamaModel, runtimeModel);
                end
            end

            settings = kssolv.settings.Settings.normalize(settings);
            settings.OllamaModels = ...
                kssolv.settings.Settings.loadCachedModels( ...
                'Ollama', settings.OllamaServerURL, settings.OllamaModel);

            cachedOpenAIModels = ...
                kssolv.settings.Settings.loadCachedModels( ...
                'OpenAICompatible', settings.OpenAIBaseURL, settings.OpenAIModel);
            environmentModels = environment.OpenAIModelList;
            if strlength(environmentModels) > 0
                settings.OpenAIModels = ...
                    kssolv.settings.Settings.normalizeModelList( ...
                    [strip(split(environmentModels, ',')); ...
                    string(cachedOpenAIModels(:))], settings.OpenAIModel);
            else
                settings.OpenAIModels = cachedOpenAIModels;
            end
            settings = kssolv.settings.Settings.normalize(settings);
        end

        function url = openAIChatCompletionsURL()
            %OPENAICHATCOMPLETIONSURL 返回兼容 Chat Completions 的完整端点。
            settings = kssolv.settings.Settings.load();
            url = char(settings.OpenAIBaseURL + "/chat/completions");
        end

        function save(settings)
            %SAVE 持久化稳定设置，并立即应用到当前 MATLAB 进程。
            settings = kssolv.settings.Settings.normalize(settings);
            kssolv.settings.EncryptedStore.writeOpenAIAPIKey( ...
                settings.OpenAIAPIKey);
            kssolv.settings.EncryptedStore.writeMaterialsProjectAPIKey( ...
                settings.MaterialsProjectAPIKey);
            preferenceNames = { ...
                'Locale', 'LLMType', 'OllamaServerURL', 'OllamaModel', ...
                'OpenAIBaseURL', 'OpenAIModel'};
            for i = 1:numel(preferenceNames)
                name = preferenceNames{i};
                setpref(kssolv.settings.Settings.PreferenceGroup, ...
                    name, settings.(name));
            end

            kssolv.settings.Environment.apply(settings);
        end

        function cacheModels(provider, endpoint, models)
            %CACHEMODELS 缓存一次成功服务探测返回的模型列表。
            provider = validatestring(provider, {'Ollama', 'OpenAICompatible'});
            endpoint = strip(string(endpoint));
            endpoint = strip(endpoint, 'right', '/');
            models = kssolv.settings.Settings.normalizeModelList(models, "");
            if strlength(endpoint) == 0 || isempty(models)
                return
            end

            entry = struct( ...
                'Version', 1, ...
                'Endpoint', char(endpoint), ...
                'Models', {models}, ...
                'ExpiresAt', datetime('now', 'TimeZone', 'UTC') + ...
                days(kssolv.settings.Settings.ModelCacheTTLDays));
            try
                kssolv.services.cache.Cache.set( ...
                    kssolv.settings.Settings.modelCacheKey( ...
                    provider, endpoint), entry);
            catch exception
                warning('KSSOLV:Settings:ModelCacheWriteFailed', ...
                    'Unable to cache the %s model list: %s', ...
                    provider, exception.message);
            end
        end

        function settings = defaults()
            %DEFAULTS 返回一份完整且可直接使用的默认设置。
            settings = struct( ...
                'Locale', "", ...
                'LLMType', "Ollama", ...
                'OllamaServerURL', "http://127.0.0.1:11434", ...
                'OllamaModel', "deepseek-r1:7b", ...
                'OllamaModels', {{'deepseek-r1:7b'}}, ...
                'OpenAIBaseURL', "https://api.openai.com/v1", ...
                'OpenAIAPIKey', "", ...
                'MaterialsProjectAPIKey', "", ...
                'OpenAIModel', "gpt-5-mini", ...
                'OpenAIModels', {{'gpt-5-mini'}});
        end
    end

    methods (Static, Access = private)
        function value = valueFromEnvironmentWhenUnset(name, savedValue, environmentValue)
            if ~ispref(kssolv.settings.Settings.PreferenceGroup, name) && ...
                    strlength(string(strtrim(environmentValue))) > 0
                value = string(strtrim(environmentValue));
            else
                value = savedValue;
            end
        end

        function settings = normalize(settings)
            defaults = kssolv.settings.Settings.defaults();
            names = fieldnames(defaults);
            for i = 1:numel(names)
                name = names{i};
                if ~isfield(settings, name) || isempty(settings.(name))
                    settings.(name) = defaults.(name);
                end
            end

            scalarStringFields = { ...
                'Locale', 'LLMType', 'OllamaServerURL', 'OllamaModel', ...
                'OpenAIBaseURL', 'OpenAIAPIKey', 'OpenAIModel', ...
                'MaterialsProjectAPIKey'};
            for i = 1:numel(scalarStringFields)
                name = scalarStringFields{i};
                value = string(settings.(name));
                if ~isscalar(value)
                    value = value(1);
                end
                settings.(name) = strip(value);
            end

            settings.OllamaServerURL = strip(settings.OllamaServerURL, 'right', '/');
            settings.OpenAIBaseURL = strip(settings.OpenAIBaseURL, 'right', '/');
            settings.OllamaModels = ...
                kssolv.settings.Settings.normalizeModelList( ...
                settings.OllamaModels, settings.OllamaModel);
            settings.OpenAIModels = ...
                kssolv.settings.Settings.normalizeModelList( ...
                settings.OpenAIModels, settings.OpenAIModel);
        end

        function models = normalizeModelList(models, selectedModel)
            models = string(models(:));
            models = strip(models);
            models(strlength(models) == 0) = [];
            models = unique([string(selectedModel); models], 'stable');
            models(strlength(models) == 0) = [];
            models = cellstr(models(:).');
        end

        function models = loadCachedModels(provider, endpoint, selectedModel)
            models = kssolv.settings.Settings.normalizeModelList( ...
                {}, selectedModel);
            key = kssolv.settings.Settings.modelCacheKey(provider, endpoint);
            try
                entry = kssolv.services.cache.Cache.get(key, []);
            catch
                return
            end
            if ~isstruct(entry) || ~isscalar(entry) || ...
                    ~all(isfield(entry, {'Version', 'Endpoint', 'Models', 'ExpiresAt'}))
                return
            end

            endpoint = strip(string(endpoint), 'right', '/');
            if entry.Version ~= 1 || ...
                    ~strcmp(string(entry.Endpoint), endpoint) || ...
                    ~isdatetime(entry.ExpiresAt) || ~isscalar(entry.ExpiresAt) || ...
                    isnat(entry.ExpiresAt) || entry.ExpiresAt <= ...
                    datetime('now', 'TimeZone', 'UTC')
                return
            end
            models = kssolv.settings.Settings.normalizeModelList( ...
                entry.Models, selectedModel);
        end

        function key = modelCacheKey(provider, endpoint)
            endpoint = lower(strip(string(endpoint), 'right', '/'));
            key = ['Settings.Models.' char(provider) '.' char(endpoint)];
        end
    end
end
