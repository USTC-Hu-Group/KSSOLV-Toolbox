classdef ModelingLibraryBrowser < handle
    %MODELINGLIBRARYBROWSER Browse presets, recipes, and project templates.
    properties (SetAccess=private)
        Figure
        Widgets struct=struct()
    end
    properties (Access=private)
        PresetDirectory string
        RecipeDirectory string
        TemplateDirectory string
    end
    methods
        function this=ModelingLibraryBrowser(options)
            arguments
                options.visible (1,1) logical=true
                options.presetDirectory string= ...
                    kssolv.modeling.provenance.ParameterPresetLibrary. ...
                    defaultDirectory()
                options.recipeDirectory string= ...
                    kssolv.modeling.provenance.RecipeLibrary.defaultDirectory()
                options.templateDirectory string= ...
                    kssolv.modeling.provenance.ProjectTemplateLibrary. ...
                    defaultDirectory()
            end
            this.PresetDirectory=options.presetDirectory;
            this.RecipeDirectory=options.recipeDirectory;
            this.TemplateDirectory=options.templateDirectory;
            this.Figure=uifigure("Name", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ModelingLibraries"), ...
                "Position",[240,220,700,358], ...
                "Visible","off");
            layout=uigridlayout(this.Figure,[2,1], ...
                "RowHeight",{"1x","fit"}, ...
                "Padding",[12,9,12,12]);
            controlTable=uitable(layout,"Data",table(),"RowName",[], ...
                "ColumnEditable",false);
            buttons=uigridlayout(layout,[1,3], ...
                "ColumnWidth",{"fit","fit","1x"},"Padding",0);
            refresh=uibutton(buttons,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:RefreshJobs"), ...
                "ButtonPushedFcn",@(~,~)this.refresh());
            create=uibutton(buttons,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:NewProjectTemplate"), ...
                "ButtonPushedFcn",@(~,~)this.createTemplate());
            status=uilabel(buttons,"Text","","WordWrap","on");
            this.Widgets=struct("Table",controlTable,"Refresh",refresh, ...
                "CreateTemplate",create,"Status",status);
            this.refresh();
            if options.visible
                kssolv.ui.util.DialogWindow.showCentered(this.Figure);
            else
                movegui(this.Figure,"center");
            end
        end

        function refresh(this)
            type=strings(0,1); name=strings(0,1); detail=strings(0,1);
            presets=kssolv.modeling.provenance.ParameterPresetLibrary.list( ...
                directory=this.PresetDirectory);
            for index=1:numel(presets)
                type(end+1,1)=message("LibraryTypePreset"); %#ok<AGROW>
                name(end+1,1)=string(presets(index).name); %#ok<AGROW>
                if string(presets(index).error)==""
                    detail(end+1,1)=string(presets(index).commandId); %#ok<AGROW>
                else
                    detail(end+1,1)=invalidDetail(presets(index).error); %#ok<AGROW>
                end
            end
            recipes=kssolv.modeling.provenance.RecipeLibrary.list( ...
                directory=this.RecipeDirectory);
            for index=1:numel(recipes)
                type(end+1,1)=message("LibraryTypeRecipe"); %#ok<AGROW>
                name(end+1,1)=recipes(index); %#ok<AGROW>
                try
                    kssolv.modeling.provenance.RecipeLibrary.load( ...
                        recipes(index),directory=this.RecipeDirectory);
                    detail(end+1,1)=message("SchemaVersionOne"); %#ok<AGROW>
                catch exception
                    detail(end+1,1)=invalidDetail(exception.message); %#ok<AGROW>
                end
            end
            templates=kssolv.modeling.provenance.ProjectTemplateLibrary.list( ...
                directory=this.TemplateDirectory);
            for index=1:numel(templates)
                type(end+1,1)=message("LibraryTypeProjectTemplate"); %#ok<AGROW>
                name(end+1,1)=templates(index); %#ok<AGROW>
                try
                    value=kssolv.modeling.provenance.ProjectTemplateLibrary. ...
                        load(templates(index),directory=this.TemplateDirectory);
                    detail(end+1,1)=string(value.recipeName)+" | "+ ...
                        string(value.inputFormat)+" -> "+ ...
                        string(value.outputFormat); %#ok<AGROW>
                catch exception
                    detail(end+1,1)=invalidDetail(exception.message); %#ok<AGROW>
                end
            end
            this.Widgets.Table.Data=table(type,name,detail, ...
                VariableNames=["Type","Name","Detail"]);
            this.Widgets.Table.ColumnName=[
                string(message("LibraryColumnType"))
                string(message("LibraryColumnName"))
                string(message("LibraryColumnDetail"))
                ];
        end
    end
    methods (Access=private)
        function createTemplate(this)
            answer=inputdlg({message("TemplateNamePrompt"), ...
                message("RecipeNamePrompt"), ...
                message("InputFormatPrompt"), ...
                message("OutputFormatPrompt")}, ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:NewProjectTemplate"),1, ...
                {message("DefaultProjectTemplateName"),"","auto","same"});
            if isempty(answer), return, end
            try
                kssolv.modeling.provenance.ProjectTemplateLibrary.save( ...
                    string(answer{1}),struct("recipeName",string(answer{2}), ...
                    "inputFormat",string(answer{3}), ...
                    "outputFormat",string(answer{4}), ...
                    "projectMetadata",struct()), ...
                    directory=this.TemplateDirectory);
                this.Widgets.Status.Text=kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:ProjectTemplateSaved");
                this.refresh();
            catch exception
                this.Widgets.Status.Text=string(exception.message);
            end
        end
    end
end

function value=invalidDetail(message)
format=kssolv.ui.util.Localizer.message( ...
    "KSSOLV:modeling:InvalidLibraryEntry");
value=string(sprintf(format,string(message)));
end

function value=message(key)
value=kssolv.ui.util.Localizer.message("KSSOLV:modeling:"+key);
end
