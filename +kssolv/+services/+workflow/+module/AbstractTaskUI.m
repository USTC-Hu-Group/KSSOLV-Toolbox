classdef (Abstract) AbstractTaskUI < matlab.mixin.SetGet
    %ABSTRACTTASKUI 任务的选项 UI 的抽象类

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Abstract, Dependent)
        options
    end

    properties (Abstract, Transient)
        widgets
    end

    properties (Access = protected)
        defaultOptions (1, 1) struct
        privateOptions (1, 1) struct
        isDirty (1, 1) logical = false
    end

    events
        OptionsChanged
    end

    methods (Access = protected)
        function this = AbstractTaskUI()
            this.setupDefaultOptions();
            this.setupUI();
        end

        function markDirty(this)
            this.isDirty = true;
            notify(this, 'OptionsChanged');
            project = kssolv.ui.util.DataStorage.getData('Project');
            if ~isempty(project)
                project.isDirty = true;
            end
        end
    end

    methods (Abstract, Access = protected)
        setupDefaultOptions(this)
        setup(this, options);
    end

    methods (Abstract)
        attachUIToAccordion(this, accordion)
        detachUIFromAccordion(this)
    end

    methods
        function value = getOptionsSnapshot(this)
            % Loaded tasks remain usable before their transient UI is built.
            if ~isempty(this.widgets)
                value = this.options;
            elseif ~isempty(fieldnames(this.privateOptions))
                value = this.privateOptions;
            else
                value = this.defaultOptions;
            end
        end

        function setupUI(this)
            if ~isempty(fields(this.privateOptions))
                this.setup(this.privateOptions);
            else
                this.setup(this.defaultOptions);
            end
        end

        function set.isDirty(this, value)
            if value
                % 更新 privateOptions
                this.get("options");
            end
            this.isDirty = false;
        end
    end

    methods (Hidden, Static)
        function accordion = qeShow(debug)
            arguments
                debug logical = false
            end
            % 用于在单元测试中测试 TaskUI

            % 判断是否存在名为 "Unit Test" 的窗口
            existingFig = findall(0, 'Type', 'figure', 'Name', 'Unit Test');
            if ~isempty(existingFig)
                % 如果存在则关闭窗口
                close(existingFig);
            end

            % 创建画布和面板
            fig = uifigure("Name", "Unit Test");
            fig.Position(3) = 300;
            fig.Position(4) = 600;
            layout = uigridlayout(fig);
            layout.ColumnSpacing = 0;
            layout.RowSpacing = 0;
            layout.ColumnWidth = {'1x'};
            layout.RowHeight = {'1x'};

            accordion = matlab.ui.container.internal.Accordion('Parent', layout);

            if debug
                pause(2);
                webWindow = struct(struct(struct(fig).Controller).PlatformHost).CEF;
                webWindow.openDevTools();
            end
        end
    end
end

