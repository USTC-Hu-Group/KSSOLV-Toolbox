function kssolvStart(ksFile, hostInBrowser)
%KSSOLVSTART 启动 KSSOLV 图形用户界面
%
% 该函数会展示图形用户界面并阻塞主进程，直到界面关闭。
% 用于编译独立应用程序时作为程序的主入口，以保持界面的持续显示。

% 开发者：杨柳
% 版权 2024-2026 合肥瀚海量子科技有限公司

arguments
    ksFile string = ""
    hostInBrowser (1, 1) logical = kssolv.settings.Environment.hostInBrowser()
end

% 安装程序会使用该参数用来完成 MATLAB Runtime 的用户级初始化。
% Runtime 初始化发生在调用本入口之前，正常返回即可结束预热进程。
if ksFile == "--prewarm"
    prefdir(1);
    return
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
