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
                this.streamFunction, tools, this.Configuration);
        end
    end

    methods (Static)
        function bot = createClient(systemPrompt, modelName, streamFunction, tools, configuration)
            %CREATECLIENT 使用 KSSOLV 设置创建 OpenAI 兼容客户端。
            arguments
                systemPrompt (1, 1) string = ""
                modelName (1, 1) string = "gpt-5-mini"
                streamFunction = []
                tools (1, :) {mustBeA(tools, "openAIFunction")} = ...
                    openAIFunction.empty
                configuration (1,1) struct = ...
                    kssolv.services.llm.internal.chatConfiguration()
            end

            useWorker = strlength(getenv('KSSOLV_HTTP_WORKER_URL')) > 0;
            if isempty(streamFunction) || useWorker
                bot = openAIChat(systemPrompt, ...
                    ModelName=modelName, Temperature=0.6, ...
                    Tools=tools, BaseURL=configuration.Endpoint, ...
                    APIKey=configuration.APIKey, TimeOut=30);
            else
                bot = openAIChat(systemPrompt, ...
                    ModelName=modelName, Temperature=0.6, ...
                    StreamFun=streamFunction, Tools=tools, ...
                    BaseURL=configuration.Endpoint, ...
                    APIKey=configuration.APIKey, TimeOut=30);
            end
            if useWorker
                % The worker streams tokens and returns a structured final
                % message. Let the Add-On read that message directly rather
                % than guessing whether JSON text represents tool calls.
                bot.sendRequestFcn = @(parameters,token,endpoint,timeout,~) ...
                    kssolv.services.llm.online.internal.sendRequest( ...
                        parameters,token,endpoint,timeout,streamFunction);
            else
                transport = bot.sendRequestFcn;
                bot.sendRequestFcn = @(parameters,token,endpoint,timeout,callback) ...
                    kssolv.services.llm.online.internal.sendNativeRequest( ...
                        parameters,token,endpoint,timeout,callback,transport);
            end
        end
    end
end
