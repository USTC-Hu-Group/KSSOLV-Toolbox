function result = remoteProbe()
%REMOTEPROBE Return non-sensitive scheduler and MATLAB diagnostics.
[numberOfWorkers, poolSize] = workerCapacity();
result = struct( ...
    "Hostname", string(java.net.InetAddress.getLocalHost.getHostName), ...
    "MatlabRelease", string(version("-release")), ...
    "ClusterMatlabRoot", string(matlabroot), ...
    "NumWorkers", numberOfWorkers, ...
    "PoolSize", poolSize, ...
    "SlurmJobId", string(getenv("SLURM_JOB_ID")), ...
    "SlurmArrayJobId", string(getenv("SLURM_ARRAY_JOB_ID")), ...
    "WorkerName", string(getenv("MDCE_WORKER_NAME")), ...
    "Result", 1 + 2, ...
    "Timestamp", datetime("now", "TimeZone", "UTC"));
end

function [numberOfWorkers, poolSize] = workerCapacity()
numberOfWorkers = 1;
try
    numberOfWorkers = double(feature("numcores"));
catch
end
poolSize = numberOfWorkers;
try
    cluster = getCurrentCluster();
    if ~isempty(cluster)
        numberOfWorkers = double(cluster.NumWorkers);
        poolSize = numberOfWorkers;
        if isprop(cluster, "PreferredPoolNumWorkers")
            preferred = double(cluster.PreferredPoolNumWorkers);
            if isfinite(preferred) && preferred > 0
                poolSize = preferred;
            end
        end
    end
catch
end
numberOfWorkers = max(1, floor(numberOfWorkers));
poolSize = max(0, min(numberOfWorkers, floor(poolSize)));
end
