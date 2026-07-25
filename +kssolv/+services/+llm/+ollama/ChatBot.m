classdef ChatBot < kssolv.services.llm.internal.AbstractChatBot
    %CHATBOT 基于部署在本地 Ollama™ 中的大语言模型实现对话功能

    % 此类依赖 MathWorks 发布的 Large Language Models with MATLAB 工具
    %  - https://github.com/matlab-deep-learning/llms-with-matlab

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    methods
        function this = ChatBot(modelName, systemPrompt, streamFunction)
            %CHATBOT 构造函数，构造对话机器人对象
            arguments
                modelName (1, 1) string = "deepseek-r1:7b"
                systemPrompt (1, 1) string = ""
                streamFunction (1, 1) function_handle = @(token) fprintf("%s\n", token)
            end

            this@kssolv.services.llm.internal.AbstractChatBot('ollamaChat', modelName, systemPrompt, streamFunction);
        end
    end

    methods (Access = protected)
        function buildChatBot(this)
            settings = kssolv.settings.Settings.load();
            endpoint = settings.OllamaServerURL;

            if ismember('tools', this.modelCapabilities)
                this.systemPrompt = strcat(this.systemPrompt, ...
                    "Always respond to the user, even if the tool's return result is blank.");
                this.bot = ollamaChat(this.modelName, this.systemPrompt, Temperature=0.6, ...
                    StreamFun=this.streamFunction, Tools=this.toolsList, Endpoint=endpoint);
            else
                this.bot = ollamaChat(this.modelName, this.systemPrompt, Temperature=0.6, ...
                    StreamFun=this.streamFunction, Endpoint=endpoint);
            end
        end
    end
end
