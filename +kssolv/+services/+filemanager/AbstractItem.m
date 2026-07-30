classdef AbstractItem < matlab.mixin.SetGet
    %ABSTRACTITEM 项目文件树中节点的抽象定义

    %   开发者：杨柳
    %   版权 2024 合肥瀚海量子科技有限公司

    properties
        name            % 代码自动生成的唯一的节点名，不允许修改
        label           % 向用户展示的节点名，允许用户设置和修改
        description     % 节点描述
        type            % 节点类型
        children        % 子节点
    end

    properties (Dependent)
        childrenCount   % 子节点数量
    end

    properties (Hidden)
        % 当类的实例被编码为 JSON 时，设置为 Hidden 属性的成员可以避免被编码
        data            % 节点数据
        createdAt       % 创建时间
        updatedAt       % 更新时间
        parent          % 父节点
    end

    properties (Hidden, Dependent)
        category        % 节点类别，如 Structure 或 Workflow
    end

    methods
        function this = AbstractItem(label, type)
            %ABSTRACTITEM 构造函数，构建空的节点
            arguments
                label string = "DefaultItem"
                type  string = "Data"
            end

            if strcmp(type, 'Folder')
                this.name = sprintf('%s(%s)', label, char(matlab.lang.internal.uuid));
            else
                this.name = sprintf('%s(%s)', type, char(matlab.lang.internal.uuid));
            end
            this.label = label;
            this.description = "None";
            this.type = type;
            this.createdAt = datetime;
            this.updatedAt = datetime;
            this.parent = [];
            this.children = {};
        end

        function output = get.childrenCount(this)
            output = sprintf('%dx%d', size(this.children, 1), size(this.children, 2));
        end

        function output = get.category(this)
            if this.type == "Folder" || this.type == "Project"
                output = strtok(this.name, '(');
            elseif ~isempty(this.parent) && this.parent.type == "Folder"
                output = strtok(this.parent.name, '(');
            else
                output = "";
            end
        end

        function addChildrenItem(this, childrenItem)
            %ADDCHILDRENITEM 将 childrenItem 类追加到 data 数组中
            arguments
                this
                childrenItem kssolv.services.filemanager.AbstractItem
            end
            childrenItem.parent = this;
            this.children{end+1, 1} = childrenItem;
            this.updatedAt = datetime;
            projectItem = this.findProjectItem();
            projectItem.isDirty = true;
        end

        function foundItem = findChildrenItem(this, nameOrLabel)
            %FINDCHILDRENITEM 在当前节点及其子节点中查找具有特定名称或标签的项
            arguments
                this
                nameOrLabel string
            end

            % 检查当前节点是否匹配名称或标签
            if this.name == nameOrLabel || this.label == nameOrLabel
                foundItem = this;
                return;
            end

            % 在子节点中递归查找
            for i = 1:length(this.children)
                foundItem = this.children{i, 1}.findChildrenItem(nameOrLabel);
                if ~isempty(foundItem)
                    return;
                end
            end

            % 如果没有找到则返回空数组
            foundItem = [];
        end

        function removeChildrenItem(this, name)
            %REMOVECHILDRENITEM 遍历查找并移除指定 name 的节点
            arguments
                this
                name string
            end

            childrenLength = length(this.children);
            for i = 1:length(this.children)
                % 如果找到子节点的名称与 itemName 相同，移除并返回
                if strcmp(this.children{i, 1}.name, name)
                    % 从 children 中移除这个子节点
                    this.children = [this.children(1:i-1); this.children(i+1:end)];
                    if isempty(this.children)
                        this.children = {};
                    end
                    this.updatedAt = datetime;
                    % 更新 Project 状态
                    projectItem = this.findProjectItem();
                    projectItem.isDirty = true;
                    return;
                else
                    % 若子节点存在 children 则继续遍历
                    if ~isempty(this.children{i, 1}.children)
                        this.children{i, 1}.removeChildrenItem(name);
                        if length(this.children) < childrenLength
                            % 如果子节点数量减少了，说明已移除，直接返回
                            return;
                        end
                    end
                end
            end
        end

        function setItemProperty(this, property, value)
            %SETITEMPROPERTY 更新当前节点的某个属性的值
            arguments
                this
                property string {mustBeNonempty}
                value string {mustBeNonempty}
            end

            % 检查节点是否存在该属性
            if ~ismember(property, properties(this))
                error('KSSOLV:FileManager:AbstractItem:PropertyNotFound', ...
                    'Unknown property in Item %s: %s', this.name, property);
            end

            if isequal(this.(property), value)
                return
            end

            % 更新属性值和相关信息
            this.(property) = value;
            this.updatedAt = datetime;
            projectItem = this.findProjectItem();
            projectItem.isDirty = true;
        end

        function projectItem = findProjectItem(this)
            %FINDPROJECTITEM 获取作为当前项目树根节点的 Project 节点
            arguments
                this
            end

            currentNode = this;
            while ~isempty(currentNode.parent)
                currentNode = currentNode.parent;
            end

            if strcmp(currentNode.type, 'Project')
                projectItem = currentNode;
            else
                projectItem = [];
            end
        end

        function encodedJSON = encode(this, prettyPrint)
            %ENCODE 将少数字段和 data 字段编码为 JSON
            % 用于 Info Browser
            arguments
                this
                prettyPrint logical = false
            end

            objectStruct = struct('name', this.name, 'label', this.label, ...
                'createdAt', this.createdAt, 'updatedAt', this.updatedAt, ...
                'description', this.description);

            if any(strcmp(this.type, ["Structure", "Volume"]))
                % Structure and Volume expose only their lightweight
                % FileParser projection to the information browser.
                objectStruct.data = this.data;
                if isobject(this.data) && ...
                        ismethod(this.data, "toInfoStruct")
                    objectStruct.data = this.data.toInfoStruct();
                end
            else
                objectStruct.data = [];
            end

            try
                encodedJSON = jsonencode(objectStruct, "PrettyPrint", prettyPrint);
            catch ME
                error('KSSOLV:FileManager:AbstractItem:JSONEncodeError', ...
                    'Error encoding this item to JSON: %s', ME.message);
            end
        end

        function encodedJSON = encodeToJSON(this, prettyPrint)
            %ENCODETOJSON 递归地处理 size 字段，并编码为 JSON
            % 用于 Project Browser

            arguments
                this
                prettyPrint logical = false
            end

            try
                encodedJSON = jsonencode(this, "PrettyPrint", prettyPrint);
            catch ME
                error('KSSOLV:FileManager:AbstractItem:JSONEncodeError', ...
                    'Error encoding the item to JSON: %s', ME.message);
            end
        end
    end
end
