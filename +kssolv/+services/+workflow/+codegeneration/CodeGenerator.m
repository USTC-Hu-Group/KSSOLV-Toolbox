classdef CodeGenerator < handle
    % CODEGENERATOR 分析工作流，通过拓扑排序确定节点的正确执行顺序，并依次执行所有任务

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    methods (Static)
        function executeTasks(workflow, workflowName)
            % executeTasks 按照拓扑顺序执行工作流中的所有任务
            %
            %   执行流程:
            %       1. 重置工作流 UI 中所有节点的状态。
            %       2. 对工作流进行拓扑排序，以确保父节点在子节点之前执行。
            %       3. 按排序顺序迭代执行每个节点的任务。
            %       4. 管理一个上下文(context)，将已完成节点更新的上下文传递给其后续节点。
            %       5. 在执行过程中更新 UI 节点状态（running, success, failed）。
            arguments
                workflow kssolv.services.workflow.WorkflowGraph
                workflowName = 'Default'
            end

            allNodeIDs = keys(workflow.Nodes);

            % 步骤 1: 将所有节点状态重置为默认值
            for i = 1:length(allNodeIDs)
                changeNodeStatus(allNodeIDs{i}, 'default', true);
                pause(0.1);
            end

            % 步骤 2: 对工作流图进行拓扑排序，获取正确的执行顺序
            try
                sortedNodeIDs = kssolv.services.workflow.codegeneration.CodeGenerator.topologicalSort(workflow);
            catch ME
                % 如果排序失败（如存在循环依赖），恢复 UI 并向上抛出异常
                runBrowser = kssolv.ui.util.DataStorage.getData('RunBrowser');
                if ~isempty(runBrowser)
                    runBrowser.restoreButtons();
                end
                throwAsCaller(ME);
            end

            % 步骤 3: 初始化上下文 context
            context = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % 步骤 4: 按照拓扑排序的顺序遍历并执行任务
            for i = 1:length(sortedNodeIDs)
                nodeID = sortedNodeIDs{i};
                node = workflow.Nodes(nodeID);

                % 准备当前节点的输入
                input = containers.Map('KeyType', 'char', 'ValueType', 'any');

                % 执行当前节点的任务
                changeNodeStatus(nodeID, 'running');
                try
                    % executeTask 将当前节点的输出存储到上下文中，供其子节点后续使用
                    context = node.task.executeTask(context, input);
                catch ME
                    changeNodeStatus(nodeID, 'failed');
                    % 任务执行失败时，恢复 UI 状态并抛出异常
                    runBrowser = kssolv.ui.util.DataStorage.getData('RunBrowser');
                    if ~isempty(runBrowser)
                        runBrowser.restoreButtons()
                    end
                    % disp(ME.message);
                    throwAsCaller(ME);
                end

                changeNodeStatus(nodeID, 'success');
            end

            % 步骤 5: 将运行结果存入 Results
            kssolv.services.workflow.codegeneration.CodeGenerator. ...
                storeResults(context, workflowName);
        end

        function context = completeRemoteExecution(workflow, envelope, options)
            %COMPLETEREMOTEEXECUTION Present local nodes and import results.
            arguments
                workflow kssolv.services.workflow.WorkflowGraph
                envelope struct
                options.ResultIdentity (1, 1) string = ""
            end
            required = ["Context", "RemoteNodeIds", "LocalNodeIds", ...
                "WorkflowName"];
            if ~all(isfield(envelope, required)) || ...
                    ~isa(envelope.Context, "containers.Map")
                error("KSSOLV:Workflow:InvalidRemoteEnvelope", ...
                    "The remote workflow result envelope is invalid.");
            end
            context = envelope.Context;
            resultsItem = ...
                kssolv.services.filemanager.Results.getResultsItem();
            existing = resultsItem.findDatasetBySourceIdentity( ...
                options.ResultIdentity);
            if ~isempty(existing)
                context = existing.data;
                return
            end
            for nodeId = string(envelope.RemoteNodeIds(:)).'
                if isKey(workflow.Nodes, char(nodeId))
                    changeNodeStatus(char(nodeId), 'success');
                end
            end
            for nodeId = string(envelope.LocalNodeIds(:)).'
                if ~isKey(workflow.Nodes, char(nodeId))
                    error("KSSOLV:Workflow:RemoteNodeMissing", ...
                        "Workflow node %s no longer exists.", nodeId);
                end
                node = workflow.Nodes(char(nodeId));
                changeNodeStatus(char(nodeId), 'running');
                try
                    if isa(node.task, ...
                            "kssolv.services.workflow.module." + ...
                            "visualization.DOSTask")
                        kssolv.services.workflow.module.visualization. ...
                            DOSTask.presentWithContext(context);
                    else
                        input = containers.Map("KeyType", "char", ...
                            "ValueType", "any");
                        context = node.task.executeTask(context, input);
                    end
                    changeNodeStatus(char(nodeId), 'success');
                catch exception
                    changeNodeStatus(char(nodeId), 'failed');
                    rethrow(exception)
                end
            end
            kssolv.services.workflow.codegeneration.CodeGenerator. ...
                storeResults(context, string(envelope.WorkflowName), ...
                options.ResultIdentity);
        end

        function storeResults(context, workflowName, resultIdentity)
            %STORERESULTS Add a completed execution context to the project.
            arguments
                context containers.Map
                workflowName = "Default"
                resultIdentity (1, 1) string = ""
            end
            resultContext = containers.Map("KeyType", "char", ...
                "ValueType", "any");
            names = keys(context);
            for index = 1:numel(names)
                resultContext(names{index}) = context(names{index});
            end
            if isKey(resultContext, "molecule")
                remove(resultContext, "molecule");
            end
            resultsItem = ...
                kssolv.services.filemanager.Results.getResultsItem();
            [~, created] = resultsItem.addDataset( ...
                resultContext, workflowName, resultIdentity);
            if ~created
                return
            end
            projectBrowser = ...
                kssolv.ui.util.DataStorage.getData("ProjectBrowser");
            projectBrowser.refreshUIAfterItemCreation( ...
                resultsItem.datasetsItem);
        end

        function sortedNodes = topologicalSort(workflow)
            % topologicalSort 使用内置函数对工作流的节点进行拓扑排序，自动处理不连通的子图并检测循环依赖

            arguments
                workflow kssolv.services.workflow.WorkflowGraph
            end

            allNodeIDs = keys(workflow.Nodes);
            if isempty(allNodeIDs)
                sortedNodes = {};
                return;
            end

            sourceEdges = {};
            targetEdges = {};
            for i = 1:length(allNodeIDs)
                parentNodeID = allNodeIDs{i};
                children = workflow.getChildren(parentNodeID);
                for j = 1:length(children)
                    childNodeID = children{j};
                    sourceEdges{end+1} = parentNodeID; %#ok<AGROW>
                    targetEdges{end+1} = childNodeID; %#ok<AGROW>
                end
            end

            try
                G = digraph(sourceEdges, targetEdges, [], allNodeIDs);
            catch ME
                error('KSSOLV:Workflow:CodeGenerator:DigraphError', 'Error creating directed graph: %s', ME.message);
            end

            if hascycles(G)
                error('KSSOLV:Workflow:CodeGenerator:CycleDetected', 'Circular dependency detected in workflow, unable to execute tasks.');
            end

            try
                nodeIndices = toposort(G, "Order", "stable");
                sortedNodes = G.Nodes.Name(nodeIndices)'; % 转置为 1xN cell 数组
            catch ME
                error('KSSOLV:Workflow:CodeGenerator:TopologicalSort', ME.message);
            end
        end
    end
end

function changeNodeStatus(nodeID, status, noRefresh)
% 用于向 UI 发送节点状态更新事件
arguments
    nodeID char
    status char {mustBeMember(status, {'default', 'running', 'failed', 'success'})}
    noRefresh logical = false
end

kssolv.ui.components.figuredocument.Workflow.sendEventToWorkflowUI('workflowUpdateNodeStatus', ...
    struct('nodeID', nodeID, 'newStatus', status));
if ~noRefresh
    pause(0.1); % 给予 UI 足够的时间来响应和刷新
end
end
