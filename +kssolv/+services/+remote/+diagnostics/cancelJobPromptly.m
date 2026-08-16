function cancelJobPromptly(job)
%CANCELJOBPROMPTLY Cancel without waiting on a local process worker.

if isempty(job) || ~isvalid(job)
    return
end

cluster = job.Parent;
profile = "";
if isprop(cluster, "Profile")
    profile = string(cluster.Profile);
end
if any(profile == ["Processes", "local"])
    try
        % Local cancel(job) waits for the process to exit. Ask the local
        % scheduler to terminate it first, then let the public API record
        % and finalize cancellation below. Fall back safely if this
        % release does not expose the scheduler hook.
        cluster.hCancelJob(job);
    catch
    end
end
cancel(job);
end
