function [bot, failure] = chatBot(modelName, systemPrompt, streamFunction)
%CHATBOT 构造对话机器人对象
arguments
    modelName (1, 1) string = ""
    systemPrompt (1, 1) string = ""
    streamFunction (1, 1) function_handle = @(token) fprintf("%s\n", token)
end

bot = [];
failure = [];
settings = kssolv.settings.Settings.load();
kssolv.settings.Environment.apply(settings);
llmType = settings.LLMType;

if strlength(modelName) == 0
    if strcmpi(llmType, "OpenAICompatible")
        modelName = settings.OpenAIModel;
    else
        modelName = settings.OllamaModel;
    end
end

if strcmpi(llmType, "OpenAICompatible")
    if strlength(modelName) == 0 && ~isempty(settings.OpenAIModels)
        availableModels = string(settings.OpenAIModels);
        modelName = availableModels(1);
    elseif strlength(modelName) == 0
        modelName = "gpt-5-mini";
    end

    if strlength(settings.OpenAIBaseURL) == 0 || ...
            strlength(settings.OpenAIAPIKey) == 0
        failure = MException('KSSOLV:LLM:MissingOpenAIConfiguration', ...
            'The OpenAI-compatible service configuration is incomplete.');
        return
    end

    if ~kssolv.services.llm.isLLMWithMATLABAddonAvailable('openAIChat')
        failure = MException('KSSOLV:LLM:AddonUnavailable', ...
            'The Large Language Models with MATLAB Add-On is unavailable.');
        return
    end

    try
        bot = kssolv.services.llm.online.ChatBot(modelName, systemPrompt, streamFunction);
    catch exception
        failure = exception;
    end
else
    if strlength(modelName) == 0
        modelName = "deepseek-r1:7b";
    end
    if ~kssolv.services.llm.isLLMWithMATLABAddonAvailable('ollamaChat')
        failure = MException('KSSOLV:LLM:AddonUnavailable', ...
            'The Large Language Models with MATLAB Add-On is unavailable.');
        return
    end

    try
        bot = kssolv.services.llm.ollama.ChatBot(modelName, systemPrompt, streamFunction);
    catch exception
        failure = exception;
    end
end
end
