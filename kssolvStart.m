function kssolvStart(ksFile, hostInBrowser)
%KSSOLVSTART 启动 KSSOLV 图形用户界面
%
% 该函数会展示图形用户界面并阻塞主进程，直到界面关闭。
% 用于编译独立应用程序时作为程序的主入口，以保持界面的持续显示。

% 开发者：杨柳
% 版权 2024-2025 合肥瀚海量子科技有限公司

arguments
    ksFile string = ""
    hostInBrowser (1, 1) logical = kssolv.settings.Environment.hostInBrowser()
end

try
    app = kssolv(ksFile, hostInBrowser);
catch exception
    disp(exception.message);
    writelines(exception.message, fullfile(KSSOLV_Toolbox.LogsDirectory, "kssolvStart.log"), "WriteMode", "append");
    return
end

while true
    pause(0.5);
    if ~isvalid(app)
        if nargout == 0
            clear app
        end

        if isdeployed
            quit("force");
        else
            return
        end
    end
end
end
