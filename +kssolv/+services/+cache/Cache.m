classdef Cache < handle
    %Cache 缓存服务类，提供持久化的键值存储功能
    %
    %   使用示例：
    %       import kssolv.services.cache.*
    %       Cache.set('userData', struct('name', 'John', 'age', 30));
    %       userData = Cache.get('userData');
    %       Cache.remove('userData');

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties (Access = private, Constant)
        CACHE_FILE = fullfile(kssolv.util.userDataDirectory(), 'Cache.mat')
    end

    properties (Access = private)
        % 静态内部存储字典
        storage
    end

    methods (Access = private)
        function this = Cache()
            % 私有构造函数，确保单例模式
            this.initializeStorage();
        end

        function initializeStorage(this)
            % 初始化存储，尝试从文件加载或创建新存储
            if exist(this.CACHE_FILE, 'file')
                loaded = load(this.CACHE_FILE);
                if isfield(loaded, 'storage')
                    this.storage = loaded.storage;
                else
                    this.storage = containers.Map();
                end
            else
                this.storage = containers.Map();
            end

            % 确保目录存在
            [filePath, ~, ~] = fileparts(this.CACHE_FILE);
            if ~exist(filePath, 'dir')
                mkdir(filePath);
            end
        end
    end

    methods
        function saveToFile(this)
            % 将存储持久化到.mat文件
            storage = this.storage; %#ok<PROP>
            save(this.CACHE_FILE, 'storage', '-v7');
        end
    end

    methods (Static)
        function this = getInstance()
            %GETINSTANCE 单例模式获取唯一实例
            persistent instance
            if isempty(instance)
                instance = kssolv.services.cache.Cache();
            end
            this = instance;
        end

        function set(key, value)
            %SET 设置键值对
            this = kssolv.services.cache.Cache.getInstance();
            this.storage(key) = value;
            this.saveToFile();
        end

        function value = get(key, defaultValue)
            %GET 获取键值，可选提供默认值
            this = kssolv.services.cache.Cache.getInstance();
            if this.storage.isKey(key)
                value = this.storage(key);
            elseif nargin > 1
                value = defaultValue;
            else
                value = [];
            end
        end

        function remove(key)
            %REMOVE 移除特定键
            this = kssolv.services.cache.Cache.getInstance();
            if this.storage.isKey(key)
                remove(this.storage, key);
                this.saveToFile();
            end
        end

        function clearAll()
            %CLEARALL 清空所有缓存
            this = kssolv.services.cache.Cache.getInstance();
            this.storage = containers.Map();
            this.saveToFile();
        end

        function keys = getAllKeys()
            %GETALLKEYS 获取所有键
            this = kssolv.services.cache.Cache.getInstance();
            keys = this.storage.keys;
        end
    end

    methods (Static, Hidden)
        function cacheTest()
            % kssolv.services.cache.Cache.cacheTest()
            import kssolv.services.cache.*

            Cache.clearAll();

            Cache.set("test", rand(3));
            disp(Cache.getAllKeys());
            disp(Cache.get("test"));

            Cache.remove("test");
            disp(Cache.getAllKeys());
            disp(Cache.get("test"));
        end
    end
end

