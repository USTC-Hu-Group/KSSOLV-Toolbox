classdef Localizer < handle
    %LOCALIZER 本地化管理器，根据 Identifier 获取 resources 路径下相应的本地化翻译
    %   参考链接：
    %       https://ww2.mathworks.cn/matlabcentral/answers/373512-how-can-i-open-message-key-catalog#answer_296850
    %   使用示例：
    %   （1）导入本类：
    %       import kssolv.ui.util.Localizer.*
    %   （2）使用本类的 message 函数获取与 Identifier 对应的本地化翻译，Identifier
    %       的格式为："KSSOLV:<XML 无后缀文件名>:<XML 文件 entry 条目中的 Key>"。
    %       例如：
    %       message('KSSOLV:toolbox:WelcomeMessage')

    %   开发者：杨柳
    %   版权 2024-2025 合肥瀚海量子科技有限公司

    properties (Access = private)
        % 键：Identifier，值：对应的本地化翻译
        keyValueMap containers.Map
    end

    properties (Access = public)
        % 上一次读取 XML 文件时使用的 locale
        currentLocale
    end

    properties (Constant)
        % 本地化文件夹的位置：+kssolv/+ui/resources/locales/
        localesFolder = fullfile(KSSOLV_Toolbox.UIResourcesDirectory, 'locales');
    end

    methods (Access = private)
        function this = Localizer(locale)
            % 构造函数，私有化以实现单例模式
            % 获取本地化设置，如 zh_CN
            this.currentLocale = locale;
            % 所使用的本地化文件夹的位置：+kssolv/+ui/resources/locales/${locale}
            localeFolder = fullfile(this.localesFolder, locale);
            if exist(localeFolder, 'dir')
                % 读取该本地化文件夹下所有 XML 文件，并全部缓存到 keyValueMap 中
                xmlFiles = dir(fullfile(localeFolder, '*.xml'));
                this.keyValueMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
                for i = 1:length(xmlFiles)
                    xmlFilePath = fullfile(xmlFiles(i).folder, xmlFiles(i).name);
                    xmlFileName = split(xmlFiles(i).name, '.');
                    xmlFileName = xmlFileName{1, 1};
                    this.keyValueMap = [this.keyValueMap; this.readXmlFile(xmlFilePath, xmlFileName)];
                end
            else
                error('KSSOLV:Localizer:ResourceFolderNotFound', 'Resources folder not found.');
            end
        end

        function keyValueMap = readXmlFile(~, xmlFilePath, fileName)
            % 读取 XML 文件，并内容转换为键值对 Map
            xmlStruct = readstruct(xmlFilePath, "FileType", "xml");
            entries = xmlStruct.message.entry;
            keyValueMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
            for i = 1:numel(entries)
                key = strcat('KSSOLV:', fileName, ':', entries(i).keyAttribute);
                value = entries(i).Text;
                keyValueMap(key) = value;
            end
        end
    end

    methods (Static, Access = public)
        function instance = getInstance(varargin)
            % 返回类的唯一实例
            narginchk(0, 1);
            persistent userLocale
            if isempty(userLocale)
                temp = feature('locale').messages;
                temp = split(temp, '.');
                userLocale = temp{1, 1};
            end

            persistent uniqueInstance
            if nargin == 0
                % 在无输入参数的情况下
                if ~isempty(uniqueInstance) && isvalid(uniqueInstance)
                    % 若 uniqueInstance 非空，直接返回当前非空的 uniqueInstance 实例
                    instance = uniqueInstance;
                    return
                else
                    % 若 uniqueInstance 为空或已被删除，则需要使用构造函数构造实例
                    locale = userLocale;
                end
            elseif isempty(varargin{1})
                % 若输入参数为 ""，则指定 locale 为 MATLAB 正在使用的界面语言
                locale = userLocale;
            else
                locale = varargin{1};
            end

            % 对尚未实现的本地化默认使用美式英语
            localesFolder = kssolv.ui.util.Localizer.localesFolder;
            implementedLocales = setdiff({dir(localesFolder).name}, {'.', '..'});
            if ~ismember(locale, implementedLocales)
                locale = 'en_US';
            end

            if isempty(uniqueInstance) || ~isvalid(uniqueInstance) || ~strcmp(locale, uniqueInstance.currentLocale)
                % 重载所有的本地化 XML 文件
                uniqueInstance = kssolv.ui.util.Localizer(locale);
            end
            instance = uniqueInstance;
        end

        function setLocale(locale)
            % 手动指定 locale
            kssolv.ui.util.Localizer.getInstance(locale);
        end

        function msg = message(key)
            % 返回给定键的本地化字符串
            instance = kssolv.ui.util.Localizer.getInstance();
            if ~isKey(instance.keyValueMap, key)
                % 开发期间资源文件可能在 MATLAB 会话中被更新。当前语言
                % 的缓存缺少键时重新载入一次，避免异步 UI 回调因旧缓存
                % 中断并留下不一致的控件状态。
                locale = instance.currentLocale;
                delete(instance);
                instance = kssolv.ui.util.Localizer.getInstance(locale);
            end
            if isKey(instance.keyValueMap, key)
                msg = instance.keyValueMap(key);
            else
                % 未找到键时的默认行为
                error('KSSOLV:Localizer:KeyNotFound', 'Key not found.');
            end
        end

        function clearInstance()
            % 清除类的唯一实例
            instance = kssolv.ui.util.Localizer.getInstance();
            delete(instance);
        end
    end
end
