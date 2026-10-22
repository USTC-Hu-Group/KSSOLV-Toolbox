classdef WorkflowGraph < handle
    %WORKFLOWGRAPH 从工作流画布中获取的 graphJSON 中解析节点和节点之间的关系

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        Nodes       % 存储节点数据的 Map，键为节点 ID，值为 WorkflowNodeData 类的实例
        Adjacency   % 存储邻接列表的 Map，键为节点 ID，值是包含 'parents' 和 'children' 的结构体
    end

    methods
        function this = WorkflowGraph(graphJSON)
            % 构造函数，使用解码后的 graphJSON 初始化图
            arguments
                graphJSON
            end

            this.Nodes = containers.Map();      % 存储自定义节点数据
            this.Adjacency = containers.Map();  % 存储父子关系

            % 从 graphJSON 添加节点和边
            this.updateFromJSON(graphJSON);
        end

        function updateNode(this, node)
            % 更新已有节点或初始化新的节点
            nodeID = node.id;

            % 如果节点已经存在，更新除 task 外的信息
            if isKey(this.Nodes, nodeID)
                thisNode = this.Nodes(nodeID);
                thisNode.label = node.data.label;
                thisNode.status = node.data.status;
                thisNode.task.resetOptionsUI();
                return
            end

            % 如果节点不存在，则使用 WorkflowNodeData 类初始化节点数据
            task = kssolv.services.workflow.module.computation.SCFTask();
            this.Nodes(nodeID) = kssolv.services.workflow.WorkflowNodeData(node.data.label, node.data.status, task);
        end

        function removeNode(this, nodeID)
            % 移除节点
            if isKey(this.Nodes, nodeID)
                % 从 Nodes 中移除节点
                remove(this.Nodes, nodeID);
            end
        end

        function addEdge(this, edge)
            % 添加边（定义父子关系）
            sourceID = edge.source.cell;
            targetID = edge.target.cell;

            % 将 source 添加为 target 的父节点
            if ~ismember(sourceID, this.Adjacency(targetID).parents)
                target = this.Adjacency(targetID);
                target.parents{end+1} = sourceID;
                this.Adjacency(targetID) = target;
            end

            % 将 target 添加为 source 的子节点
            if ~ismember(targetID, this.Adjacency(sourceID).children)
                source = this.Adjacency(sourceID);
                source.children{end+1} = targetID;
                this.Adjacency(sourceID) = source;
            end
        end

        function removeEdge(this, sourceID, targetID)
            % 移除边（解除父子关系）
            if isKey(this.Adjacency, sourceID) && isKey(this.Adjacency, targetID)
                % 从 source 的子节点列表中删除 target
                this.Adjacency(sourceID).children = setdiff(this.Adjacency(sourceID).children, {targetID}, 'stable');
                % 从 target 的父节点列表中删除 source
                this.Adjacency(targetID).parents = setdiff(this.Adjacency(targetID).parents, {sourceID}, 'stable');
            end
        end

        function parents = getParents(this, nodeID)
            % 获取节点的父节点（上游节点）
            if isKey(this.Adjacency, nodeID)
                parents = this.Adjacency(nodeID).parents;
            else
                parents = {};
            end
        end

        function children = getChildren(this, nodeID)
            % 获取节点的子节点（下游节点）
            if isKey(this.Adjacency, nodeID)
                children = this.Adjacency(nodeID).children;
            else
                children = {};
            end
        end

        function updateNodeData(this, nodeID, newData)
            % 更新节点数据（如标签、状态）
            if isKey(this.Nodes, nodeID)
                % 仅更新节点的相关字段
                fields = fieldnames(newData);
                for i = 1:length(fields)
                    this.Nodes(nodeID).(fields{i}) = newData.(fields{i});
                end
            end
        end

        function updateFromJSON(this, graphJSON)
            % 从 graphJSON 更新图结构
            if isstruct(graphJSON) && isscalar(graphJSON) && isfield(graphJSON, 'cells')
                graphJSONCells = graphJSON.cells;
            else
                graphJSONCells = graphJSON;
            end

            newNodeIDs = {};
            existingNodeIDs = keys(this.Nodes);

            % 重置所有邻接列表
            this.Adjacency = containers.Map();

            % 首先处理节点
            for i = 1:length(graphJSONCells)
                if isstruct(graphJSONCells)
                    cell = graphJSONCells(i);
                else
                    cell = graphJSONCells{i};
                end

                if isfield(cell, 'shape') && strcmp(cell.shape, 'dag-node')
                    this.updateNode(cell);
                    % 初始化该节点的邻接列表
                    this.Adjacency(cell.id) = struct('parents', {{}}, 'children', {{}});
                    % 收集新节点 ID
                    newNodeIDs{end+1} = cell.id; %#ok<AGROW>
                end
            end

            % 重新添加所有的边
            for i = 1:length(graphJSONCells)
                if isstruct(graphJSONCells)
                    cell = graphJSONCells(i);
                else
                    cell = graphJSONCells{i};
                end

                if isfield(cell, 'shape') && strcmp(cell.shape, 'dag-edge')
                    this.addEdge(cell);
                end
            end

            % 移除不再存在的节点
            nodesToRemove = setdiff(existingNodeIDs, newNodeIDs);
            for i = 1:length(nodesToRemove)
                this.removeNode(nodesToRemove{i});
            end
        end
    end
end
