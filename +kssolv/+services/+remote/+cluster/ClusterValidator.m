classdef ClusterValidator
    %CLUSTERVALIDATOR Validate a configured remote Slurm cluster.

    methods (Static)
        function report = validate(configuration, options)
            arguments
                configuration struct
                options.Factory = ...
                    kssolv.services.remote.cluster.ClusterFactory()
                options.RunSchedulerValidation (1, 1) logical = true
                options.ReportFile (1, 1) string = ""
                options.NumWorkersToUse (1, 1) double = 1
                options.RunSmokeTest (1, 1) logical = true
                options.SmokeTimeoutSeconds (1, 1) double {mustBePositive} = 300
            end
            started = datetime("now", "TimeZone", "UTC");
            report = struct( ...
                "Succeeded", false, ...
                "StartedAt", started, ...
                "FinishedAt", NaT("TimeZone", "UTC"), ...
                "ProfileName", "", ...
                "MatlabRelease", string(version("-release")), ...
                "Message", "", ...
                "ReportFile", options.ReportFile, ...
                "Probe", struct());
            configuration = kssolv.services.remote.config.RemoteConfiguration. ...
                sanitized(configuration);
            kssolv.services.remote.cluster.ClusterFactory.requireToolbox();
            cluster = options.Factory.ensureProfile(configuration);
            report.ProfileName = string(cluster.Profile);
            if ~options.RunSchedulerValidation
                report.Succeeded = true;
                report.Message = "Cluster profile was created successfully.";
                report.FinishedAt = datetime("now", "TimeZone", "UTC");
                return
            end
            workerCount = min(max(1, options.NumWorkersToUse), ...
                configuration.NumWorkers);
            argumentsList = {"NumWorkersToUse", workerCount};
            if strlength(options.ReportFile) > 0
                argumentsList = [argumentsList, ...
                    {"ReportFile", options.ReportFile}];
            end
            try
                if ~isMATLABReleaseOlderThan("R2026a", "release")
                    validate(cluster, argumentsList{:});
                else
                    parallel.validateProfile(cluster.Profile, ...
                        argumentsList{:});
                end
                report.Succeeded = true;
                report.Message = "Cluster validation completed successfully.";
                if options.RunSmokeTest
                    probeJob = batch(cluster, ...
                        @kssolv.services.remote.diagnostics.remoteProbe, ...
                        1, {});
                    cleanup = onCleanup(@()deleteJob(probeJob));
                    finished = wait(probeJob, "finished", ...
                        options.SmokeTimeoutSeconds);
                    if ~finished
                        cancel(probeJob);
                        error("KSSOLV:Remote:SmokeTestTimeout", ...
                            "The remote smoke job did not finish within %d seconds.", ...
                            options.SmokeTimeoutSeconds);
                    end
                    outputs = fetchOutputs(probeJob);
                    report.Probe = outputs{1};
                    if ~isstruct(report.Probe) || ...
                            ~isfield(report.Probe, "Result") || ...
                            report.Probe.Result ~= 3
                        error("KSSOLV:Remote:InvalidSmokeResult", ...
                            "The remote smoke job returned invalid diagnostics.");
                    end
                    report.Message = ...
                        "Cluster validation and smoke job completed successfully.";
                    clear cleanup
                    deleteJob(probeJob);
                end
            catch exception
                report.Message = string(exception.message);
                report.FinishedAt = datetime("now", "TimeZone", "UTC");
                rethrow(exception)
            end
            report.FinishedAt = datetime("now", "TimeZone", "UTC");
        end
    end
end

function deleteJob(job)
try
    if ~isempty(job) && isvalid(job)
        delete(job);
    end
catch
end
end
