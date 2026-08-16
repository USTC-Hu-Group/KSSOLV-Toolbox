classdef RemoteRunController
    %REMOTERUNCONTROLLER Route a workflow to local or selected remote use.

    methods (Static)
        function [mode, record] = execute(workflow, workflowName, ...
                projectIdentity, options)
            arguments
                workflow kssolv.services.workflow.WorkflowGraph
                workflowName (1, 1) string
                projectIdentity (1, 1) string
                options.ConfigurationStore = ...
                    kssolv.services.remote.config.RemoteConfigurationStore()
                options.SelectionStore = ...
                    kssolv.services.remote.config.RemoteSelectionStore()
                options.JobManager = []
                options.StatusReporter = @footerStatus
            end
            if isdeployed
                mode = "Local";
                record = struct.empty();
                kssolv.services.workflow.codegeneration.CodeGenerator. ...
                    executeTasks(workflow, workflowName);
                return
            end
            selectedId = options.SelectionStore.get( ...
                options.ConfigurationStore);
            if strlength(selectedId) == 0
                mode = "Local";
                record = struct.empty();
                kssolv.services.workflow.codegeneration.CodeGenerator. ...
                    executeTasks(workflow, workflowName);
                return
            end
            try
                configuration = options.ConfigurationStore.get(selectedId);
                report(options.StatusReporter, formatRemoteMessage( ...
                    "RemotePreparingWorkflow", workflowName));
                snapshot = kssolv.services.remote.execution. ...
                    WorkflowSnapshotBuilder.build( ...
                    workflow, workflowName, projectIdentity);
                report(options.StatusReporter, formatRemoteMessage( ...
                    "RemoteSubmittingToCluster", ...
                    configuration.DisplayName));
                manager = options.JobManager;
                if isempty(manager)
                    manager = kssolv.services.remote.job.RemoteJobManager( ...
                        options.ConfigurationStore);
                end
                record = manager.submitWorkflow(selectedId, snapshot);
                mode = "Remote";
                report(options.StatusReporter, formatRemoteMessage( ...
                    "RemoteSubmitted", record.LocalJobId));
            catch exception
                report(options.StatusReporter, formatRemoteMessage( ...
                    "RemoteSubmissionFailed", exception.message));
                rethrow(exception)
            end
        end

        function id = selectedConfigurationId(options)
            arguments
                options.ConfigurationStore = ...
                    kssolv.services.remote.config.RemoteConfigurationStore()
                options.SelectionStore = ...
                    kssolv.services.remote.config.RemoteSelectionStore()
            end
            if isdeployed
                id = "";
                return
            end
            id = options.SelectionStore.get(options.ConfigurationStore);
        end
    end
end

function report(reporter, text)
if isempty(reporter)
    return
end
try
    reporter(string(text));
catch
end
end

function footerStatus(text)
footer = kssolv.ui.util.DataStorage.getData("FooterBar");
if isempty(footer) || ~isvalid(footer)
    return
end
footer.setLabelText(string(text));
drawnow
end

function value = formatRemoteMessage(key, varargin)
arguments
    key (1, 1) string
end
arguments (Repeating)
    varargin
end
template = string(kssolv.ui.util.Localizer.message( ...
    "KSSOLV:dialogs:" + string(key)));
value = string(sprintf(char(template), varargin{:}));
end
