classdef LocalRemoteAccess < handle
    %LOCALREMOTEACCESS Exercise remote command plumbing on the local host.

    methods
        function [status, output] = runCommand(~, command)
            [status, output] = system(command);
        end

        function copyFileToRemote(~, source, destination)
            [copied, detail] = copyfile(source, destination);
            if ~copied
                error("KSSOLV:Remote:TestCopyFailed", "%s", detail);
            end
        end

        function copyFileFromRemote(~, source, destination)
            [copied, detail] = copyfile(source, destination);
            if ~copied
                error("KSSOLV:Remote:TestCopyFailed", "%s", detail);
            end
        end

        function remoteDelete(~, path)
            if isfolder(path)
                rmdir(path, "s");
            elseif isfile(path)
                delete(path);
            end
        end
    end
end
