classdef ChatBot < kssolv.services.llm.internal.AbstractChatBot
    %CHATBOT 基于在线的大语言模型实现对话功能

    % 此类依赖 MathWorks 发布的 Large Language Models with MATLAB 工具
    %  - https://github.com/matlab-deep-learning/llms-with-matlab

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    methods
        function this = ChatBot(modelName, systemPrompt, streamFunction)
            %CHATBOT 构造函数，构造对话机器人对象
            arguments
                modelName (1, 1) string = "gpt-5-mini"
                systemPrompt (1, 1) string = ""
                streamFunction (1, 1) function_handle = @(token) fprintf("%s\n", token)
            end

            this@kssolv.services.llm.internal.AbstractChatBot('openAIChat', modelName, systemPrompt, streamFunction);
        end
    end

    methods (Access = protected)
        function buildChatBot(this)
            tools = openAIFunction.empty;
            if ismember('tools', this.modelCapabilities)
                tools = this.toolsList;
            end
            this.bot = ...
                kssolv.services.llm.online.ChatBot.createClient( ...
                this.systemPrompt, this.modelName, ...
                this.streamFunction, tools);
        end
    end

    methods (Static)
        function bot = createClient(systemPrompt, modelName, streamFunction, tools)
            %CREATECLIENT 使用 KSSOLV 设置创建 OpenAI 兼容客户端。
            arguments
                systemPrompt (1, 1) string = ""
                modelName (1, 1) string = "gpt-5-mini"
                streamFunction = []
                tools (1, :) {mustBeA(tools, "openAIFunction")} = ...
                    openAIFunction.empty
            end

            settings = kssolv.settings.Settings.load();
            kssolv.settings.Environment.apply(settings);

            if isempty(streamFunction)
                bot = openAIChat(systemPrompt, ...
                    ModelName=modelName, Temperature=0.6, ...
                    Tools=tools, BaseURL=settings.OpenAIBaseURL, ...
                    APIKey=settings.OpenAIAPIKey);
            else
                bot = openAIChat(systemPrompt, ...
                    ModelName=modelName, Temperature=0.6, ...
                    StreamFun=streamFunction, Tools=tools, ...
                    BaseURL=settings.OpenAIBaseURL, ...
                    APIKey=settings.OpenAIAPIKey);
            end
        end
    end
end
