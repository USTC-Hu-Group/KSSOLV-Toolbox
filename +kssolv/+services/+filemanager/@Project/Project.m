classdef Project < kssolv.services.filemanager.AbstractItem
    %PROJECT 定义了以".ks"为扩展名的 KSSOLV Toolbox 项目文件类和相关操作函数

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Hidden, SetObservable)
        isDirty logical   % 用于判断是否需要保存当前项目中的变更
    end

    properties (Hidden)
        version string    % .ks 文件版本号，默认为 ks-1.0
    end

    methods
        function this = Project()
            %PROJECT 构造函数
            this = this@kssolv.services.filemanager.AbstractItem("Project", "Project");

            workflowParent = kssolv.services.filemanager.Workflow('Workflow', 'Folder');
            this.addChildrenItem(workflowParent);
            structureParent = kssolv.services.filemanager.Structure('Structure', 'Folder');
            this.addChildrenItem(structureParent);
            volumeParent = kssolv.services.filemanager.Volume('Volume', 'Folder');
            this.addChildrenItem(volumeParent);
            resultsParent = kssolv.services.filemanager.Results('Results', 'Folder');
            this.addChildrenItem(resultsParent);

            this.isDirty = false;
            this.version = 'ks-1.0';
        end

        function saveToKsFile(this, filename)
            % 将项目数据结构体保存到 .ks 文件中
            arguments
                this
                filename (1,1) string = this.label + '.ks'
            end

            % 检查 filename 是否为绝对路径，并检查目录是否存在，不存在则创建
            folderPath = fileparts(filename);
            if ~isempty(folderPath) && ~exist(folderPath, 'dir')
                previousWarningState = warning;
                warningCleanup = ...
                    onCleanup(@() warning(previousWarningState));
                warning('off', 'all');
                mkdir(folderPath);
                clear warningCleanup
            end

            data = this;
            try
                % 在执行 save 命令前设定 isDirty 属性，
                % 避免将值为 true 的 isDirty 保存到 .ks 文件中
                data.isDirty = false;
                save(filename, 'data', "-mat", "-v7.3");
            catch ME
                error('KSSOLV:FileManager:Project:FileSaveError', ...
                    'Error saving the Project file: %s', ME.message);
            end
        end

        function set.isDirty(this, value)
            this.isDirty = value;
            this.updatedAt = datetime;
        end
    end

    methods (Static)
        function data = loadKsFile(fileName)
            % 从 .ks 文件中加载项目数据结构体
            [~, ~, ext] = fileparts(fileName);
            if ~strcmp(ext, '.ks')
                % 检查文件的扩展名是否为 .ks
                error('KSSOLV:FileManager:Project:FileLoadError', ...
                    'Specified file does not have a .ks extension');
            end

            try
                load(fileName, "-mat", 'data');
            catch ME
                error('KSSOLV:FileManager:Project:FileLoadError', ...
                    'Error loading the Project file: %s', ME.message);
            end
        end
    end
end
