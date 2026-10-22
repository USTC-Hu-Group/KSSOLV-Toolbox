classdef Environment < handle
    %ENVIRONMENT 管理 Python 虚拟环境及依赖
    %   使用方法：
    %       PYTHONENVIRONMENT = kssolv.services.python.Environment.getInstance();
    %       初始化并切换至 KSSOLV Toolbox 使用的 Python 虚拟环境
    %
    %       delete(PYTHONENVIRONMENT)
    %       关闭 KSSOLV Toolbox 使用的 Python 虚拟环境，切换回默认的 Python 环境

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    properties
        % Python 解释器路径（虚拟环境内）
        pythonExecutable (1, :) char
    end

    properties (Constant)
        % 虚拟环境绝对路径
        virtualEnvironmentPath (1, :) char = fullfile(kssolv.util.userDataDirectory(), 'python', 'venv')
    end

    properties (Access = private)
        % 原有的 pyenv 设置备份
        environmentBackup (1, 1) struct
    end

    methods (Static)
        function initialize()
            %INITIALIZE 初始化并切换 Python 环境
            kssolv.services.python.Environment.getInstance();
        end

        function singletonInstance = getInstance(reset)
            %GETINSTANCE 单例模式获取唯一实例，reset 为 true 时清除 instance 变量
            arguments
                reset (1, 1) logical = false
            end

            persistent instance
            if reset
                instance = [];
            else
                if isempty(instance) || ~isvalid(instance)
                    instance = kssolv.services.python.Environment();
                end
            end

            singletonInstance = instance;
        end
    end

    methods
        function delete(this)
            % 析构函数，恢复为原有的 pyenv 设置
            if strcmp(pyenv().Status, 'Loaded')
                terminate(pyenv);
            end
            pyenv('Version', this.environmentBackup.Executable, ...
                'ExecutionMode', this.environmentBackup.ExecutionMode);

            % 清除 instance 变量
            kssolv.services.python.Environment.getInstance(true);
        end
    end

    methods (Access = private)
        function this = Environment()
            % 私有构造函数，只能通过 getInstance 获取实例
            this.environmentBackup = struct("Executable", pyenv().Executable, ...
                "ExecutionMode", pyenv().ExecutionMode);
            this.setupVirtualEnvironment();
        end

        function setupVirtualEnvironment(this)
            % 如果虚拟环境不存在，则创建虚拟环境
            if ~isfolder(this.virtualEnvironmentPath)
                fprintf('Creating virtual environment: %s\n', this.virtualEnvironmentPath);
                [status, message] = mkdir(this.virtualEnvironmentPath, 's');
                if status ~= 0
                    error('KSSOLV:python:EnvironmentSetupFailed', 'Directory creation failed: %s', message);
                end

                createVenvCommand = sprintf('%s -m venv "%s"', pyenv().Executable, this.virtualEnvironmentPath);
                [status, result] = system(createVenvCommand);
                if status ~= 0
                    error('KSSOLV:python:EnvironmentSetupFailed', 'Virtual environment creation failed: %s', result);
                end
            end

            % 虚拟环境内的 Python 解释器路径, python 命令名称为 python 或 python3
            pythonCommandParts = split(pyenv().Executable, filesep);
            pythonCommand = fullfile(this.virtualEnvironmentPath, pythonCommandParts{end-1}, pythonCommandParts{end});
            assert(isfile(pythonCommand), 'Python interpreter not found: %s', pythonCommand);
            this.pythonExecutable = pythonCommand;

            % 配置 MATLAB 的 Python 环境
            if ~strcmp(pyenv().Executable, this.pythonExecutable)
                if strcmp(pyenv().Status, 'Loaded')
                    terminate(pyenv);
                end
                pyenv('Version', this.pythonExecutable, 'ExecutionMode', 'OutOfProcess');
            end

            % 安装或升级 pip
            kssolv.services.python.pipInstall("pip", "upgrade", true);
        end
    end
end

