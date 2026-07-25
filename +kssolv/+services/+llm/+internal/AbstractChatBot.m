classdef AbstractChatBot < kssolv.services.llm.internal.tools
    %ABSTRACTCHATBOT 基于大语言模型实现对话功能的抽象类

    % 此类依赖 MathWorks 发布的 Large Language Models with MATLAB 工具
    %  - https://github.com/matlab-deep-learning/llms-with-matlab

    % 开发者：杨柳
    % 版权 2025-2026 合肥瀚海量子科技有限公司

    properties
        bot (1, 1) % 对话机器人对象
        modelName (1, 1) string % 所使用的 LLM 模型的名称
        modelCapabilities (:, 1) cell % 所使用的大语言模型的能力，例如支持函数调用等
        systemPrompt (1, 1) string % 系统提示词
        streamFunction (1, 1) % 流式传输函数
        messageHistory (1, 1) % 对话消息历史记录
    end

    properties (Access = protected)
        chatType % "ollamaChat" 或 "openAIChat"
    end

    methods (Abstract, Access = protected)
        buildChatBot(this) % 使用 ollamaChat 或 openAIChat 实例化对话机器人
    end

    methods
        function this = AbstractChatBot(chatType, modelName, systemPrompt, streamFunction)
            %CHATBOT 构造函数，构造对话机器人对象
            arguments
                chatType char {mustBeMember(chatType, {'ollamaChat', 'openAIChat'})} = 'openAIChat'
                modelName (1, 1) string = "gpt-5-mini"
                systemPrompt (1, 1) string = ""
                streamFunction (1, 1) function_handle = @(token) fprintf("%s\n", token)
            end

            this.chatType = chatType;
            this.modelName = modelName;
            this.systemPrompt = systemPrompt;
            this.streamFunction = streamFunction;
            this.messageHistory = messageHistory();

            if ~kssolv.services.llm.isLLMWithMATLABAddonAvailable(chatType)
                error('KSSOLV:LLM:AddonUnavailable', ...
                    'The Large Language Models with MATLAB Add-On is unavailable.');
            end

            getModelCapabilities(this);
            buildChatBot(this);
        end

        function chat(this, promptHistory, useHistoryMessages)
            %CHAT 进行一次对话，可选择是否使用对话历史记录作为上下文
            arguments
                this
                promptHistory (1, 1) string = "你是谁？"
                useHistoryMessages (1, 1) logical = true
            end

            if ~kssolv.services.llm.isLLMWithMATLABAddonAvailable( ...
                    this.chatType)
                error('KSSOLV:LLM:AddonUnavailable', ...
                    'The Large Language Models with MATLAB Add-On is unavailable.');
            end

            % 将本次用户的 prompt 保存到历史消息中
            if useHistoryMessages
                this.messageHistory = addUserMessage(this.messageHistory, promptHistory);
                promptHistory = this.messageHistory;
            else
                tempMessageHistory = addUserMessage(messageHistory(), promptHistory); %#ok<CPROPLC>
                promptHistory = tempMessageHistory;
            end

            try
                % 携带所有历史消息获取 LLM 的响应消息
                [~, message, response] = generate(this.bot, promptHistory, MaxNumTokens=Inf);
            catch ME
                buildChatBot(this);
                [~, message, response] = generate(this.bot, promptHistory, MaxNumTokens=Inf);
            end

            % 将 LLM 的响应消息保存到历史消息中
            promptHistory = addResponseMessage(promptHistory, message);

            if response.StatusCode == "OK" && ...
                    ismember('tools', this.modelCapabilities)
                maxToolCallRounds = 8;
                toolCallRound = 0;

                while isfield(message, 'tool_calls') && ...
                        ~isempty(message.tool_calls)
                    toolCallRound = toolCallRound + 1;
                    if toolCallRound > maxToolCallRounds
                        error("KSSOLV:LLM:TooManyToolCallRounds", ...
                            "The model exceeded %d consecutive tool-call rounds.", ...
                            maxToolCallRounds);
                    end

                    functionCalls = message.tool_calls;
                    if iscell(functionCalls)
                        functionCalls = [functionCalls{:}];
                    end

                    for i = 1:numel(functionCalls)
                        functionCall = functionCalls(i);
                        functionId = "";
                        if isfield(functionCall, "id")
                            functionId = string(functionCall.id);
                        end

                        functionResult = this.functionCallAttempt(functionCall);
                        promptHistory = addToolMessage(promptHistory, ...
                            functionId, functionCall.function.name, functionResult);
                    end

                    [~, message, ~] = generate(this.bot, promptHistory, ...
                        MaxNumTokens=Inf);
                    promptHistory = addResponseMessage(promptHistory, message);
                end
            end

            if useHistoryMessages
                this.messageHistory = promptHistory;
            end
        end

        function showMessageHistory(this, filterThinkContent)
            %SHOWMESSAGEHISTORY 展示全部对话历史记录
            % filterThinkContent: 是否不输出思考部分内容，默认为 true
            arguments
                this
                filterThinkContent (1, 1) logical = true
            end

            if isempty(this.messageHistory.Messages)
                return
            end

            for i = 1:length(this.messageHistory.Messages)
                message = this.messageHistory.Messages{1, i};
                content = message.content;

                if filterThinkContent
                    % 使用正则表达式移除 <think> 标签中的内容，并移除多余的空行
                    content = regexprep(message.content, '<think>.*?</think>\s*', '');
                    content = regexprep(content, '^\s*\n', '');
                    fprintf("[%s] %s\n", message.role, content);
                else
                    fprintf("[%s]\n%s\n", message.role, content);
                end
            end
        end

        function getModelCapabilities(this)
            %GETMODELCAPABILITIES 获取模型的能力
            if strcmp(this.chatType, 'ollamaChat')
                % 本地 Ollama 模型
                try
                    settings = kssolv.settings.Settings.load();
                    ollamaEndpoint = settings.OllamaServerURL;
                    ollamaEndpoint = strip(ollamaEndpoint, 'right', '/');
                    url = ollamaEndpoint + "/api/show";
                    options = weboptions("Timeout", 30, "ContentType", "json");
                    response = webwrite(url, struct("name", this.modelName), options);
                    this.modelCapabilities = response.capabilities;
                catch
                    this.modelCapabilities = {};
                end
                return
            end

            % 探测 OpenAI 兼容模型的能力。
            settings = kssolv.settings.Settings.load();
            if strlength(settings.OpenAIAPIKey) == 0
                error("KSSOLV:LLM:NonExistOpenAIAPIKey", "OPENAI_API_KEY is not set, unable to get model information from OpenAI style agent.");
            end

            try
                % 能力探测失败不应阻止基础聊天客户端初始化。
                tempBot = ...
                    kssolv.services.llm.online.ChatBot.createClient( ...
                    this.systemPrompt, this.modelName, [], this.toolsList);
                generate(tempBot, "Hi", MaxNumTokens=Inf);
                this.modelCapabilities = {'tools'};
            catch
                this.modelCapabilities = {};
            end
        end
    end

    methods (Access = private)
        function functionCall = processResponseData(~, responseData)
            % [Unused]
            % 如果存在工具函数调用响应，则尝试调用相应的工具函数
            functionCall = [];
            if isstruct(responseData)
                data = responseData;
                if isfield(data, 'message') && isfield(data.message, 'tool_calls')
                    functionCall = data.message.tool_calls;
                end
            elseif iscell(responseData)
                data = responseData{1, 1};
                if isfield(data, 'message') && isfield(data.message, 'tool_calls')
                    functionCall = data.message.tool_calls;
                end
            elseif isa(responseData, 'uint8') && iscolumn(responseData)
                % 如果 responseData 是 nx1 的 uint8 数组，即流式传输数据
                lines = splitlines(char(responseData'));

                for i = 1:length(lines)
                    line = strtrim(lines{i});

                    if isempty(line)
                        continue;
                    end

                    if startsWith(line, 'data:')
                        % 提取 "data: " 后面的 JSON 部分
                        jsonString = strip(extractAfter(line, 'data:'));

                        % [DONE] 是结束标志
                        if strcmp(jsonString, '[DONE]')
                            break
                        end

                        % 解码 JSON 字符串为 MATLAB 结构体
                        try
                            dataStruct = jsondecode(jsonString);
                        catch ME
                            fprintf('Warning: JSON decoding failed, content: "%s". Error: %s\n', jsonString, ME.message);
                            continue;
                        end

                        % 提取并拼接内容
                        if isfield(dataStruct, 'choices') && ~isempty(dataStruct.choices)
                            choice = dataStruct.choices(1); % 通常只关心第一个 choice
                            if isfield(choice, 'delta') && isfield(choice.delta, 'tool_calls')
                                functionCall = choice.delta.tool_calls;
                                return
                            end

                            % 检查结束原因
                            if isfield(choice, 'finish_reason') && ~isempty(choice.finish_reason)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end
