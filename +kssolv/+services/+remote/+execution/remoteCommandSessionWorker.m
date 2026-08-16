function remoteCommandSessionWorker(workspace)
%REMOTECOMMANDSESSIONWORKER Serve commands in one MATLAB base workspace.

workspace = string(workspace);
writePid(fullfile(workspace, "session.pid"), currentProcessId());
writeJson(fullfile(workspace, "ready.json"), struct( ...
    "Version", 1, "ProcessId", currentProcessId(), ...
    "MatlabRelease", string(version("-release"))));
stopPath = fullfile(workspace, "stop");
while ~isfile(stopPath)
    requests = dir(fullfile(workspace, "request-*.json"));
    if isempty(requests)
        pause(0.05);
        continue
    end
    [~, order] = sort(string({requests.name}));
    requests = requests(order);
    for index = 1:numel(requests)
        requestPath = fullfile(workspace, requests(index).name);
        try
            request = jsondecode(fileread(requestPath));
            requestId = string(request.Id);
            try
                output = evalc("base", ...
                    char(string(request.Command))); %#ok<EVLC>
                succeeded = true;
            catch exception
                output = exception.getReport( ...
                    "extended", "hyperlinks", "off");
                succeeded = false;
            end
            response = struct("Version", 1, "Id", requestId, ...
                "Succeeded", succeeded, "Output", string(output));
            writeJson(fullfile(workspace, ...
                "response-" + requestId + ".json"), response);
        catch exception
            fallbackId = extractBetween(string(requests(index).name), ...
                "request-", ".json");
            response = struct("Version", 1, "Id", fallbackId, ...
                "Succeeded", false, "Output", string( ...
                exception.getReport("extended", "hyperlinks", "off")));
            writeJson(fullfile(workspace, ...
                "response-" + fallbackId + ".json"), response);
        end
        delete(requestPath);
    end
end
end

function writePid(path, value)
fileId = fopen(path, "w");
if fileId < 0
    error("KSSOLV:Remote:CommandSessionWriteFailed", ...
        "Unable to write %s.", path);
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId, "%d\n", value);
clear cleanup
end

function writeJson(path, value)
temporary = string(path) + ".tmp";
fileId = fopen(temporary, "w", "n", "UTF-8");
if fileId < 0
    error("KSSOLV:Remote:CommandSessionWriteFailed", ...
        "Unable to write %s.", temporary);
end
cleanup = onCleanup(@()fclose(fileId));
fwrite(fileId, unicode2native(jsonencode(value), "UTF-8"), "uint8");
clear cleanup
movefile(temporary, path, "f");
end

function value = currentProcessId()
if exist("matlabProcessID", "file") == 2 || ...
        exist("matlabProcessID", "builtin") == 5
    value = double(matlabProcessID);
else
    value = double(feature("getpid")); %#ok<FEATGPID>
end
end
