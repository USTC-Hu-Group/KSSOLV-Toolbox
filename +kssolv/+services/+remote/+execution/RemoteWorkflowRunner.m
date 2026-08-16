classdef RemoteWorkflowRunner
    %REMOTEWORKFLOWRUNNER Execute a workflow snapshot without UI access.

    methods (Static)
        function envelope = execute(snapshot)
            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                executeCore(snapshot, true);
            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                prepareEnvelopeForTransport(envelope);
        end

        function envelope = executeBridge(snapshot)
            % The remote MATLAB client and its Parallel Server workers use
            % one release; only the serialized, release-neutral snapshot
            % crosses the desktop-to-bridge boundary.
            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                executeCore(snapshot, false);
            envelope = kssolv.services.remote.execution.RemoteWorkflowRunner. ...
                prepareEnvelopeForTransport(envelope);
        end

        function envelope = restoreEnvelopeAfterTransport(envelope)
            %RESTOREENVELOPEAFTERTRANSPORT Reattach transient model state.
            if ~isstruct(envelope) || ~isscalar(envelope) || ...
                    ~isfield(envelope, "Context") || ...
                    ~isa(envelope.Context, "containers.Map")
                return
            end
            context = envelope.Context;
            names = keys(context);
            for index = 1:numel(names)
                value = context(names{index});
                if isobject(value) && ismethod(value, "attachListeners")
                    try
                        value.attachListeners();
                    catch exception
                        error("KSSOLV:Remote:ResultRestoreFailed", ...
                            "Unable to restore result value %s: %s", ...
                            names{index}, exception.message);
                    end
                end
            end
        end
    end

    methods (Static, Access = private)
        function envelope = prepareEnvelopeForTransport(envelope)
            % Event listeners are process-local and cannot be serialized
            % safely across MATLAB workers or releases.
            context = envelope.Context;
            names = keys(context);
            for index = 1:numel(names)
                value = context(names{index});
                if isobject(value) && ismethod(value, "detachListeners")
                    value.detachListeners();
                end
            end
        end

        function envelope = executeCore(snapshot, requireSnapshotRelease)
            kssolv.services.remote.execution.WorkflowSnapshotBuilder.validate(snapshot);
            localRelease = string(version("-release"));
            if requireSnapshotRelease && ...
                    localRelease ~= string(snapshot.MatlabRelease)
                error("KSSOLV:Remote:MatlabReleaseMismatch", ...
                    "Snapshot requires MATLAB %s but worker runs %s.", ...
                    snapshot.MatlabRelease, localRelease);
            end
            localVersion = string(KSSOLV_Toolbox.Version);
            if localVersion ~= string(snapshot.ToolboxVersion)
                error("KSSOLV:Remote:ToolboxVersionMismatch", ...
                    "Snapshot requires KSSOLV %s but worker runs %s.", ...
                    snapshot.ToolboxVersion, localVersion);
            end
            toolboxFile = string(which("KSSOLV_Toolbox"));
            if strlength(toolboxFile) == 0
                error("KSSOLV:Remote:ToolboxRootUnavailable", ...
                    "The KSSOLV Toolbox root is not available on the worker.");
            end
            toolboxRoot = string(fileparts(toolboxFile));
            coreRoot = fullfile(toolboxRoot, "+kssolv", "+core", ...
                "kssolv-3o");
            if isfolder(coreRoot)
                addpath(coreRoot);
            end
            KSSOLV.startup();
            context = containers.Map("KeyType", "char", ...
                "ValueType", "any");
            taskStates = repmat(struct("NodeId", "", ...
                "State", "", "ElapsedSeconds", 0), ...
                numel(snapshot.RemoteTasks), 1);
            totalStart = tic;
            for index = 1:numel(snapshot.RemoteTasks)
                task = snapshot.RemoteTasks(index);
                taskStart = tic;
                context = kssolv.services.remote.execution.ExecutionTaskRegistry. ...
                    execute(task.ClassName, context, task.Options);
                taskStates(index) = struct( ...
                    "NodeId", string(task.NodeId), ...
                    "State", "Finished", ...
                    "ElapsedSeconds", toc(taskStart));
            end
            envelope = struct( ...
                "Version", 1, ...
                "WorkflowName", string(snapshot.WorkflowName), ...
                "ProjectIdentity", string(snapshot.ProjectIdentity), ...
                "Context", context, ...
                "RemoteNodeIds", string(snapshot.RemoteNodeIds(:)), ...
                "LocalNodeIds", string(snapshot.LocalNodeIds(:)), ...
                "TaskStates", taskStates, ...
                "MatlabRelease", localRelease, ...
                "ToolboxVersion", localVersion, ...
                "Hostname", localHostname(), ...
                "SlurmJobId", string(getenv("SLURM_JOB_ID")), ...
                "ElapsedSeconds", toc(totalStart), ...
                "FinishedAt", string(datetime("now", "TimeZone", "UTC", ...
                    "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")));
        end
    end
end

function value = localHostname()
value = strip(string(getenv("HOSTNAME")));
if strlength(value) > 0
    return
end
[status, output] = system("hostname");
if status == 0
    value = strip(string(output));
end
if strlength(value) == 0
    value = "unknown";
end
end
