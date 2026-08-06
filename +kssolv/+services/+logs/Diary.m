classdef Diary < handle
    %DIARY 记录 KSSOLV Toolbox 运行过程中的输出，并显示在运行浏览器中

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    events
        NewOutput     % 当有新输出时触发
    end

    properties (Access = private)
        diaryFile     % 日记文件完整路径
        lastPosition  % 上次读取的文件位置
        fileID        % 日记文件标识符
        timerObject   % 文件监听定时器
        isTimerActive % 监听状态标志
    end

    properties (Access = private, Constant)
        SCAN_INTERVAL = 0.1 % 文件检查间隔(秒)
    end

    methods (Access = private)
        function this = Diary()
            % 私有构造函数，确保单例模式
            this.initializeDiary();
        end

        function initializeDiary(this)
            % 初始化日记文件和目录
            if ~isfolder(KSSOLV_Toolbox.LogsDirectory)
                mkdir(KSSOLV_Toolbox.LogsDirectory);
            end
            this.diaryFile = fullfile(KSSOLV_Toolbox.LogsDirectory, [char(datetime('now', 'Format', 'uuuu-MM-dd HH-mm-ss')), '.log']);

            % 安全关闭现有日记
            if strcmp(get(0, 'Diary'), 'on')
                diary off;
            end

            % 启用新日记
            diary(this.diaryFile);
            diary on;

            % 初始化文件读取位置
            this.lastPosition = 0;
            this.fileID = fopen(this.diaryFile, 'r');
            if this.fileID == -1
                error('无法打开日记文件: %s', this.diaryFile);
            end
        end

        function setupListener(this)
            % 检查是否已存在计时器，重新设置定时文件监听器
            existingTimers = timerfind('Name', 'DiaryFileWatcher');

            % 如果存在则删除旧计时器
            if ~isempty(existingTimers)
                stop(existingTimers);
                delete(existingTimers);
                clear existingTimers;
            end

            % 创建新计时器
            this.timerObject = timer('ExecutionMode', 'fixedRate', ...
                'Period', this.SCAN_INTERVAL, 'TimerFcn', @(~, ~) this.checkForUpdates(), ...
                'Name', 'DiaryFileWatcher');

            % 启动计时器
            this.isTimerActive = true;
            start(this.timerObject);

            % 将计时器中的警告设置为错误
            warning('error', 'MATLAB:callback:error');
        end

        function checkForUpdates(this)
            % 检查文件更新并处理新内容
            if ~this.isTimerActive
                return
            end

            try
                % 获取当前文件大小
                fileInfo = dir(this.diaryFile);
                currentSize = fileInfo.bytes;

                if currentSize > this.lastPosition
                    % 读取新增内容
                    fseek(this.fileID, this.lastPosition, 'bof');
                    newContent = fread(this.fileID, [1, Inf], '*char');
                    this.lastPosition = ftell(this.fileID);

                    % 触发新输出事件
                    if ~isempty(newContent)
                        try
                            notify(this, 'NewOutput', kssolv.services.logs.NewOutputEventData(newContent));
                        catch
                            existingTimers = timerfind('Name', 'DiaryFileWatcher');
                            if ~isempty(existingTimers)
                                stop(existingTimers);
                                delete(existingTimers);
                                clear existingTimers;
                            end
                        end
                    end
                end
            catch ME
                disp('日记监听错误: %s', ME.message);
            end
        end
    end

    methods
        function filePath = getLogFile(this)
            %GETLOGFILE Return the log file used by the current session.
            filePath = string(this.diaryFile);
        end

        function delete(this)
            % 析构函数: 清理资源
            this.isTimerActive = false;
            if isvalid(this.timerObject)
                stop(this.timerObject);
                delete(this.timerObject);
            end
            if this.fileID ~= -1
                fclose(this.fileID);
            end
            diary off;
        end
    end

    methods (Static)
        function this = getInstance(newListener)
            %GETINSTANCE 单例模式获取唯一实例
            arguments
                newListener (1, 1) logical = true
            end

            persistent instance
            if isempty(instance) || ~isvalid(instance)
                instance = kssolv.services.logs.Diary();
            end

            this = instance;

            if newListener
                this.setupListener();
            end
        end

        function clearHistory()
            %CLEARHISTORY 清除历史
            this = kssolv.services.logs.Diary.getInstance();
            this.lastPosition = ftell(this.fileID);
        end
    end
end
