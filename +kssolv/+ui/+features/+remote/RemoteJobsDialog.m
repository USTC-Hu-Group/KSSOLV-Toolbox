classdef RemoteJobsDialog < handle
    %REMOTEJOBSDIALOG Inspect, cancel, fetch and import remote jobs.

    properties (SetAccess = private)
        Figure
        Widgets struct = struct()
        JobManager
    end

    properties (Access = private)
        Records struct
    end

    methods
        function this = RemoteJobsDialog(options)
            arguments
                options.JobManager = ...
                    kssolv.services.remote.job.RemoteJobManager()
                options.Visible (1, 1) logical = true
            end
            this.JobManager = options.JobManager;
            this.buildUI();
            this.reloadFromStore();
            if options.Visible
                kssolv.ui.util.DialogWindow.showCentered(this.Figure);
            else
                movegui(this.Figure, "center");
            end
        end

        function reloadFromStore(this)
            this.Records = this.JobManager.JobStore.list();
            this.refreshTable();
        end

        function refresh(this)
            try
                this.setStatus(remoteMessage("RemoteRefresh") + "…", false);
                drawnow;
                this.Records = this.JobManager.refreshAll();
                this.refreshTable();
                this.setStatus("", false);
            catch exception
                this.setStatus(exception.message, true);
            end
        end
    end

    methods (Access = private)
        function buildUI(this)
            this.Figure = uifigure( ...
                "Name", remoteMessage("RemoteJobsTitle"), ...
                "Position", [140, 140, 1050, 480], ...
                "Visible", "off");
            root = uigridlayout(this.Figure, [2, 1], ...
                "RowHeight", {"1x", 28}, "RowSpacing", 12, ...
                "Padding", 12);
            jobsTable = uitable(root, "Data", table(), "RowName", [], ...
                "ColumnEditable", false, ...
                "SelectionType", "row", "Multiselect", "on", ...
                "SelectionChangedFcn", @(~, ~) ...
                    this.updateActionButtons());
            controls = uigridlayout(root, [1, 7], ...
                "ColumnWidth", {"fit", "fit", "fit", "fit", ...
                "fit", "fit", "1x"}, "Padding", 0);
            refreshButton = uibutton(controls, ...
                "Text", remoteMessage("RemoteRefresh"), ...
                "ButtonPushedFcn", @(~, ~) this.refresh());
            cancelButton = uibutton(controls, ...
                "Text", remoteMessage("RemoteCancelJob"), ...
                "ButtonPushedFcn", @(~, ~) this.cancelSelected());
            fetchButton = uibutton(controls, ...
                "Text", remoteMessage("RemoteFetchImport"), ...
                "ButtonPushedFcn", @(~, ~) this.fetchSelected());
            diaryButton = uibutton(controls, ...
                "Text", remoteMessage("RemoteViewDiary"), ...
                "ButtonPushedFcn", @(~, ~) this.viewDiary());
            cleanupButton = uibutton(controls, ...
                "Text", remoteMessage("RemoteCleanup"), ...
                "ButtonPushedFcn", @(~, ~) this.cleanupSelected());
            deleteButton = uibutton(controls, ...
                "Text", remoteMessage("RemoteDeleteRecord"), ...
                "Enable", "off", ...
                "ButtonPushedFcn", @(~, ~) this.deleteSelected());
            status = uilabel(controls, "Text", "", "WordWrap", "off", ...
                "HorizontalAlignment", "right");
            this.Widgets = struct("Table", jobsTable, ...
                "Refresh", refreshButton, "Cancel", cancelButton, ...
                "Fetch", fetchButton, "Diary", diaryButton, ...
                "Cleanup", cleanupButton, "Delete", deleteButton, ...
                "Status", status, ...
                "Root", root, "Controls", controls);
        end

        function refreshTable(this)
            records = this.Records;
            if isempty(records)
                data = table(strings(0, 1), strings(0, 1), ...
                    strings(0, 1), strings(0, 1), strings(0, 1), ...
                    nan(0, 1), ...
                    strings(0, 1), strings(0, 1), ...
                    VariableNames=["JobId", "Workflow", "Mode", ...
                    "Cluster", "State", "MatlabJobId", "Submitted", ...
                    "Error"]);
            else
                clusterNames = strings(numel(records), 1);
                for index = 1:numel(records)
                    try
                        configuration = this.JobManager. ...
                            ConfigurationStore.get( ...
                            records(index).ConfigurationId);
                        clusterNames(index) = configuration.DisplayName;
                    catch
                        snapshot = records(index).ConfigurationSnapshot;
                        if isstruct(snapshot) && isscalar(snapshot) && ...
                                isfield(snapshot, "DisplayName")
                            clusterNames(index) = snapshot.DisplayName;
                        else
                            clusterNames(index) = ...
                                records(index).ConfigurationId;
                        end
                    end
                end
                submitted = string({records.SubmittedAt}).';
                created = string({records.CreatedAt}).';
                missing = strlength(submitted) == 0;
                submitted(missing) = created(missing);
                data = table(string({records.LocalJobId}).', ...
                    string({records.WorkflowName}).', ...
                    string({records.ExecutionMode}).', clusterNames, ...
                    string({records.State}).', ...
                    double([records.MatlabJobId]).', ...
                    submitted, ...
                    string({records.ErrorSummary}).', ...
                    VariableNames=["JobId", "Workflow", "Mode", ...
                    "Cluster", "State", "MatlabJobId", "Submitted", ...
                    "Error"]);
            end
            this.Widgets.Table.Data = data;
            this.Widgets.Table.ColumnName = [ ...
                remoteMessage("RemoteJobId")
                remoteMessage("RemoteWorkflow")
                remoteMessage("RemoteExecutionMode")
                remoteMessage("RemoteCluster")
                remoteMessage("RemoteState")
                remoteMessage("RemoteMatlabJobId")
                remoteMessage("RemoteSubmittedAt")
                remoteMessage("RemoteError")];
            this.updateActionButtons();
        end

        function [record, index] = selected(this)
            indices = this.selectedRows();
            if isempty(indices)
                error("KSSOLV:Remote:UI:NoJobSelected", ...
                    remoteMessage("RemoteSelectJob"));
            end
            index = indices(1);
            record = this.Records(index);
        end

        function cancelSelected(this)
            try
                [record, ~] = this.selected();
                this.JobManager.cancel(record.LocalJobId);
                this.reloadFromStore();
            catch exception
                this.setStatus(exception.message, true);
            end
        end

        function fetchSelected(this)
            try
                [record, ~] = this.selected();
                if record.ResultImported
                    error("KSSOLV:Remote:UI:ResultAlreadyImported", ...
                        remoteMessage("RemoteResultAlreadyImported"));
                end
                project = kssolv.ui.util.DataStorage.getData("Project");
                if isempty(project)
                    error("KSSOLV:Remote:UI:WorkflowUnavailable", ...
                        remoteMessage("RemoteWorkflowUnavailable"));
                end
                [envelope, record] = this.JobManager.fetchWorkflow( ...
                    record.LocalJobId);
                workflowRoot = project.findChildrenItem("Workflow");
                workflow = workflowRoot.findChildrenItem( ...
                    record.ProjectIdentity);
                if isempty(workflow)
                    workflow = workflowRoot.findChildrenItem( ...
                        record.WorkflowName);
                end
                if isempty(workflow)
                    if ~isempty(string(envelope.LocalNodeIds))
                        error("KSSOLV:Remote:UI:WorkflowUnavailable", ...
                            remoteMessage("RemoteWorkflowUnavailable"));
                    end
                    kssolv.services.workflow.codegeneration.CodeGenerator. ...
                        storeResults(envelope.Context, ...
                        string(envelope.WorkflowName), record.LocalJobId);
                else
                    kssolv.services.workflow.codegeneration.CodeGenerator. ...
                        completeRemoteExecution(workflow.graph, envelope, ...
                        ResultIdentity=record.LocalJobId);
                end
                this.JobManager.markImported(record.LocalJobId);
                this.JobManager.cleanupLocalArtifacts(record.LocalJobId);
                this.reloadFromStore();
                this.setStatus(remoteMessage("RemoteImportComplete"), false);
            catch exception
                this.reloadFromStore();
                this.setStatus(exception.message, true);
            end
        end

        function viewDiary(this)
            try
                [record, ~] = this.selected();
                if ~any(record.State == ["Retrieved", "Failed", ...
                        "Cancelled"])
                    record = this.JobManager.refresh(record.LocalJobId);
                    this.reloadFromStore();
                end
                content = record.Diary;
                if strlength(content) == 0
                    content = remoteMessage("RemoteNoDiary");
                end
                figureHandle = uifigure( ...
                    "Name", remoteMessage("RemoteViewDiary"), ...
                    "Position", [180, 180, 820, 520], ...
                    "Visible", "off");
                area = uitextarea(figureHandle, "Value", content, ...
                    "Editable", "off", "FontName", "monospace", ...
                    "Position", [10, 10, 800, 500]); %#ok<NASGU>
                kssolv.ui.util.DialogWindow.showCentered(figureHandle);
            catch exception
                this.setStatus(exception.message, true);
            end
        end

        function cleanupSelected(this)
            try
                [record, ~] = this.selected();
                answer = uiconfirm(this.Figure, ...
                    remoteMessage("RemoteCleanupConfirmation"), ...
                    remoteMessage("RemoteCleanup"), ...
                    "Options", [remoteMessage("RemoteCleanup"), ...
                    remoteMessage("RemoteClose")], ...
                    "DefaultOption", 2, "CancelOption", 2);
                if answer ~= remoteMessage("RemoteCleanup")
                    return
                end
                this.JobManager.cleanupLocalArtifacts(record.LocalJobId);
                this.reloadFromStore();
            catch exception
                this.setStatus(exception.message, true);
            end
        end

        function deleteSelected(this)
            try
                indices = this.selectedRows();
                if isempty(indices)
                    error("KSSOLV:Remote:UI:NoJobSelected", ...
                        remoteMessage("RemoteSelectJob"));
                end
                records = this.Records(indices);
                message = sprintf( ...
                    remoteMessage("RemoteDeleteRecordsConfirmation"), ...
                    numel(records));
                answer = uiconfirm(this.Figure, ...
                    message, ...
                    remoteMessage("RemoteDeleteRecord"), ...
                    "Options", [remoteMessage("RemoteDeleteRecord"), ...
                    remoteMessage("RemoteClose")], ...
                    "DefaultOption", 2, "CancelOption", 2);
                if answer ~= remoteMessage("RemoteDeleteRecord")
                    return
                end
                localJobIds = string({records.LocalJobId}).';
                this.JobManager.deleteRecords(localJobIds);
                this.Widgets.Table.Selection = [];
                this.reloadFromStore();
                this.setStatus(remoteMessage("RemoteRecordDeleted"), false);
            catch exception
                this.setStatus(exception.message, true);
            end
        end

        function updateActionButtons(this)
            if ~isfield(this.Widgets, "Delete") || ...
                    ~isvalid(this.Widgets.Delete)
                return
            end
            hasSelection = ~isempty(this.selectedRows());
            if hasSelection
                this.Widgets.Delete.Enable = "on";
            else
                this.Widgets.Delete.Enable = "off";
            end
        end

        function rows = selectedRows(this)
            selection = this.Widgets.Table.Selection;
            if isempty(selection) || isempty(this.Records)
                rows = zeros(0, 1);
                return
            end
            if string(this.Widgets.Table.SelectionType) == "row"
                rows = selection(:);
            elseif size(selection, 2) >= 2
                rows = selection(:, 1);
            else
                rows = selection(:);
            end
            rows = unique(double(rows), "stable");
            rows = rows(isfinite(rows) & rows == fix(rows) & ...
                rows >= 1 & rows <= numel(this.Records));
        end

        function setStatus(this, text, isError)
            this.Widgets.Status.Text = string(text);
            this.Widgets.Status.Tooltip = string(text);
            if isError
                this.Widgets.Status.FontColor = [0.75, 0.1, 0.1];
            else
                this.Widgets.Status.FontColor = [0.15, 0.45, 0.2];
            end
        end
    end
end

function value = remoteMessage(key)
value = string(kssolv.ui.util.Localizer.message( ...
    "KSSOLV:dialogs:" + string(key)));
end
