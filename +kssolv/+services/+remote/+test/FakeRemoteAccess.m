classdef FakeRemoteAccess < handle
    properties
        Commands string = strings(0, 1)
        LoginCommands string = strings(0, 1)
        CompletionMarkers string = strings(0, 1)
        UploadedNames string = strings(0, 1)
        UploadedRequest struct = struct()
        DeletedPaths string = strings(0, 1)
        FailOn (1, 1) string = ""
        Outputs cell = {}
        ToolboxCacheAvailable (1, 1) logical = false
    end

    methods
        function this = FakeRemoteAccess()
            context = containers.Map("KeyType", "char", ...
                "ValueType", "any");
            context("energy") = -1.25;
            this.Outputs = {struct("Context", context)};
        end

        function [status, output] = runCommand(this, command)
            command = string(command);
            this.Commands(end + 1, 1) = command;
            status = 0;
            if strlength(this.FailOn) > 0 && ...
                    contains(command, this.FailOn)
                status = 1;
                output = "simulated remote command failure";
                return
            end
            if contains(command, "KSSOLV_ROUTE_STAGING=")
                output = "KSSOLV_ROUTE_STAGING=/tmp/kssolv-route.fake";
                return
            end
            if contains(command, "test -f --") && ...
                    contains(command, ".kssolv-cache-complete")
                status = double(~this.ToolboxCacheAvailable);
                output = "";
                return
            end
            if contains(command, "mkdir -p")
                output = "";
                return
            end
            if contains(command, "-batch") && ...
                    contains(command, ".kssolv-cache-complete")
                this.ToolboxCacheAvailable = true;
            end
            if contains(command, "submit")
                state = "Queued";
            elseif contains(command, "cancel")
                state = "Cancelled";
            elseif contains(command, "fetch")
                state = "Retrieved";
            else
                state = "Finished";
            end
            value = struct( ...
                "Version", 1, ...
                "BridgeMatlabRelease", "2024a", ...
                "MatlabProfileName", "remote-slurm", ...
                "MatlabJobId", 42, ...
                "SchedulerJobIds", "8675309", ...
                "SubmittedAt", "2026-08-14T00:00:00.000Z", ...
                "State", state, ...
                "Diary", "bridge diary", ...
                "ErrorIdentifier", "", ...
                "ErrorSummary", "", ...
                "UpdatedAt", "2026-08-14T00:00:01.000Z");
            output = "MATLAB output" + newline + ...
                "KSSOLV_BRIDGE_STATUS:" + string(jsonencode(value));
        end

        function [status, output] = runLoginCommand(this, command)
            this.LoginCommands(end + 1, 1) = string(command);
            [status, output] = this.runCommand(command);
        end

        function [status, output] = runCommandUntilMarker(this, ...
                command, marker)
            this.CompletionMarkers(end + 1, 1) = string(marker);
            [status, output] = this.runCommand(command);
        end

        function copyFileToRemote(this, source, ~)
            source = string(source);
            [~, name, extension] = fileparts(source);
            this.UploadedNames(end + 1, 1) = name + extension;
            if name + extension == "request.json"
                this.UploadedRequest = jsondecode(fileread(source));
            end
        end

        function copyFileFromRemote(this, ~, destination)
            outputs = this.Outputs;
            save(fullfile(destination, "result.mat"), "outputs", "-v7");
        end

        function remoteDelete(this, path)
            this.DeletedPaths(end + 1, 1) = string(path);
        end
    end
end
