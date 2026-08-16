classdef FakeSshClient < handle
    properties
        Commands string = strings(0, 1)
        UploadSource (1, 1) string = ""
        UploadTarget (1, 1) string = ""
        DownloadSource (1, 1) string = ""
        DownloadTarget (1, 1) string = ""
    end

    methods
        function result = runCommand(this, command)
            this.Commands(end + 1, 1) = string(command);
            result = struct("exitcode", 0, "stdout", "ok", "stderr", "");
        end

        function copyToRemote(this, source, target)
            this.UploadSource = string(source);
            this.UploadTarget = string(target);
        end

        function copyFromRemote(this, source, target)
            this.DownloadSource = string(source);
            this.DownloadTarget = string(target);
        end
    end
end
