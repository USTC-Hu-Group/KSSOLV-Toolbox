classdef Structure < kssolv.services.filemanager.AbstractItem
    %STRUCTURE 定义了KSSOLV Toolbox 结构类和相关操作函数

    %   开发者：杨柳
    %   版权 2024 合肥瀚海量子科技有限公司

    methods
        function this = Structure(label, type)
            %STRUCTURE 构造函数
            arguments
                label string = "Structure"
                type string = "Structure"
            end
            this = this@kssolv.services.filemanager.AbstractItem(label, type);
        end

        function showMoleculeDisplay(this)
            % 使用 Data 数据中的文件路径以打开对应结构的渲染界面
            if isobject(this.data) && ...
                    isprop(this.data, "MatgenlabObject") && ...
                    ~isempty(this.data.MatgenlabObject)
                input = this.data.MatgenlabObject;
                format = "";
            elseif ismethod(this.data, "getDisplayData")
                [input, format] = this.data.getDisplayData();
            else
                input = this.data.rawFileContent;
                format = this.data.fileType;
            end
            kssolv.ui.components.figuredocument.MoleculeDisplay( ...
                input, format, this.name).Display();
        end

        function importedFileCount = importStructureFromFile(this)
            % 打开导入结构文件对话框，创建并添加 Structure 节点，渲染结构
            import kssolv.ui.util.Localizer.message

            [files, path] = ...
                kssolv.services.fileparser.FileDialogRegistry. ...
                chooseMany( ...
                kssolv.services.fileparser.FileDialogRegistry. ...
                structureFilters(), ...
                message("KSSOLV:dialogs:ImportStructureFromFile"), ...
                "LastStructureImportFolder");

            % 检查用户是否点击了取消按钮
            if isempty(files)
                importedFileCount = 0;
                return
            end

            % 初始化成功导入的文件计数
            importedFileCount = 0;

            % 遍历所有选中的文件
            for i = 1:length(files)
                fullPath = fullfile(path, files{i});
                [~, filename] = fileparts(files{i});

                % 解析文件并创建结构节点
                structure = kssolv.services.filemanager.Structure(filename);

                try
                    structure.data = ...
                        kssolv.services.fileparser.StructureIO(fullPath);
                catch exception
                    warning("KSSOLV:FileManager:Structure:ImportFailed", ...
                        "Unable to import '%s': %s", fullPath, ...
                        exception.message);
                    continue
                end

                if ~isempty(structure.data)
                    this.addChildrenItem(structure);
                    importedFileCount = importedFileCount + 1;
                    displayObj = ...
                        kssolv.ui.components.figuredocument. ...
                        MoleculeDisplay(structure.data.MatgenlabObject, "", ...
                        structure.name);
                    displayObj.Display();
                end
            end
        end
    end

    methods (Static)
        function importedStructures = getAllImportedStructures()
            % 输出当前使用的工程中 Structure 节点下的所有数据结构体
            project = kssolv.ui.util.DataStorage.getData('Project');
            if isempty(project)
                importedStructures = cell.empty;
                return
            end

            structureItem = project.findChildrenItem('Structure');
            importedStructures = cell(size(structureItem.children, 1), 1);
            for i = 1:size(structureItem.children, 1)
                temp = structureItem.children{i}.data.KSSOLVSetupObject;
                temp.node.label = structureItem.children{i}.label;
                temp.node.name = structureItem.children{i}.name;
                importedStructures{i, 1} = temp;
            end
        end
    end
end
