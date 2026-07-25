classdef Environment
    %ENVIRONMENT KSSOLV 进程环境变量和 .env 文件的访问边界。
    %
    % 该类只负责读取、写入和解析进程环境。用户首选项、默认值、缓存及
    % 配置合并由 kssolv.settings.Settings 负责。

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    methods (Static)
        function environment = read()
            %READ 返回当前进程环境的结构化只读快照。
            kssolv.settings.Environment.ensureLoaded();

            hostInBrowser = string(strtrim(getenv('KSSOLV_HOST_IN_BROWSER')));

            environment = struct( ...
                'HostInBrowser', ...
                kssolv.settings.Environment.parseBoolean(hostInBrowser), ...
                'Locale', string(strtrim(getenv('KSSOLV_LOCALE'))), ...
                'LLMType', string(strtrim(getenv('KSSOLV_LLM_TYPE'))), ...
                'LLMModel', string(strtrim(getenv('KSSOLV_LLM_MODEL'))), ...
                'OllamaServerURL', string(strtrim( ...
                getenv('KSSOLV_OLLAMA_ENDPOINT'))), ...
                'OpenAIBaseURL', string(strtrim(getenv('OPENAI_PROXY_URL'))), ...
                'OpenAIAPIKey', string(getenv('OPENAI_API_KEY')), ...
                'OpenAIModelList', string(strtrim(getenv('OPENAI_MODEL_LIST'))));
        end

        function apply(settings)
            %APPLY 将完整设置同步到当前 MATLAB 进程环境。
            requiredFields = { ...
                'Locale', 'LLMType', 'OllamaServerURL', 'OllamaModel', ...
                'OpenAIBaseURL', 'OpenAIModel', 'OpenAIModels'};
            if ~isstruct(settings) || ~isscalar(settings) || ...
                    ~all(isfield(settings, requiredFields))
                error('KSSOLV:Settings:InvalidEnvironmentSettings', ...
                    'A complete scalar settings structure is required.');
            end

            setenv('KSSOLV_LOCALE', char(string(settings.Locale)));
            setenv('KSSOLV_LLM_TYPE', char(string(settings.LLMType)));
            setenv('KSSOLV_OLLAMA_ENDPOINT', char(string(settings.OllamaServerURL)));
            setenv('OPENAI_PROXY_URL', char(string(settings.OpenAIBaseURL)));

            if isfield(settings, 'OpenAIAPIKey')
                setenv('OPENAI_API_KEY', char(string(settings.OpenAIAPIKey)));
            end

            if strcmpi(string(settings.LLMType), 'OpenAICompatible')
                selectedModel = string(settings.OpenAIModel);
            else
                selectedModel = string(settings.OllamaModel);
            end
            setenv('KSSOLV_LLM_MODEL', char(selectedModel));

            openAIModels = unique([string(settings.OpenAIModels(:)); ...
                string(settings.OpenAIModel)], 'stable');
            openAIModels = strip(openAIModels);
            openAIModels(strlength(openAIModels) == 0) = [];
            setenv('OPENAI_MODEL_LIST', char(join(openAIModels, ',')));
        end

        function value = hostInBrowser()
            %HOSTINBROWSER 返回统一解析后的浏览器托管开关。
            environment = kssolv.settings.Environment.read();
            value = environment.HostInBrowser;
        end
    end

    methods (Static, Access = private)
        function ensureLoaded()
            % 仅首次访问进程环境时加载项目 .env 文件。
            persistent isEnvironmentLoaded
            if ~isempty(isEnvironmentLoaded) && isEnvironmentLoaded
                return
            end

            envFilePath = fullfile(KSSOLV_Toolbox.RootDirectory, '.env');
            if ~isdeployed && isfile(envFilePath)
                loadenv(envFilePath);
            end
            isEnvironmentLoaded = true;
        end

        function value = parseBoolean(rawValue)
            rawValue = lower(strip(string(rawValue)));
            value = isscalar(rawValue) && ...
                ismember(rawValue, ["1", "true", "yes", "on"]);
        end
    end
end
