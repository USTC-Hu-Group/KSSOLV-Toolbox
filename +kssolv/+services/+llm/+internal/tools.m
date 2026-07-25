classdef (Abstract) tools < handle
    %TOOLS 将部分 KSSOLV APIs 定义为可以被 LLM 使用的 function tools

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    properties
        toolsList (1, :) {mustBeA(toolsList, "openAIFunction")} = openAIFunction.empty
        registry containers.Map
    end

    methods
        function this = tools()
            %TOOLS 构造函数，构建所有的工具函数并进行注册
            import kssolv.api.v1.*
            this.registry = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % 定义 getCurrentGraph 工具函数
            getCurrentGraphTool = openAIFunction("getCurrentGraph", ...
                "Retrieve the current workflow's information in JSON format");
            % 注册 getCurrentGraph 工具函数
            this.register(getCurrentGraphTool, @() workflow.getCurrentGraph());

            % 定义 changeNodeLabel 工具函数
            changeNodeLabelTool = openAIFunction("changeNodeLabel", ...
                "Change the label of a specified node in the current workflow");
            changeNodeLabelTool = addParameter(changeNodeLabelTool, ...
                "nodeID", type="string", ...
                description="Unique identifier of the node");
            changeNodeLabelTool = addParameter(changeNodeLabelTool, ...
                "newLabel", type="string", ...
                description="New label for the node");
            % 注册 changeNodeLabel 工具函数
            this.register(changeNodeLabelTool, ...
                @(args) workflow.changeNodeLabel(args.nodeID, args.newLabel));
        end

        function register(this, toolFunction, invoker)
            %REGISTER 把相关信息写入 registry
            arguments
                this
                toolFunction (1, 1) openAIFunction
                invoker (1, 1) function_handle
            end

            if ~isKey(this.registry, toolFunction.FunctionName)
                this.registry(toolFunction.FunctionName) = struct("tool", toolFunction, ...
                    "required", toolFunction.Parameters, "invoke", invoker);
                this.toolsList(end + 1) = toolFunction;
            end
        end

        function output = functionCallAttempt(this, functionCall)
            %FUNCTIONCALLATTEMPT 核对函数后，尝试运行被调用的函数
            if ~isstruct(functionCall) || ~isscalar(functionCall) || ...
                    ~isfield(functionCall, "function") || ...
                    ~isstruct(functionCall.function) || ...
                    ~isfield(functionCall.function, "name")
                error("KSSOLV:LLM:ImproperFunctionCalling", ...
                    "The tool call is missing its function name.");
            end

            functionName = char(string(functionCall.function.name));

            % 校验被调用的工具函数的名称
            if ~isKey(this.registry, functionName)
                error("KSSOLV:LLM:NotRegisteredTool", "Function tool “%s” is not registered.", functionName);
            end

            % 获取注册的工具函数
            registeredFunction = this.registry(functionName);
            if ~isempty(registeredFunction)
                parameterNames = fields(registeredFunction.required);
                requiredArguments = {};
                for i = 1:numel(parameterNames)
                    parameter = registeredFunction.required.(parameterNames{i});
                    if ~isfield(parameter, "required") || parameter.required
                        requiredArguments{end + 1} = parameterNames{i}; %#ok<AGROW>
                    end
                end
            else
                output = sprintf("The function “%s” doesn't exist.", functionName);
                return
            end

            % 解析参数并执行工具函数
            if ~isempty(parameterNames)
                if ~isfield(functionCall.function, "arguments")
                    error("KSSOLV:LLM:ImproperFunctionCalling", ...
                        "Function “%s” is missing its arguments.", functionName);
                end

                functionArguments = functionCall.function.arguments;
                if ischar(functionArguments) || ...
                        (isstring(functionArguments) && isscalar(functionArguments))
                    try
                        functionArguments = jsondecode(functionArguments);
                    catch exception
                        error("KSSOLV:LLM:ImproperFunctionCalling", ...
                            "Function “%s” provided invalid JSON arguments: %s", ...
                            functionName, exception.message);
                    end
                end

                if ~isstruct(functionArguments) || ~isscalar(functionArguments)
                    error("KSSOLV:LLM:ImproperFunctionCalling", ...
                        "Function “%s” arguments must be a JSON object or scalar structure.", ...
                        functionName);
                end

                % 校验参数
                if ~all(isfield(functionArguments, requiredArguments))
                    missingArguments = requiredArguments(~isfield(functionArguments, requiredArguments));
                    error("KSSOLV:LLM:ImproperFunctionCalling", ...
                        "Function “%s” is missing required argument(s): %s", ...
                        functionName, strjoin(missingArguments, ", "));
                end

                % 注入参数，执行工具函数
                output = jsonencode(registeredFunction.invoke(functionArguments));
            else
                % 无参数时直接执行工具函数
                output = jsonencode(registeredFunction.invoke());
            end

            output = sprintf("The result of calling the function “%s” is: %s", functionName, output);
        end
    end
end
