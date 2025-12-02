classdef HomeTab < handle
    %HOMETAB Toolstrip 菜单栏中的 Home 标签页

    %   开发者：杨柳、高俊、林海饶
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties
        Tab       % Home 标签页
        Tag       % 标签
        Title     % 标题
        Widgets   % 小组件
    end

    properties (Access = private)
        settingsDialog % 设置对话框
    end

    methods
        function this = HomeTab()
            %HOMETAB 构造函数，初始设置相关参数
            import kssolv.ui.util.Localizer.message
            this.Title = message("KSSOLV:toolbox:HomeTabTitle");
            this.Tag = 'HomeTab';

            buildTab(this);
            connectTab(this);
            setTabActivated(this);

            % 将 HomeTab 保存到 DataStorage
            kssolv.ui.util.DataStorage.setData('HomeTab', this);
        end
    end

    methods (Access = protected)
        function buildTab(this)
            %BUILDTAB 创建 Home Tab 对象
            this.Tab = matlab.ui.internal.toolstrip.Tab(this.Title);
            this.Tab.Tag = this.Tag;

            % 分别创建各个 Section 并添加到 Home Tab 中
            createFileSection(this);
            createProjectSection(this);
            createRunningSection(this)
            createEnvironmentSection(this);
            createResourceSection(this);
        end

        function connectTab(this)
            %CONNECTTAB 为按钮等组件添加监听器和回调函数
            % File Section
            addlistener(this.Widgets.FileSection.FileOpenButton, ...
                'ButtonPushed', @(src, data) callbackFileOpenButton(this));
            addlistener(this.Widgets.FileSection.FileOpenButton.Popup.getChildByIndex(1), ...
                'ItemPushed', @(src, data) callbackFileOpenButton(this));
            addlistener(this.Widgets.FileSection.FileSaveButton, ...
                'ButtonPushed', @(src, data) callbackFileSaveButton(this));
            addlistener(this.Widgets.FileSection.FileSaveButton.Popup.getChildByIndex(1), ...
                'ItemPushed', @(src, data) callbackFileSaveButton(this));
            addlistener(this.Widgets.FileSection.FileSaveButton.Popup.getChildByIndex(2), ...
                'ItemPushed', @(src, data) callbackSaveProjectAs(this));
            addlistener(this.Widgets.FileSection.FileCloseButton, ...
                'ButtonPushed', @(src, data) callbackFileCloseButton(this));
            % Project Section
            addlistener(this.Widgets.ProjectSection.ProjectStructureButton.Popup.getChildByIndex(1), ...
                'ItemPushed', @(src, data) callbackImportStructureFromFile(this));
            addlistener(this.Widgets.ProjectSection.ProjectWorkflowButton, ...
                'ButtonPushed', @(src, data) callbackProjectWorkflowButton(this));
            addlistener(this.Widgets.ProjectSection.ProjectWorkflowButton.Popup.getChildByIndex(1), ...
                'ItemPushed', @(src, data) callbackNewBlankWorkflow(this));
            addlistener(this.Widgets.ProjectSection.ProjectWorkflowButton.Popup.getChildByIndex(3), ...
                'ItemPushed', @(src, data) callbackImportWorkflowFromFile(this));
            addlistener(this.Widgets.ProjectSection.ProjectWorkflowButton.Popup.getChildByIndex(4), ...
                'ItemPushed', @(src, data) callbackExportWorkflow(this));
            addlistener(this.Widgets.ProjectSection.ProjectVariableButton.Popup.getChildByIndex(2), ...
                'ItemPushed', @(src, data) callbackExportVariabletoMATLAB(this));
            % Running Section
            addlistener(this.Widgets.RunningSection.RunningRunButton, ...
                'ButtonPushed', @(src, data) callbackRunningRunButton(this));
            addlistener(this.Widgets.RunningSection.RunningRunButton.Popup.getChildByIndex(1), ...
                'ItemPushed', @(src, data) callbackRunAndTime(this));
            addlistener(this.Widgets.RunningSection.RunningStopButton, ...
                'ButtonPushed', @(src, data) callbackRunningStopButton(this));
            % Environment Section
            addlistener(this.Widgets.EnvironmentSection.EnvironmentSettingsButton, ...
                'ButtonPushed', @(src, data) callbackEnvironmentSettingsButton(this));
            % Resource Section
            addlistener(this.Widgets.ResourceSection.ResourceDocumentationButton, ...
                'ButtonPushed', @(src, data) callbackResourceDocumentationButton(this));
            addlistener(this.Widgets.ResourceSection.ResourceHelpButton.Popup.getChildByIndex(1), ...
                'ItemPushed', @(src, data) callbackExamplesButton(this));
            addlistener(this.Widgets.ResourceSection.ResourceHelpButton.Popup.getChildByIndex(2), ...
                'ItemPushed', @(src, data) callbackOpenOfficialSiteButton(this));
            addlistener(this.Widgets.ResourceSection.ResourceSupportButton, ...
                'ButtonPushed', @(src, data) callbackResourceSupportButton(this));
        end

        function setTabActivated(this)
            %SETTABACTIVATED 初始化时设置一些按钮是否被启用
            this.Widgets.RunningSection.RunningStepButton.Enabled = false;
            this.Widgets.RunningSection.RunningStopButton.Enabled = false;

            % 禁用尚未实现功能的按钮
            this.Widgets.ProjectSection.ProjectStructureButton.Popup.getChildByIndex(2).Enabled = false;
            this.Widgets.ProjectSection.ProjectStructureButton.Popup.getChildByIndex(3).Enabled = false;
            this.Widgets.ProjectSection.ProjectStructureButton.Popup.getChildByIndex(4).Enabled = false;
            this.Widgets.ProjectSection.ProjectVariableButton.Popup.getChildByIndex(1).Enabled = false;
            this.Widgets.EnvironmentSection.EnvironmentRemoteButton.Popup.getChildByIndex(1).Enabled = false;
            this.Widgets.EnvironmentSection.EnvironmentExtraButton.Popup.getChildByIndex(1).Enabled = false;
        end
    end

    methods (Access = private)
        %% 创建 Sections
        function createFileSection(this)
            %CREATEFILESECTION 创建"文件"小节，并添加到 HomeTab 中
            import matlab.ui.internal.toolstrip.*
            import kssolv.ui.util.Localizer.message
            import kssolv.ui.util.CreateButton
            import kssolv.ui.util.CreateListItem

            % 创建 File Section
            section = Section(message("KSSOLV:toolbox:FileSectionTitle"));
            section.Tag = 'FileSection';
            % 创建 Column
            column1 = Column();
            column2 = Column();
            column3 = Column();

            % 创建 Button
            FileOpenButton = CreateButton('split', 'FileOpen', section.Tag, 'openFolder');
            FileSaveButton = CreateButton('split', 'FileSave', section.Tag, 'unsaved');
            FileCloseButton = CreateButton('push', 'FileClose', section.Tag, 'close');

            % 创建并组装 PopupList(下拉菜单)
            FileOpenButtonPopup = PopupList();
            OpenProjectFileListItem = CreateListItem('default', 'OpenProjectFile', section.Tag, 1, 'project');
            FileOpenButtonPopup.add(OpenProjectFileListItem);
            FileOpenButton.Popup = FileOpenButtonPopup;

            FileSaveButtonPopup = PopupList();
            SaveProjectListItem = CreateListItem('default', 'SaveProject', section.Tag, 1, 'saved');
            SaveProjectAsListItem = CreateListItem('default', 'SaveProjectAs', section.Tag, 1, 'saveAs');
            FileSaveButtonPopup.add(SaveProjectListItem);
            FileSaveButtonPopup.add(SaveProjectAsListItem);
            FileSaveButton.Popup = FileSaveButtonPopup;

            % 组装 Column 和 Button
            column1.add(FileOpenButton);
            column2.add(FileSaveButton);
            column3.add(FileCloseButton);
            section.add(column1);
            section.add(column2);
            section.add(column3);
            this.Tab.add(section);

            % 添加到 Widgets
            this.Widgets.FileSection = struct('FileOpenButton', FileOpenButton, ...
                'FileSaveButton', FileSaveButton, 'FileCloseButton', FileCloseButton);
        end

        function createProjectSection(this)
            %CREATEPROJECTSECTION 创建"项目"小节，并添加到 HomeTab 中
            import matlab.ui.internal.toolstrip.*
            import kssolv.ui.util.Localizer.message
            import kssolv.ui.util.CreateButton
            import kssolv.ui.util.CreateListItem

            % 创建 Project Section
            section = Section(message("KSSOLV:toolbox:ProjectSectionTitle"));
            section.Tag = 'ProjectSection';

            % 创建 Column
            column1 = Column();
            column2 = Column();
            column3 = Column();

            % 创建 Button
            ProjectStructureButton = CreateButton('dropdown', 'ProjectStructure', section.Tag, 'import_data');
            ProjectWorkflowButton = CreateButton('split', 'ProjectWorkflow', section.Tag, 'artifactGraph');
            ProjectVariableButton = CreateButton('dropdown', 'ProjectVariable', section.Tag, 'legend');

            % 创建并组装 PopupList(下拉菜单)
            ProjectStructureButtonPopup = PopupList();
            ImportStructureFromFileListItem = CreateListItem('default', 'ImportStructureFromFile', section.Tag, 0, 'importDiagram');
            ImportStructureFromLinkListItem = CreateListItem('default', 'ImportStructureFromLink', section.Tag, 0, 'link_project');
            ImportStructureFromLibraryListItem = CreateListItem('default', 'ImportStructureFromLibrary', section.Tag, 0, 'database_projectYellow');
            ImportStructureFromMatlabListItem = CreateListItem('default', 'ImportStructureFromMatlab', section.Tag, 0, 'matlabWorkspaceFile');

            ProjectWorkflowButtonPopup = PopupList();
            NewWorkflowListItem = CreateListItem('default', 'NewWorkflow', section.Tag, 0, 'add_class');
            ImportTemplateWorkflowListItem = kssolv.ui.components.tab.HomeTab.createTemplateWorkflowMenu(section.Tag);
            ImportWorkflowFromFileListItem = CreateListItem('default', 'ImportWorkflowFromFile', section.Tag, 0, 'new_artifactGraph');
            ExportWorkflowListItem = CreateListItem('default', 'ExportWorkflow', section.Tag, 0, 'documentArtifactGraph');

            ProjectVariableButtonPopup = PopupList();
            NewVariableListItem = CreateListItem('default', 'NewVariable', section.Tag, 0, 'new_sectionHighlighted');
            ExportVariabletoMATLABListItem = CreateListItem('default', 'ExportVariabletoMATLAB', section.Tag, 0, 'matlabWorkspaceFile');

            ProjectStructureButtonPopup.add(ImportStructureFromFileListItem)
            ProjectStructureButtonPopup.add(ImportStructureFromLinkListItem);
            ProjectStructureButtonPopup.add(ImportStructureFromLibraryListItem);
            ProjectStructureButtonPopup.add(ImportStructureFromMatlabListItem);
            ProjectWorkflowButtonPopup.add(NewWorkflowListItem);
            ProjectWorkflowButtonPopup.add(ImportTemplateWorkflowListItem);
            ProjectWorkflowButtonPopup.add(ImportWorkflowFromFileListItem);
            ProjectWorkflowButtonPopup.add(ExportWorkflowListItem);
            ProjectVariableButtonPopup.add(NewVariableListItem);
            ProjectVariableButtonPopup.add(ExportVariabletoMATLABListItem);
            ProjectStructureButton.Popup = ProjectStructureButtonPopup;
            ProjectWorkflowButton.Popup = ProjectWorkflowButtonPopup;
            ProjectVariableButton.Popup = ProjectVariableButtonPopup;

            % 组装 Column 和 Button
            column1.add(ProjectStructureButton);
            column2.add(ProjectWorkflowButton);
            column3.add(ProjectVariableButton);
            section.add(column1);
            section.add(column2);
            section.add(column3);
            this.Tab.add(section);

            % 添加到 Widgets
            this.Widgets.ProjectSection = struct('ProjectStructureButton', ProjectStructureButton, ...
                'ProjectWorkflowButton', ProjectWorkflowButton, 'ProjectVariableButton', ProjectVariableButton);
        end

        function createRunningSection(this)
            %CREATERUNNINGSECTION 创建"运行"小节，并添加到 HomeTab 中
            import matlab.ui.internal.toolstrip.*
            import kssolv.ui.util.Localizer.message
            import kssolv.ui.util.CreateButton
            import kssolv.ui.util.CreateListItem

            % 创建 File Section
            section = Section(message("KSSOLV:toolbox:RunningSectionTitle"));
            section.Tag = 'RunningSection';
            % 创建 Column
            column1 = Column();
            column2 = Column();
            column3 = Column();

            % 创建 Button
            RunningRunButton = CreateButton('split', 'RunningRun', section.Tag, 'playControl');
            RunningStepButton = CreateButton('push', 'RunningStep', section.Tag, 'stepForward');
            RunningStopButton = CreateButton('push', 'RunningStop', section.Tag, 'stop');

            % 创建并组装 PopupList(下拉菜单)
            RunPopup = PopupList();
            RunAndTimeListItem = CreateListItem('default', 'RunAndTime', section.Tag, 1, 'runAndTime');
            RunPopup.add(RunAndTimeListItem);
            RunningRunButton.Popup = RunPopup;

            % 组装 Column 和 Button
            column1.add(RunningRunButton);
            column2.add(RunningStepButton);
            column3.add(RunningStopButton);
            section.add(column1);
            section.add(column2);
            section.add(column3);
            this.Tab.add(section);

            % 添加到 Widgets
            this.Widgets.RunningSection = struct('RunningRunButton', RunningRunButton, ...
                'RunningStepButton', RunningStepButton, 'RunningStopButton', RunningStopButton);
        end

        function createEnvironmentSection(this)
            %CREATENVIRONMENTSECTION 创建"环境"小节，并添加到 HomeTab 中
            import matlab.ui.internal.toolstrip.*
            import kssolv.ui.util.Localizer.message
            import kssolv.ui.util.CreateButton
            import kssolv.ui.util.CreateListItem

            % 创建 Environment Section
            section = Section(message("KSSOLV:toolbox:EnvironmentSectionTitle"));
            section.Tag = 'EnvironmentSection';
            % 创建 Column
            column1 = Column();
            column2 = Column();
            column3 = Column();
            column4 = Column();

            % 创建 Button
            EnvironmentSettingsButton = CreateButton('push', 'EnvironmentSettings', section.Tag, 'settings');
            EnvironmentRemoteButton = CreateButton('dropdown', 'EnvironmentRemote', section.Tag, 'matlabCloud');
            EnvironmentParallelButton = CreateButton('push', 'EnvironmentParallel', section.Tag, 'parallel');
            EnvironmentExtraButton = CreateButton('dropdown', 'EnvironmentExtra', section.Tag, 'addOns');

            % 创建并组装 PopupList(下拉菜单)
            RemotePopup = PopupList();
            ExtraPopup = PopupList();
            ConnectToClusterListItem = CreateListItem('default', 'ConnectToCluster', section.Tag, 0, 'new_cloud');
            GetExtraFeatureListItem = CreateListItem('default', 'GetExtraFeature', section.Tag, 0, 'addOns');
            RemotePopup.add(ConnectToClusterListItem);
            ExtraPopup.add(GetExtraFeatureListItem);
            EnvironmentRemoteButton.Popup = RemotePopup;
            EnvironmentExtraButton.Popup = ExtraPopup;

            % 组装 Column 和 Button
            column1.add(EnvironmentSettingsButton);
            column2.add(EnvironmentRemoteButton);
            column3.add(EnvironmentParallelButton);
            column4.add(EnvironmentExtraButton);
            section.add(column1);
            section.add(column2);
            section.add(column3);
            section.add(column4);
            this.Tab.add(section);

            % 添加到 Widgets
            this.Widgets.EnvironmentSection = struct('EnvironmentSettingsButton', EnvironmentSettingsButton, ...
                'EnvironmentRemoteButton', EnvironmentRemoteButton, 'EnvironmentParallelButton', EnvironmentParallelButton, ...
                'EnvironmentExtraButton', EnvironmentExtraButton);
        end

        function createResourceSection(this)
            %CREATERESOURCESECTION 创建"资源"小节，并添加到 HomeTab 中
            import matlab.ui.internal.toolstrip.*
            import kssolv.ui.util.Localizer.message
            import kssolv.ui.util.CreateButton
            import kssolv.ui.util.CreateListItem

            % 创建 Resource Section
            section = Section(message("KSSOLV:toolbox:ResourceSectionTitle"));
            section.Tag = 'ResourceSection';
            % 创建 Column
            column1 = Column();
            column2 = Column();
            column3 = Column();
            column4 = Column();

            % 创建 Button
            ResourceDocumentationButton = CreateButton('push', 'ResourceDocumentation', section.Tag, 'documentation');
            ResourceCommunityButton = CreateButton('push', 'ResourceCommunity', section.Tag, 'community');
            ResourceHelpButton = CreateButton('dropdown', 'ResourceHelp', section.Tag, 'help');
            ResourceSupportButton = CreateButton('push', 'ResourceSupport', section.Tag, 'requestSupport');

            % 创建并组装 PopupList(下拉菜单)
            HelpPopup = PopupList();
            ExamplesListItem = CreateListItem('default', 'Examples', section.Tag, 0, 'examples');
            OpenOfficialSiteListItem = CreateListItem('default', 'OfficialSite', section.Tag, 0, 'link_globe');
            CheckUpdateListItem = CreateListItem('default', 'CheckUpdate', section.Tag);
            CheckLicenseListItem = CreateListItem('default', 'CheckLicense', section.Tag);
            TermsOfUseListItem = CreateListItem('default', 'TermsOfUse', section.Tag);
            AboutUsListItem = CreateListItem('default', 'AboutUs', section.Tag);
            HelpPopup.add(ExamplesListItem);
            HelpPopup.add(OpenOfficialSiteListItem);
            HelpPopup.addSeparator;
            HelpPopup.add(CheckUpdateListItem);
            HelpPopup.add(CheckLicenseListItem);
            HelpPopup.add(TermsOfUseListItem);
            HelpPopup.add(AboutUsListItem);
            ResourceHelpButton.Popup = HelpPopup;

            % 组装 Column 和 Button
            column1.add(ResourceDocumentationButton);
            column2.add(ResourceCommunityButton);
            column3.add(ResourceHelpButton);
            column4.add(ResourceSupportButton);
            section.add(column1);
            section.add(column2);
            section.add(column3);
            section.add(column4);
            this.Tab.add(section);

            % 添加到 Widgets
            this.Widgets.ResourceSection = struct('ResourceDocumentationButton', ResourceDocumentationButton, ...
                'ResourceCommunityButton', ResourceCommunityButton, 'ResourceHelpButton', ResourceHelpButton, ...
                'ResourceSupportButton', ResourceSupportButton);
        end

        %% 回调函数
        function callbackFileOpenButton(~, ~, ~)
            import kssolv.ui.util.Localizer.*
            [file, path] = uigetfile({'*.ks', 'KSSOLV Files (*.ks)'}, ...
                message('KSSOLV:dialogs:OpenKSFileTitle'), 'MultiSelect', 'off');
            if isequal(file, 0)
                % 用户点击了"取消"按钮
                kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();
                return
            end

            ksFile = fullfile(path, file);
            kssolv.ui.util.DataStorage.setData('LoadingKsFile', true);
            project = kssolv.services.filemanager.Project.loadKsFile(ksFile);
            kssolv.ui.util.DataStorage.setData('LoadingKsFile', false);
            kssolv.ui.util.DataStorage.setData('Project', project);
            kssolv.ui.util.DataStorage.setData('ProjectFilename', ksFile);
            kssolv.ui.util.DataStorage.getData('ProjectBrowser').reBuildUI();

            kssolv.KSSOLVToolbox.setAppContainerTitle();
            kssolv.KSSOLVToolbox.createListener();
            kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();
        end

        function callbackFileSaveButton(~, ~, ~)
            import kssolv.ui.util.Localizer.*
            project = kssolv.ui.util.DataStorage.getData('Project');
            if ~project.isDirty
                return
            end
            ksFile = kssolv.ui.util.DataStorage.getData('ProjectFilename');
            if ksFile == ""
                % ksFile 为空说明当前未打开某个 .ks 文件，需要选择保存为 .ks 文件的路径
                [file, location] = uiputfile({'*.ks', 'KSSOLV Files (*.ks)'}, ...
                    message('KSSOLV:dialogs:SaveKSFileTitle'), 'untitled');
                if isequal(file, 0) || isequal(location, 0)
                    % 用户点击了"取消"按钮
                    kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();
                    return
                else
                    % 用户选择了具体的文件路径
                    ksFile = fullfile(location, file);
                    kssolv.ui.util.DataStorage.setData('ProjectFilename', ksFile);
                    project.saveToKsFile(ksFile);
                end
                kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();
            else
                % ksFile 不为空说明当前已打开某个 .ks 文件，直接保存文件
                project.saveToKsFile(ksFile);
            end
        end

        function callbackSaveProjectAs(~, ~, ~)
            import kssolv.ui.util.Localizer.*

            ksFile = kssolv.ui.util.DataStorage.getData('ProjectFilename');
            if ksFile == ""
                filename = 'untitled';
            else
                [~, filename, ~] = fileparts(ksFile);
            end

            % 打开对话框，需要选择另存为 .ks 文件的路径
            [file, location] = uiputfile({'*.ks', 'KSSOLV Files (*.ks)'}, ...
                message('KSSOLV:dialogs:SaveKSFileTitle'), filename);
            if isequal(file, 0) || isequal(location, 0)
                % 用户点击了"取消"按钮
                kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();
                return
            else
                % 用户选择了具体的文件路径
                ksFile = fullfile(location, file);
                project = kssolv.ui.util.DataStorage.getData('Project');
                project.isDirty = false;
                project.saveToKsFile(ksFile);

                % 更新标题栏
                kssolv.ui.util.DataStorage.setData('ProjectFilename', ksFile);
                kssolv.KSSOLVToolbox.setAppContainerTitle();
                kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();
            end
        end

        function callbackFileCloseButton(~, ~, ~)
            import kssolv.ui.util.Localizer.*
            project = kssolv.ui.util.DataStorage.getData('Project');
            projectFilename = kssolv.ui.util.DataStorage.getData('ProjectFilename');
            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            if ~project.isDirty
                % 如果 project 没有进行任何修改，则直接关闭已有的 project
                % 此处不需要进行额外的处理
            else
                % 如果 project 有进行修改，则弹出对话框，包含"保存"、"不保存"和"取消"按钮
                YesLabel = message('KSSOLV:dialogs:ProjectCanCloseSave');
                NoLabel = message('KSSOLV:dialogs:ProjectCanCloseDoNotSave');
                CancelLabel = message('KSSOLV:dialogs:ProjectCanCloseCancel');

                if isdeployed
                    % 在独立应用程序里，模态对话框无法正常工作，因此需要使用非模态的对话框
                    confirmDialog = kssolv.ui.components.dialog.ConfirmDialog( ...
                        message('KSSOLV:dialogs:ProjectCanCloseMessage'), ...
                        message('KSSOLV:dialogs:ProjectCanCloseTitle'), ...
                        'Options', {YesLabel, NoLabel, CancelLabel}, ...
                        'DefaultOption', 1, 'CancelOption', 3);
                    selection = confirmDialog.show();
                else
                    % 普通情况下使用模态对话框
                    selection = uiconfirm(appContainer, ...
                        message('KSSOLV:dialogs:ProjectCanCloseMessage'), ...
                        message('KSSOLV:dialogs:ProjectCanCloseTitle'), ...
                        "Options", {YesLabel, NoLabel, CancelLabel}, ...
                        "DefaultOption", 1, "CancelOption", 3);
                end

                switch selection
                    case YesLabel
                        if projectFilename == ""
                            % 如果尚未指定要保存的文件，则选择保存为 .ks 文件的路径
                            [file,location] = uiputfile({'*.ks', 'KSSOLV Files (*.ks)'}, ...
                                message('KSSOLV:dialogs:SaveKSFileTitle'), 'untitled.ks');
                            if isequal(file, 0) || isequal(location, 0)
                                % 用户点击了"取消"按钮
                                return
                            else
                                % 用户选择了具体的文件路径，保存 project
                                project.saveToKsFile(fullfile(location, file));
                            end
                        else
                            % 如果已打开 .ks 文件，则保存后关闭当前 project
                            project.saveToKsFile(projectFilename);
                        end
                    case NoLabel
                        % 此处无需进行处理
                    case CancelLabel
                        return
                end
            end

            % 关闭所有已打开的 document
            documents = appContainer.getDocuments();
            for i = 1:numel(documents)
                documents{i}.close();
            end

            kssolv.ui.util.DataStorage.setData('Project', kssolv.services.filemanager.Project());
            kssolv.ui.util.DataStorage.setData('ProjectFilename', '');
            kssolv.ui.util.DataStorage.getData('ProjectBrowser').reBuildUI();
            kssolv.ui.util.DataStorage.getData('InfoBrowser').reBuildUI();
            kssolv.KSSOLVToolbox.setAppContainerTitle();
            kssolv.KSSOLVToolbox.createListener();
            appContainer.bringToFront();
        end

        function callbackImportStructureFromFile(~, ~, ~)
            project = kssolv.ui.util.DataStorage.getData('Project');
            for i = 1:length(project.children)
                % 从当前 Project 的第二级节点中查找 Structure 节点
                if startsWith(project.children{i, 1}.name, 'Structure')
                    item = project.children{i, 1};
                end
            end
            if ~isempty(item)
                importedFileCount = item.importStructureFromFile();
                if importedFileCount > 0
                    projectBrowser = kssolv.ui.util.DataStorage.getData('ProjectBrowser');
                    startIndex = numel(item.children) - importedFileCount + 1;
                    for index = startIndex : numel(item.children)
                        projectBrowser.updateTreetable('ADD', item.name, item.children{index}.encodeToJSON(1));
                    end
                    projectBrowser.updateTreetable('PATCH', item.name, item.encodeToJSON(1));
                end
            end
        end

        function callbackProjectWorkflowButton(~, ~, ~)
            project = kssolv.ui.util.DataStorage.getData('Project');
            for i = 1:length(project.children)
                % 从当前 Project 的第二级节点中查找 Workflow 节点
                if startsWith(project.children{i, 1}.name, 'Workflow')
                    item = project.children{i, 1};
                end
            end
            if ~isempty(item)
                item.createWorkflowItem();
                projectBrowser = kssolv.ui.util.DataStorage.getData('ProjectBrowser');
                projectBrowser.updateTreetable('ADD', item.name, item.children{end}.encodeToJSON(1));
                projectBrowser.updateTreetable('PATCH', item.name, item.encodeToJSON(1));
            end
        end

        function callbackNewBlankWorkflow(~, ~, ~)
            project = kssolv.ui.util.DataStorage.getData('Project');
            for i = 1:length(project.children)
                % 从当前 Project 的第二级节点中查找 Workflow 节点
                if startsWith(project.children{i, 1}.name, 'Workflow')
                    item = project.children{i, 1};
                end
            end
            if ~isempty(item)
                item.createWorkflowItem(true);
                projectBrowser = kssolv.ui.util.DataStorage.getData('ProjectBrowser');
                projectBrowser.updateTreetable('ADD', item.name, item.children{end}.encodeToJSON(1));
                projectBrowser.updateTreetable('PATCH', item.name, item.encodeToJSON(1));
            end
        end

        function callbackImportWorkflowFromFile(~, ~, ~)
            import kssolv.ui.util.Localizer.*

            % 打开文件选取对话框
            [file, path] = uigetfile({'*.wf', 'KSSOLV Workflow Files (*.wf)'}, ...
                message('KSSOLV:dialogs:OpenWFFileTitle'), 'MultiSelect', 'off');
            if isequal(file, 0)
                % 用户点击了"取消"按钮
                return
            end
            kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();

            % 加载到当前 Project 中
            wfFile = fullfile(path, file);
            kssolv.ui.components.figuredocument.Workflow.loadWfFile(wfFile);
        end

        function callbackExportWorkflow(~, ~, ~)
            import kssolv.ui.util.Localizer.*

            currentWorkflowDocument = kssolv.ui.components.figuredocument.Workflow.getCurrentWorkflowDocument();
            if isempty(currentWorkflowDocument)
                return
            end

            % 根据 tag 查找对应的 Workflow item
            project = kssolv.ui.util.DataStorage.getData('Project');
            workflow = project.findChildrenItem(currentWorkflowDocument.Tag);

            % 选择保存为 .wf 文件的路径
            [file,location] = uiputfile({'*.wf', 'KSSOLV Workflow Files (*.wf)'}, ...
                message('KSSOLV:dialogs:SaveWFFileTitle'), 'untitled');
            if isequal(file, 0) || isequal(location, 0)
                % 用户点击了"取消"按钮
                return
            else
                % 用户选择了具体的文件路径
                wfFile = fullfile(location, file);
                workflow.saveToWfFile(wfFile);
            end
            kssolv.ui.util.DataStorage.getData('AppContainer').bringToFront();
        end

        function callbackExportVariabletoMATLAB(~, ~, ~)
            projectBrowser = kssolv.ui.util.DataStorage.getData('ProjectBrowser');
            project = kssolv.ui.util.DataStorage.getData('Project');
            if ~isempty(projectBrowser.currentSelectedItem)
                % 添加到 base 工作空间
                item = project.findChildrenItem(projectBrowser.currentSelectedItem);
                assignin('base', strrep(item.label, ' ', ''), item);
            end
        end

        function callbackRunningRunButton(this, ~, ~)
            project = kssolv.ui.util.DataStorage.getData('Project');
            runBrowser = kssolv.ui.util.DataStorage.getData('RunBrowser');

            this.Widgets.RunningSection.RunningRunButton.Enabled = false;
            this.Widgets.RunningSection.RunningStopButton.Enabled = true;
            runBrowser.Widgets.ButtonPanel.RunButton.Enable = false;
            runBrowser.Widgets.ButtonPanel.StopButton.Enable = true;

            % 增加换行以便利阅读
            runBrowser.addNewLineToOutputTextArea();

            % 获取当前最新打开的工作流
            workflowDocument = kssolv.ui.components.figuredocument.Workflow.getCurrentWorkflowDocument();
            if isempty(workflowDocument)
                this.Widgets.RunningSection.RunningRunButton.Enabled = true;
                this.Widgets.RunningSection.RunningStopButton.Enabled = false;
                runBrowser.Widgets.ButtonPanel.RunButton.Enable = true;
                runBrowser.Widgets.ButtonPanel.StopButton.Enable = false;
                return
            end
            workflowRoot = project.findChildrenItem('Workflow');
            workflow = workflowRoot.findChildrenItem(workflowDocument.Tag);

            % 运行工作流
            kssolv.services.workflow.codegeneration.CodeGenerator.executeTasks(workflow.graph, workflow.label);

            this.Widgets.RunningSection.RunningRunButton.Enabled = true;
            this.Widgets.RunningSection.RunningStopButton.Enabled = false;
            runBrowser.Widgets.ButtonPanel.RunButton.Enable = true;
            runBrowser.Widgets.ButtonPanel.StopButton.Enable = false;
        end

        function callbackRunAndTime(this, ~, ~)
            import kssolv.ui.util.Localizer.*

            footerBar = kssolv.ui.util.DataStorage.getData('FooterBar');
            footerBar.setLabelText('');

            % 计时并运行
            tStart = tic;
            this.callbackRunningRunButton();
            tEnd = toc(tStart);

            % 在底部状态栏中更新本次计算用时
            timeUsedText = sprintf('%s%.2f %s', message('KSSOLV:dialogs:RunTimeUsed'), ...
                tEnd, message('KSSOLV:dialogs:RunTimeUsedUnit'));
            footerBar.setLabelText(timeUsedText);
        end

        function callbackRunningStopButton(this, ~, ~)
            this.Widgets.RunningSection.RunningRunButton.Enabled = true;
            this.Widgets.RunningSection.RunningStopButton.Enabled = false;

            runBrowser = kssolv.ui.util.DataStorage.getData('RunBrowser');
            runBrowser.Widgets.ButtonPanel.RunButton.Enable = true;
            runBrowser.Widgets.ButtonPanel.StopButton.Enable = false;
        end

        function callbackEnvironmentSettingsButton(this, ~, ~)
            this.Widgets.EnvironmentSection.EnvironmentSettingsButton.Enabled = false;

            if isempty(this.settingsDialog) || ~isvalid(this.settingsDialog)
                this.settingsDialog = kssolv.ui.components.dialog.SettingsDialog();
                registerUIListeners(this.settingsDialog, ...
                    addlistener(this.settingsDialog, 'CloseEvent', ...
                    @(src, event) settingsDialogClosed(this, src, event)));
            end

            appContainer = kssolv.ui.util.DataStorage.getData('AppContainer');
            this.settingsDialog.show(appContainer);
        end

        function callbackResourceDocumentationButton(~, ~, ~)
            url = 'https://gleamore.feishu.cn/docx/O64DdiY7LoPykxxLWAJcr0oxnfd';
            web(url);
        end

        function callbackExamplesButton(~, ~, ~)
            url = 'https://gleamore.feishu.cn/docx/O64DdiY7LoPykxxLWAJcr0oxnfd';
            web(url);
        end

        function callbackOpenOfficialSiteButton(~, ~, ~)
            url = 'https://pwdft.com/prod/43.html';
            web(url);
        end

        function callbackResourceSupportButton(~, ~, ~)
            url = sprintf('mailto:%s?subject=%s V%s', KSSOLV_Toolbox.AuthorEmail, ...
                "Request for Assistance with KSSOLV Toolbox", KSSOLV_Toolbox.Version);
            web(url);
        end

        function settingsDialogClosed(this, ~, ~)
            this.Widgets.EnvironmentSection.EnvironmentSettingsButton.Enabled = true;
        end
    end

    methods (Static, Access = {?kssolv.ui.components.tab.HomeTab, ?kssolv.ui.components.tab.WorkflowTab})
        function importTemplateWorkflowListItem = createTemplateWorkflowMenu(sectionTag)
            import matlab.ui.internal.toolstrip.*
            import kssolv.ui.util.CreateListItem

            popup = PopupList();
            importTemplateWorkflowListItem = CreateListItem('popup', 'ImportTemplateWorkflow', sectionTag, 0, 'add_artifactGraph');

            workflowTemplateDirectory = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'workflows');
            workflowFiles = dir(fullfile(workflowTemplateDirectory, '*.wf'));
            for i = 1:length(workflowFiles)
                currentFilename = workflowFiles(i).name;
                currentFilePath = fullfile(workflowFiles(i).folder, currentFilename);
                [~, name, ~] = fileparts(currentFilename);

                % 动态创建 ListItem，并添加到 popup 中
                templateItem = ListItem(name, 'artifactGraph');
                templateItem.Tag = [sectionTag '_' erase(name, ' ')];
                popup.add(templateItem);

                % 添加回调函数
                addlistener(templateItem, ...
                    'ItemPushed', @(src, data) kssolv.ui.components.figuredocument.Workflow.loadWfFile(currentFilePath));
            end

            importTemplateWorkflowListItem.Popup = popup;
        end
    end

    methods (Static, Hidden)
        %% 单元测试
        function app = qeShow()
            % 用于在单元测试中测试 HomeTab，可通过下面的命令使用：
            % kssolv.ui.components.tab.HomeTab.qeShow();

            % 创建 AppContainer
            appOptions.Tag = sprintf('kssolv(%s)', char(matlab.lang.internal.uuid));
            appOptions.Title = kssolv.ui.util.Localizer.message('KSSOLV:toolbox:UnitTestTitle');
            appOptions.ToolstripEnabled = true;
            app = matlab.ui.container.internal.AppContainer(appOptions);

            % 添加 HomeTab
            homeTab = kssolv.ui.components.tab.HomeTab();
            tabGroup = matlab.ui.internal.toolstrip.TabGroup();
            tabGroup.Tag = 'kssolvTabGroup';
            tabGroup.add(homeTab.Tab);
            app.add(tabGroup);

            % 展示界面
            app.Visible = true;
        end
    end
end

