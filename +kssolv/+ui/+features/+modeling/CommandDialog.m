classdef CommandDialog < controllib.ui.internal.dialog.AbstractDialog
    %COMMANDDIALOG Schema-driven modal editor for one Modeling command.

    properties (SetAccess = private)
        Parameters (1,1) struct = struct()
        Cancelled (1,1) logical = true
        Widgets (1,1) struct = struct()
    end

    properties (Access = private)
        CommandInfo (1,1) struct
        Display
        Fields
        Preset (1,1) struct = struct()
        DialogLayout
        FormLayout
        FieldEntries (1,1) struct = struct()
        IsClosing (1,1) logical = false
        Width (1,1) double = 560
        Height (1,1) double = 160
        FormHeight (1,1) double = 70
        HelpExpanded (1,1) logical = false
        HelpContentHeight (1,1) double = 0
        ActivePreview (1,1) logical = false
    end

    methods
        function this = CommandDialog(commandInfo, display, preset)
            arguments
                commandInfo (1,1) struct
                display
                preset (1,1) struct = struct()
            end
            this.CommandInfo = commandInfo;
            this.Display = display;
            this.Preset = preset;
            this.Fields = ...
                kssolv.ui.features.modeling.ParameterSchema.forCommand( ...
                commandInfo.id, display);
            this.Title = kssolv.ui.util.Localizer.message( ...
                commandInfo.labelKey);

            figure = this.getWidget();
            figure.CloseRequestFcn = @(~, ~)this.cancel();
            figure.WindowStyle = "modal";
            figure.Resize = "off";
        end

        function [parameters, cancelled] = show(this, varargin)
            figure = this.getWidget();
            if isempty(varargin)
                appContainer = ...
                    kssolv.ui.util.DataStorage.getData("AppContainer");
                if ~isempty(appContainer) && isvalid(appContainer)
                    show@controllib.ui.internal.dialog.AbstractDialog( ...
                        this, appContainer);
                else
                    show@controllib.ui.internal.dialog.AbstractDialog( ...
                        this, []);
                end
            else
                show@controllib.ui.internal.dialog.AbstractDialog( ...
                    this, varargin{:});
            end
            uiwait(figure);
            parameters = this.Parameters;
            cancelled = this.Cancelled;
        end

        function close(this)
            this.clearPreview();
            if ~this.IsClosing
                this.Parameters = struct();
                this.Cancelled = true;
                this.IsClosing = true;
            end
            figure = this.getWidget();
            close@controllib.ui.internal.dialog.AbstractDialog(this);
            if isvalid(figure) && strcmp(figure.BeingDeleted, "off")
                uiresume(figure);
            end
        end

    end

    methods (Hidden)
        function gap = actionTopGap(this)
            action = getpixelposition(this.Widgets.ApplyButton, true);
            if strcmp(this.Widgets.StatusLabel.Visible, "on")
                neighbor = this.Widgets.StatusLabel;
            elseif isfield(this.Widgets, "HelpPanel") && ...
                    strcmp(this.Widgets.HelpPanel.Visible, "on")
                neighbor = this.Widgets.HelpPanel;
            elseif isfield(this.Widgets, "HelpToggleButton")
                neighbor = this.Widgets.HelpToggleButton;
            else
                neighbor = this.Widgets.FormPanel;
            end
            neighborPosition = getpixelposition(neighbor, true);
            gap = neighborPosition(2) - (action(2) + action(4));
        end

        function metrics = layoutAuditMetrics(this)
            metrics = struct( ...
                "formHeight", this.FormHeight, ...
                "helpExpanded", this.HelpExpanded, ...
                "statusVisible", ...
                string(this.Widgets.StatusLabel.Visible) == "on", ...
                "figureHeight", this.getWidget().Position(4));
        end

    end

    methods (Access = protected)
        function buildUI(this)
            figure = this.getWidget();
            figure.Position(3:4) = [this.Width, this.Height];

            this.DialogLayout = uigridlayout(figure, [4, 1], ...
                "RowHeight", {"fit", this.FormHeight, 0, "fit"}, ...
                "ColumnWidth", {"1x"}, ...
                "RowSpacing", 10, ...
                "Padding", [14, 16, 14, 12], ...
                "Scrollable", "off");

            this.buildHeader();
            this.buildForm();
            this.Widgets.FormLayout = this.FormLayout;
            this.buildHelp();
            this.buildButtons();
            this.loadInitialValues();
            this.applyConditions();
        end
    end

    methods (Access = private)
        function buildHeader(this)
            header = uigridlayout(this.DialogLayout, [3, 1], ...
                "RowHeight", {"fit", "fit", "fit"}, ...
                "ColumnWidth", {"1x"}, ...
                "RowSpacing", 3, ...
                "Padding", 0);
            header.Layout.Row = 1;

            titleLabel = uilabel(header, ...
                "Text", this.Title, ...
                "FontSize", 16, ...
                "FontWeight", "bold");
            titleLabel.Layout.Row = 1;
            descriptionLabel = uilabel(header, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                this.CommandInfo.tooltipKey), ...
                "FontColor", [0.35, 0.35, 0.35], ...
                "WordWrap", "on");
            descriptionLabel.Layout.Row = 2;
            presetLayout=uigridlayout(header,[1,4], ...
                "ColumnWidth",{"fit","1x","fit","fit"}, ...
                "ColumnSpacing",6,"Padding",0);
            presetLayout.Layout.Row=3;
            presetLabel=uilabel(presetLayout,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:ParameterPresets"));
            entries=kssolv.modeling.provenance.ParameterPresetLibrary. ...
                list(this.CommandInfo.id);
            names=string({entries.name});
            items=[string(kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:NoPreset"));reshape(names,[],1)];
            data=["";reshape(names,[],1)];
            presetDropDown=uidropdown(presetLayout,"Items",cellstr(items), ...
                "ItemsData",cellstr(data));
            loadButton=uibutton(presetLayout,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:LoadPreset"), ...
                "ButtonPushedFcn",@(~,~)this.loadSavedPreset());
            saveButton=uibutton(presetLayout,"Text", ...
                kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:SavePreset"), ...
                "ButtonPushedFcn",@(~,~)this.saveCurrentPreset());
            this.Widgets.TitleLabel = titleLabel;
            this.Widgets.DescriptionLabel = descriptionLabel;
            this.Widgets.PresetLabel=presetLabel;
            this.Widgets.PresetDropDown=presetDropDown;
            this.Widgets.LoadPresetButton=loadButton;
            this.Widgets.SavePresetButton=saveButton;
        end

        function buildForm(this)
            count = numel(this.Fields);
            panel = uipanel(this.DialogLayout, ...
                "BorderType", "line", ...
                "Scrollable", "off");
            panel.Layout.Row = 2;
            this.Widgets.FormPanel = panel;
            if count == 0
                this.FormLayout = uigridlayout(panel, [1, 1], ...
                    "ColumnWidth", {"1x"}, ...
                    "RowHeight", {"1x"}, ...
                    "Padding", [18, 18, 18, 18]);
                emptyState = uilabel(this.FormLayout, ...
                    "Text", kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:NoParametersRequired"), ...
                    "HorizontalAlignment", "center", ...
                    "VerticalAlignment", "center", ...
                    "WordWrap", "on", ...
                    "FontColor", [0.35, 0.35, 0.35]);
                this.Widgets.EmptyStateLabel = emptyState;
                return
            end
            this.FormLayout = uigridlayout(panel, [count, 1], ...
                "ColumnWidth", {"1x"}, ...
                "RowHeight", repmat({"fit"}, 1, count), ...
                "RowSpacing", 10, ...
                "Padding", [12, 12, 12, 12], ...
                "Scrollable", "on");

            for index = 1:count
                field = this.Fields(index);
                presentation = ...
                    kssolv.ui.features.modeling.ParameterPresentation.describe( ...
                    this.CommandInfo.id, field);
                isLogical = presentation.control == "logical";
                if isLogical
                    fieldLayout = uigridlayout( ...
                        this.FormLayout, [1, 1], ...
                        "ColumnWidth", {"1x"}, ...
                        "RowHeight", {"fit"}, ...
                        "Padding", 0);
                else
                    fieldLayout = uigridlayout( ...
                        this.FormLayout, [2, 1], ...
                        "ColumnWidth", {"1x"}, ...
                        "RowHeight", {"fit", "fit"}, ...
                        "RowSpacing", 4, ...
                        "Padding", 0);
                end
                fieldLayout.Layout.Row = index;

                if isLogical
                    label = [];
                else
                    label = uilabel(fieldLayout, ...
                        "Text", presentation.label, ...
                        "Tooltip", presentation.tooltip, ...
                        "HorizontalAlignment", "left", ...
                        "WordWrap", "on");
                    label.Layout.Row = 1;
                    label.Layout.Column = 1;
                end

                entry = this.createControl( ...
                    fieldLayout, field, presentation);
                if isLogical
                    % The checkbox text is the field label.  This avoids a
                    % redundant label/"Enabled" pair and makes boolean rows
                    % both clearer and more compact.
                    label = entry.container;
                end
                entry.label = label;
                entry.row = index;
                entry.rowContainer = fieldLayout;
                entry.presentation = presentation;
                entry.field = field;
                this.FieldEntries.(char(field.name)) = entry;
                this.Widgets.(char(field.name) + "Label") = label;
                if presentation.control == "matrix"
                    fieldHeights = fieldLayout.RowHeight;
                    fieldHeights{2} = 118;
                    fieldLayout.RowHeight = fieldHeights;
                end
            end
        end

        function buildHelp(this)
            help = kssolv.ui.features.modeling.ParameterHelp.describe( ...
                this.CommandInfo.id);
            if help.key == ""
                return
            end

            layout = uigridlayout(this.DialogLayout, [2, 1], ...
                "RowHeight", {"fit", 0}, ...
                "ColumnWidth", {"1x"}, ...
                "RowSpacing", 6, ...
                "Padding", 0);
            layout.Layout.Row = 3;

            sectionTitle = kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:HelpInformation");
            header = uigridlayout(layout, [1, 3], ...
                "RowHeight", {26}, ...
                "ColumnWidth", {26, "fit", "1x"}, ...
                "ColumnSpacing", 6, ...
                "Padding", 0);
            header.Layout.Row = 1;
            toggleButton = uibutton(header, ...
                "Text", "", ...
                "BackgroundColor", "white", ...
                "Tooltip", sectionTitle, ...
                "ButtonPushedFcn", @(~, ~)this.toggleHelp());
            toggleButton.Layout.Row = 1;
            toggleButton.Layout.Column = 1;
            toggleButton.IconAlignment = "center";
            matlab.ui.control.internal.specifyIconID( ...
                toggleButton, "help", 16);
            helpLabel = uilabel(header, ...
                "Text", sectionTitle, ...
                "FontWeight", "bold", ...
                "VerticalAlignment", "center");
            helpLabel.Layout.Row = 1;
            helpLabel.Layout.Column = 2;

            panel = uipanel(layout, ...
                "BorderType", "line", ...
                "Visible", "off");
            panel.Layout.Row = 2;

            hasFormula = help.formula ~= "";
            if hasFormula
                rowHeights = {"fit", "1x", 48, "fit"};
                rowCount = 4;
            else
                rowHeights = {"fit", "1x"};
                rowCount = 2;
            end
            content = uigridlayout(panel, [rowCount, 1], ...
                "RowHeight", rowHeights, ...
                "ColumnWidth", {"1x"}, ...
                "RowSpacing", 7, ...
                "Padding", [12, 12, 12, 10]);
            titleLabel = uilabel(content, ...
                "Text", help.title, ...
                "FontWeight", "bold", ...
                "WordWrap", "on");
            titleLabel.Layout.Row = 1;
            textLabel = uilabel(content, ...
                "Text", help.text, ...
                "WordWrap", "on", ...
                "VerticalAlignment", "top");
            textLabel.Layout.Row = 2;
            if hasFormula
                formulaLabel = uilabel(content, ...
                    "Text", help.formula, ...
                    "Interpreter", "latex", ...
                    "FontSize", 15, ...
                    "HorizontalAlignment", "center", ...
                    "VerticalAlignment", "center");
                formulaLabel.Layout.Row = 3;
                this.Widgets.HelpFormulaLabel = formulaLabel;
                symbolsLabel = uilabel(content, ...
                    "Text", help.symbols, ...
                    "WordWrap", "on", ...
                    "VerticalAlignment", "top", ...
                    "FontColor", [0.28, 0.28, 0.28]);
                symbolsLabel.Layout.Row = 4;
                this.Widgets.HelpSymbolsLabel = symbolsLabel;
            end

            textLineCount = max(2, min(5, ...
                ceil(strlength(string(help.text)) / 58)));
            symbolLineCount = 0;
            if hasFormula
                symbolLineCount = max(2, min(4, ...
                    ceil(strlength(string(help.symbols)) / 58)));
            end
            this.HelpContentHeight = 52 + 19 * textLineCount + ...
                double(hasFormula) * (48 + 19 * symbolLineCount);
            this.Widgets.HelpLayout = layout;
            this.Widgets.HelpHeaderLayout = header;
            this.Widgets.HelpToggleButton = toggleButton;
            this.Widgets.HelpInformationLabel = helpLabel;
            this.Widgets.HelpPanel = panel;
            this.Widgets.HelpContentLayout = content;
            this.Widgets.HelpTitleLabel = titleLabel;
            this.Widgets.HelpTextLabel = textLabel;

            heights = this.DialogLayout.RowHeight;
            heights{3} = "fit";
            this.DialogLayout.RowHeight = heights;
        end

        function entry = createControl( ...
                this, parent, field, presentation)
            name = char(field.name);
            entry = struct( ...
                "controlType", presentation.control, ...
                "controls", {{}}, ...
                "container", []);
            switch presentation.control
                case "logical"
                    control = uicheckbox(parent, ...
                        "Text", presentation.label, ...
                        "Tooltip", presentation.tooltip);
                    control.Layout.Row = 1;
                    control.Layout.Column = 1;
                    control.ValueChangedFcn = ...
                        @(~, ~)this.applyConditions();
                    entry.controls = {control};
                    entry.container = control;
                case {"enum", "coordinateSystem", "numericEnum"}
                    control = uidropdown(parent, ...
                        "Items", cellstr(presentation.choiceLabels), ...
                        "ItemsData", cellstr(presentation.choices), ...
                        "Tooltip", presentation.tooltip, ...
                        "Interruptible", "off", ...
                        "ValueChangedFcn", ...
                        @(~, ~)this.applyConditions());
                    control.Layout.Row = 2;
                    control.Layout.Column = 1;
                    entry.controls = {control};
                    entry.container = control;
                case "scalar"
                    control = uieditfield(parent, "numeric", ...
                        "Tooltip", presentation.tooltip, ...
                        "ValueChangedFcn", @(~,~)this.applyConditions());
                    control.Layout.Row = 2;
                    control.Layout.Column = 1;
                    entry.controls = {control};
                    entry.container = control;
                case "vector"
                    width = presentation.shape;
                    container = uigridlayout( ...
                        parent, [1, width], ...
                        "RowHeight", {"fit"}, ...
                        "ColumnWidth", repmat({"1x"}, 1, width), ...
                        "ColumnSpacing", 6, ...
                        "Padding", 0);
                    container.Layout.Row = 2;
                    container.Layout.Column = 1;
                    controls = cell(1, width);
                    for component = 1:width
                        controls{component} = uieditfield( ...
                            container, "numeric", ...
                            "Tooltip", presentation.tooltip, ...
                            "ValueChangedFcn", ...
                            @(~,~)this.applyConditions());
                        controls{component}.Layout.Column = component;
                    end
                    entry.controls = controls;
                    entry.container = container;
                case "matrix"
                    control = uitable(parent, ...
                        "Data", eye(3), ...
                        "ColumnEditable", true(1, 3), ...
                        "ColumnName", {"x", "y", "z"}, ...
                        "RowName", {"a", "b", "c"}, ...
                        "Tooltip", presentation.tooltip, ...
                        "CellEditCallback", @(~,~)this.applyConditions());
                    control.Layout.Row = 2;
                    control.Layout.Column = 1;
                    entry.controls = {control};
                    entry.container = control;
                case "structure"
                    values = ...
                        kssolv.ui.features.modeling.ModelInputResolver.available( ...
                        this.Display);
                    if isempty(values)
                        labels = kssolv.ui.util.Localizer.message( ...
                            "KSSOLV:modeling:NoAvailableStructures");
                        data = "";
                    else
                        labels = values;
                        data = values;
                    end
                    control = uidropdown(parent, ...
                        "Items", cellstr(labels), ...
                        "ItemsData", cellstr(data), ...
                        "Tooltip", presentation.tooltip, ...
                        "Interruptible", "off");
                    control.Layout.Row = 2;
                    control.Layout.Column = 1;
                    entry.controls = {control};
                    entry.container = control;
                otherwise
                    control = uieditfield(parent, "text", ...
                        "Tooltip", presentation.tooltip, ...
                        "ValueChangedFcn", @(~,~)this.applyConditions());
                    control.Layout.Row = 2;
                    control.Layout.Column = 1;
                    entry.controls = {control};
                    entry.container = control;
            end
            this.Widgets.(name) = entry.container;
        end

        function buildButtons(this)
            layout = uigridlayout(this.DialogLayout, [2, 5], ...
                "RowHeight", {0, "fit"}, ...
                "ColumnWidth", {"fit", "1x", "fit", "fit", "fit"}, ...
                "RowSpacing", 5, ...
                "Padding", 0);
            layout.Layout.Row = 4;

            status = uilabel(layout, ...
                "Text", "", ...
                "FontColor", [0.75, 0.15, 0.10], ...
                "WordWrap", "on", ...
                "Visible", "off");
            status.Layout.Row = 1;
            status.Layout.Column = [1, 5];

            resetButton = uibutton(layout, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Reset"), ...
                "ButtonPushedFcn", @(~, ~)this.loadInitialValues());
            resetButton.Layout.Row = 2;
            resetButton.Layout.Column = 1;
            capability = kssolv.modeling.contracts.CommandCapability. ...
                forCommand(this.CommandInfo.id);
            previewButton = uibutton(layout, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Preview"), ...
                "Enable", matlab.lang.OnOffSwitchState( ...
                capability.supportsPreview), ...
                "Tooltip", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:PreviewTooltip"), ...
                "ButtonPushedFcn", @(~, ~)this.preview());
            previewButton.Layout.Row = 2;
            previewButton.Layout.Column = 3;
            cancelButton = uibutton(layout, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Cancel"), ...
                "ButtonPushedFcn", @(~, ~)this.cancel());
            cancelButton.Layout.Row = 2;
            cancelButton.Layout.Column = 4;
            applyButton = uibutton(layout, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Apply"), ...
                "ButtonPushedFcn", @(~, ~)this.apply());
            applyButton.Layout.Row = 2;
            applyButton.Layout.Column = 5;

            this.Widgets.StatusLabel = status;
            this.Widgets.ButtonLayout = layout;
            this.Widgets.ResetButton = resetButton;
            this.Widgets.PreviewButton = previewButton;
            this.Widgets.CancelButton = cancelButton;
            this.Widgets.ApplyButton = applyButton;
        end

        function toggleHelp(this)
            this.HelpExpanded = ~this.HelpExpanded;
            heights = this.Widgets.HelpLayout.RowHeight;
            if this.HelpExpanded
                heights{2} = this.HelpContentHeight;
                this.Widgets.HelpPanel.Visible = "on";
            else
                heights{2} = 0;
                this.Widgets.HelpPanel.Visible = "off";
            end
            this.Widgets.HelpLayout.RowHeight = heights;
            this.updateDialogSize();
            this.updatePolymerEstimate();
        end

        function updatePolymerEstimate(this)
            if ~isfield(this.Widgets,"StatusLabel") || this.ActivePreview || ...
                    ~kssolv.modeling.polymers.PolymerCommands.supports( ...
                    this.CommandInfo.id) || ...
                    string(this.CommandInfo.id)=="save_user_repeat_unit"
                return
            end
            try
                parameters=this.readParameters();
                estimate=kssolv.modeling.polymers.PolymerCommands.estimate( ...
                    this.CommandInfo.id,parameters);
                if isempty(estimate), return, end
                if estimate.warning
                    key="KSSOLV:modeling:PolymerAtomEstimateWarning";
                    color=[.75,.35,.08];
                else
                    key="KSSOLV:modeling:PolymerAtomEstimate";
                    color=[.20,.38,.58];
                end
                this.Widgets.StatusLabel.Text=sprintf( ...
                    kssolv.ui.util.Localizer.message(key), ...
                    estimate.estimatedAtoms);
                this.Widgets.StatusLabel.FontColor=color;
                this.Widgets.StatusLabel.Visible="on";
                this.updateDialogSize();
            catch
                % Incomplete edits should not replace normal field validation.
            end
        end

        function loadInitialValues(this)
            this.clearPreview();
            if isempty(fieldnames(this.FieldEntries))
                return
            end
            for index = 1:numel(this.Fields)
                field = this.Fields(index);
                name = char(field.name);
                value = this.defaultValue(field);
                this.setEntryValue(this.FieldEntries.(name), value);
            end
            this.Widgets.StatusLabel.Text = "";
            this.Widgets.StatusLabel.Visible = "off";
            this.applyConditions();
        end

        function loadSavedPreset(this)
            name=string(this.Widgets.PresetDropDown.Value);
            if name=="", return, end
            try
                value=kssolv.modeling.provenance.ParameterPresetLibrary. ...
                    load(this.CommandInfo.id,name);
                fields=fieldnames(value.parameters);
                for index=1:numel(fields)
                    fieldName=fields{index};
                    if isfield(this.FieldEntries,fieldName)
                        this.setEntryValue(this.FieldEntries.(fieldName), ...
                            value.parameters.(fieldName));
                    end
                end
                this.applyConditions();
            catch exception
                this.showStatus(exception.message,[.75,.15,.10]);
            end
        end

        function saveCurrentPreset(this)
            try
                parameters=this.readParameters();
                answer=inputdlg(kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:PresetNamePrompt"), ...
                    kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:SavePreset"),1,{""});
                if isempty(answer), return, end
                name=strtrim(string(answer{1}));
                kssolv.modeling.provenance.ParameterPresetLibrary.save( ...
                    this.CommandInfo.id,name,parameters);
                control=this.Widgets.PresetDropDown;
                if ~any(string(control.ItemsData)==name)
                    control.Items=[control.Items,{char(name)}];
                    control.ItemsData=[control.ItemsData,{char(name)}];
                end
                control.Value=char(name);
                this.showStatus(kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:PresetSaved"),[.10,.45,.18]);
            catch exception
                this.showStatus(exception.message,[.75,.15,.10]);
            end
        end

        function showStatus(this,text,color)
            this.Widgets.StatusLabel.Text=string(text);
            this.Widgets.StatusLabel.FontColor=color;
            this.Widgets.StatusLabel.Visible="on";
            this.updateDialogSize();
        end

        function value = defaultValue(this, field)
            name = char(field.name);
            if isfield(this.Preset, name)
                value = this.Preset.(name);
            elseif endsWith(string(field.name), "StructureName") && ...
                    strlength(strtrim(string(field.defaultValue))) == 0
                value = "";
            else
                value = ...
                    kssolv.ui.features.modeling.ParameterDialog.parseValue( ...
                    field.defaultValue, field.kind, field.label);
            end
        end

        function setEntryValue(~, entry, value)
            switch entry.controlType
                case "logical"
                    entry.controls{1}.Value = logical(value);
                case "coordinateSystem"
                    value = logical(value);
                    if entry.field.name == "cartesian"
                        if value
                            choice = "cartesian";
                        else
                            choice = "fractional";
                        end
                    elseif value
                        choice = "fractional";
                    else
                        choice = "cartesian";
                    end
                    entry.controls{1}.Value = char(choice);
                case "numericEnum"
                    value = string(compose("%.15g", double(value)));
                    entry.controls{1}.Value = char(value);
                case {"enum", "structure"}
                    value = string(value);
                    control = entry.controls{1};
                    available = string(control.ItemsData);
                    if ~any(available == value) && value ~= ""
                        control.Items = [control.Items, {char(value)}];
                        control.ItemsData = [
                            control.ItemsData, {char(value)}];
                    end
                    if any(string(control.ItemsData) == value)
                        control.Value = char(value);
                    end
                case "scalar"
                    entry.controls{1}.Value = double(value);
                case "vector"
                    values = reshape(double(value), 1, []);
                    for index = 1:numel(entry.controls)
                        entry.controls{index}.Value = values(index);
                    end
                case "matrix"
                    entry.controls{1}.Data = double(value);
                otherwise
                    if isnumeric(value)
                        entry.controls{1}.Value = ...
                            char(kssolv.ui.features.modeling.CommandDialog. ...
                            formatNumeric(value));
                    else
                        entry.controls{1}.Value = char(string(value));
                    end
            end
        end

        function applyConditions(this)
            names = fieldnames(this.FieldEntries);
            for index = 1:numel(names)
                entry = this.FieldEntries.(names{index});
                presentation = entry.presentation;
                visible = true;
                if presentation.conditionField ~= ""
                    controller = this.FieldEntries.( ...
                        char(presentation.conditionField));
                    controllerValue = this.readEntryValue( ...
                        controller, false);
                    visible = any(string(controllerValue) == ...
                        presentation.conditionValues);
                end
                entry.label.Visible = ...
                    matlab.lang.OnOffSwitchState(visible);
                entry.container.Visible = ...
                    matlab.lang.OnOffSwitchState(visible);
                entry.rowContainer.Visible = ...
                    matlab.lang.OnOffSwitchState(visible);
                heights = this.FormLayout.RowHeight;
                if visible
                    heights{entry.row} = "fit";
                else
                    heights{entry.row} = 0;
                end
                this.FormLayout.RowHeight = heights;
            end
            this.updateDialogSize();
            this.updatePolymerEstimate();
        end

        function updateDialogSize(this)
            if isempty(this.DialogLayout) || ~isvalid(this.DialogLayout)
                return
            end

            names = fieldnames(this.FieldEntries);
            rowHeights = zeros(1, 0);
            for index = 1:numel(names)
                entry = this.FieldEntries.(names{index});
                if strcmp(entry.rowContainer.Visible, "off")
                    continue
                end
                if entry.controlType == "matrix"
                    rowHeights(end + 1) = 144; %#ok<AGROW>
                elseif entry.controlType == "logical"
                    rowHeights(end + 1) = 24; %#ok<AGROW>
                else
                    rowHeights(end + 1) = 48; %#ok<AGROW>
                end
            end
            if isempty(rowHeights)
                contentHeight = 70;
            else
                contentHeight = sum(rowHeights) + ...
                    10 * (numel(rowHeights) - 1) + 26;
            end
            if this.HelpExpanded
                maximumFormHeight = 400;
            else
                maximumFormHeight = 500;
            end
            this.FormHeight = min(maximumFormHeight, contentHeight);
            if ~isempty(this.FormLayout) && isvalid(this.FormLayout)
                this.FormLayout.Scrollable = ...
                    matlab.lang.OnOffSwitchState( ...
                    contentHeight > maximumFormHeight);
            end
            layoutHeights = this.DialogLayout.RowHeight;
            layoutHeights{2} = this.FormHeight;
            this.DialogLayout.RowHeight = layoutHeights;

            statusHeight = 0;
            if isfield(this.Widgets, "StatusLabel") && ...
                    strcmp(this.Widgets.StatusLabel.Visible, "on")
                % The action layout already contributes the fitted label
                % row and its 5 px internal spacing. Only the remaining
                % client-height allowance belongs in the outer budget.
                statusHeight = 17.25;
                if this.FormHeight >= maximumFormHeight
                    statusHeight = statusHeight - 0.5;
                elseif this.FormHeight > 400
                    statusHeight = statusHeight - 0.75;
                end
            end
            if isfield(this.Widgets, "ButtonLayout") && ...
                    isvalid(this.Widgets.ButtonLayout)
                buttonRowHeights = ...
                    this.Widgets.ButtonLayout.RowHeight;
                if statusHeight > 0
                    buttonRowHeights{1} = "fit";
                else
                    buttonRowHeights{1} = 0;
                end
                this.Widgets.ButtonLayout.RowHeight = buttonRowHeights;
            end
            helpHeight = 0;
            if isfield(this.Widgets, "HelpToggleButton")
                helpHeight = 34;
                if this.HelpExpanded
                    helpHeight = helpHeight + ...
                        this.HelpContentHeight + 6;
                end
            end
            % Budget the full macOS HiDPI height before presentation so the
            % first visible frame already has symmetric action-row spacing.
            chromeHeight = 131.5 + double( ...
                isfield(this.Widgets, "HelpToggleButton"));
            description = string(this.Widgets.DescriptionLabel.Text);
            if strlength(description) > 100
                % At the current 560 px dialog width these long English
                % descriptions wrap to a second line. Account for that
                % line before the window is shown rather than packing it
                % after presentation.
                chromeHeight = chromeHeight + 14.5;
            end
            targetHeight = min(760, max(160, ...
                chromeHeight + this.FormHeight + statusHeight + helpHeight));
            figure = this.getWidget();
            position = figure.Position;
            % Keep the window centered when conditional fields resize it.
            position(1) = position(1) + (position(3) - this.Width) / 2;
            position(2) = position(2) + ...
                (position(4) - targetHeight) / 2;
            position(3:4) = [this.Width, targetHeight];
            figure.Position = position;
            this.Height = targetHeight;
        end

        function apply(this)
            if this.IsClosing
                return
            end
            try
                parameters = this.readParameters();
            catch exception
                this.Widgets.StatusLabel.Text = exception.message;
                this.Widgets.StatusLabel.Visible = "on";
                this.updateDialogSize();
                figure = this.getWidget();
                if strcmp(figure.Visible, "on")
                    uialert(figure, exception.message, ...
                        kssolv.ui.util.Localizer.message( ...
                        "KSSOLV:modeling:ValidationError"));
                else
                    rethrow(exception)
                end
                return
            end
            this.Parameters = parameters;
            this.Cancelled = false;
            this.clearPreview();
            this.finishClose();
        end

        function preview(this)
            if this.IsClosing
                return
            end
            try
                parameters = this.readParameters();
                parameters = ...
                    kssolv.ui.features.modeling.ModelInputResolver.enrich( ...
                    this.CommandInfo.id, parameters);
                transaction = this.Display.previewModelingCommand( ...
                    this.CommandInfo.id, parameters);
                this.Display.showModelingPreview(transaction);
                this.ActivePreview = true;
                this.Widgets.StatusLabel.Text = ...
                    kssolv.ui.util.Localizer.message( ...
                    "KSSOLV:modeling:PreviewActive");
                this.Widgets.StatusLabel.FontColor = [0.10, 0.45, 0.18];
                this.Widgets.StatusLabel.Visible = "on";
                this.updateDialogSize();
            catch exception
                this.ActivePreview = false;
                this.Widgets.StatusLabel.Text = exception.message;
                this.Widgets.StatusLabel.FontColor = [0.75, 0.15, 0.10];
                this.Widgets.StatusLabel.Visible = "on";
                this.updateDialogSize();
            end
        end

        function cancel(this)
            if this.IsClosing
                return
            end
            this.Parameters = struct();
            this.Cancelled = true;
            this.clearPreview();
            this.finishClose();
        end

        function clearPreview(this)
            if ~this.ActivePreview
                return
            end
            this.ActivePreview = false;
            if ~isempty(this.Display) && isvalid(this.Display)
                this.Display.clearModelingPreview();
            end
        end

        function finishClose(this)
            if this.IsClosing
                return
            end
            this.IsClosing = true;
            this.close();
        end

        function parameters = readParameters(this)
            parameters = struct();
            for index = 1:numel(this.Fields)
                field = this.Fields(index);
                name = char(field.name);
                entry = this.FieldEntries.(name);
                if strcmp(entry.container.Visible, "off")
                    continue
                end
                value = this.readEntryValue(entry, true);
                parameters.(name) = value;
            end
        end

        function value = readEntryValue(this, entry, validate)
            switch entry.controlType
                case "logical"
                    value = logical(entry.controls{1}.Value);
                case "coordinateSystem"
                    choice = string(entry.controls{1}.Value);
                    if entry.field.name == "cartesian"
                        value = choice == "cartesian";
                    else
                        value = choice == "fractional";
                    end
                case "numericEnum"
                    value = str2double(string(entry.controls{1}.Value));
                case {"enum", "structure"}
                    value = string(entry.controls{1}.Value);
                case "scalar"
                    value = double(entry.controls{1}.Value);
                case "vector"
                    value = zeros(1, numel(entry.controls));
                    for index = 1:numel(entry.controls)
                        value(index) = ...
                            double(entry.controls{index}.Value);
                    end
                case "matrix"
                    value = double(entry.controls{1}.Data);
                case "numericText"
                    rawValue=strtrim(string(entry.controls{1}.Value));
                    if entry.field.kind=="optionalNumeric" && rawValue==""
                        value=zeros(1,0);
                    else
                        value = kssolv.ui.features.modeling.ParameterDialog. ...
                            parseNumeric(rawValue,entry.presentation.label);
                    end
                otherwise
                    value = strtrim(string(entry.controls{1}.Value));
                    if entry.field.kind == "text" && value == ""
                        error("KSSOLV:Modeling:EmptyParameter", ...
                            "'%s' cannot be empty.", ...
                            entry.presentation.label);
                    end
            end
            if validate
                this.validateValue(entry, value);
            end
        end

        function validateValue(~, entry, value)
            presentation = entry.presentation;
            if isnumeric(value)
                if isempty(value) && entry.field.kind=="optionalNumeric"
                    return
                end
                if isempty(value) || any(~isfinite(value), "all")
                    error("KSSOLV:Modeling:NumericParameter", ...
                        "'%s' must contain finite numeric values.", ...
                        presentation.label);
                end
                if presentation.integer && ...
                        any(abs(value - round(value)) > 1e-9, "all")
                    error("KSSOLV:Modeling:IntegerParameter", ...
                        "'%s' must contain integer values.", ...
                        presentation.label);
                end
                if any(value < presentation.minimum, "all") || ...
                        any(value > presentation.maximum, "all")
                    error("KSSOLV:Modeling:ParameterRange", ...
                        "'%s' is outside the allowed range.", ...
                        presentation.label);
                end
            end

            name = presentation.name;
            if name == "indices" && any(value < 1, "all")
                error("KSSOLV:Modeling:SiteIndices", ...
                    "Site indices use MATLAB one-based positive integers.");
            elseif name == "order" && ...
                    ~isequal(sort(reshape(value, 1, [])), 1:3)
                error("KSSOLV:Modeling:AxisOrder", ...
                    "Axis order must be a permutation of 1, 2 and 3.");
            elseif name == "matrix" && ~isequal(size(value), [3, 3])
                error("KSSOLV:Modeling:LatticeShape", ...
                    "The lattice matrix must be 3-by-3.");
            elseif name == "strain" && ~any(numel(value) == [1, 3])
                error("KSSOLV:Modeling:StrainShape", ...
                    "Strain must be a scalar or a three-component vector.");
            elseif name == "scaling" && ~any(numel(value) == [1, 3])
                error("KSSOLV:Modeling:ScalingShape", ...
                    "Scaling must be an integer or a three-component vector.");
            elseif name == "scalingMatrix"
                if ~(numel(value) == 3 || ...
                        isequal(size(value), [3, 3]))
                    error("KSSOLV:Modeling:ScalingShape", ...
                        "Supercell scaling must contain three factors or a 3-by-3 matrix.");
                elseif isvector(value) && any(value < 1, "all")
                    error("KSSOLV:Modeling:ScalingFactors", ...
                        "Supercell factors must be positive integers.");
                elseif isequal(size(value), [3, 3]) && det(value) == 0
                    error("KSSOLV:Modeling:ScalingMatrix", ...
                        "The integer supercell matrix must be nonsingular.");
                end
            elseif endsWith(name, "StructureName") && string(value) == ""
                error("KSSOLV:Modeling:StructureReference", ...
                    "Select another project structure.");
            end
        end
    end

    methods (Static, Access = private)
        function text = formatNumeric(value)
            value = double(value);
            if isempty(value)
                text = "";
                return
            end
            rows = strings(1, size(value, 1));
            for index = 1:size(value, 1)
                rows(index) = join( ...
                    compose("%.10g", value(index, :)), " ");
            end
            text = join(rows, "; ");
        end
    end
end
