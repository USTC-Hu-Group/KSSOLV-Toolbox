classdef ModelingJobsBrowser < handle
    %MODELINGJOBSBROWSER Nonmodal Jobs/Run Browser for resumable batches.
    properties (SetAccess=private)
        Figure
        Widgets struct=struct()
    end
    properties (Access=private)
        Directory string
    end
    methods
        function this=ModelingJobsBrowser(options)
            arguments
                options.directory string= ...
                    kssolv.modeling.ModelingJobStore.defaultDirectory()
                options.visible (1,1) logical=true
            end
            this.Directory=options.directory;
            this.Figure=uifigure("Name", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ModelingJobs"), ...
                "Position",[200,200,760,380], ...
                "Visible","off");
            layout=uigridlayout(this.Figure,[3,1], ...
                "RowHeight",{"1x","fit","fit"},"Padding",12);
            controlTable=uitable(layout,"Data",table(),"RowName",[], ...
                "ColumnEditable",false, ...
                "CellSelectionCallback",@(~,~)this.updateControlState());
            controls=uigridlayout(layout,[1,4], ...
                "ColumnWidth",{"fit","fit","fit","1x"},"Padding",0);
            refresh=uibutton(controls,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:RefreshJobs"), ...
                "ButtonPushedFcn",@(~,~)this.refresh());
            resume=uibutton(controls,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ResumeJob"), ...
                "Enable","off", ...
                "ButtonPushedFcn",@(~,~)this.resumeSelected());
            cancel=uibutton(controls,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:CancelJob"), ...
                "Enable","off", ...
                "ButtonPushedFcn",@(~,~)this.cancelSelected());
            status=uilabel(layout,"Text","","WordWrap","on");
            this.Widgets=struct("Table",controlTable,"Refresh",refresh, ...
                "Resume",resume,"Cancel",cancel,"Status",status);
            this.refresh();
            if options.visible
                kssolv.ui.util.DialogWindow.showCentered(this.Figure);
            else
                movegui(this.Figure,"center");
            end
        end

        function refresh(this)
            jobs=kssolv.modeling.ModelingJobStore.list( ...
                directory=this.Directory);
            if isempty(jobs)
                data=table(strings(0,1),strings(0,1),zeros(0,1), ...
                    zeros(0,1),zeros(0,1),false(0,1),strings(0,1), ...
                    VariableNames=["Id","Status","Completed", ...
                    "Requested","Succeeded","Recoverable","Error"]);
            else
                data=struct2table(jobs);
                data=data(:,["id","status","completed","requested", ...
                    "succeeded","recoverable","error"]);
                data.Properties.VariableNames=["Id","Status", ...
                    "Completed","Requested","Succeeded","Recoverable", ...
                    "Error"];
                data.Status=arrayfun(@localizeJobStatus, ...
                    string(data.Status));
            end
            this.Widgets.Table.Data=data;
            this.Widgets.Table.ColumnName=[
                string(message("JobColumnId"))
                string(message("JobColumnStatus"))
                string(message("JobColumnCompleted"))
                string(message("JobColumnRequested"))
                string(message("JobColumnSucceeded"))
                string(message("JobColumnRecoverable"))
                string(message("JobColumnError"))
                ];
            this.updateControlState();
        end
    end
    methods (Access=private)
        function updateControlState(this)
            enabled=false;
            selection=this.Widgets.Table.Selection;
            data=this.Widgets.Table.Data;
            if ~isempty(selection) && ~isempty(data)
                row=selection(1);
                enabled=row>=1 && row<=height(data) && ...
                    logical(data.Recoverable(row));
            end
            state=matlab.lang.OnOffSwitchState(enabled);
            this.Widgets.Resume.Enable=state;
            this.Widgets.Cancel.Enable=state;
        end

        function id=selectedId(this)
            selection=this.Widgets.Table.Selection;
            if isempty(selection) || isempty(this.Widgets.Table.Data)
                id=""; return
            end
            id=string(this.Widgets.Table.Data.Id(selection(1),1));
        end
        function resumeSelected(this)
            id=this.selectedId(); if id=="", return, end
            try
                this.Widgets.Status.Text=sprintf( ...
                    message("JobRunning"),id); drawnow
                kssolv.modeling.ModelingJobStore.run(id, ...
                    directory=this.Directory);
                this.Widgets.Status.Text=sprintf( ...
                    message("JobCompleted"),id);
            catch exception
                this.Widgets.Status.Text=string(exception.message);
            end
            this.refresh();
        end
        function cancelSelected(this)
            id=this.selectedId(); if id=="", return, end
            try
                kssolv.modeling.ModelingJobStore.requestCancel(id, ...
                    directory=this.Directory);
                this.Widgets.Status.Text=sprintf( ...
                    message("JobCancellationRequested"),id);
            catch exception
                this.Widgets.Status.Text=string(exception.message);
            end
            this.refresh();
        end
    end
end

function value=message(key)
value=kssolv.ui.util.Localizer.message("KSSOLV:modeling:"+key);
end

function value=localizeJobStatus(status)
key="JobStatus"+matlab.lang.makeValidName(char(status), ...
    "ReplacementStyle","delete");
try
    value=string(message(key));
catch exception
    if exception.identifier~="KSSOLV:Localizer:KeyNotFound"
        rethrow(exception)
    end
    value=string(status);
end
end
