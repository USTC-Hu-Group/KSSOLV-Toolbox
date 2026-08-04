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

    methods (Access = protected)
        function buildUI(this)
            figure = this.getWidget();
            figure.Position(3:4) = [this.Width, this.Height];

            this.DialogLayout = uigridlayout(figure, [3, 1], ...
                "RowHeight", {"fit", this.FormHeight, "fit"}, ...
                "ColumnWidth", {"1x"}, ...
                "RowSpacing", 10, ...
                "Padding", [14, 16, 14, 12], ...
                "Scrollable", "off");

            this.buildHeader();
            this.buildForm();
            this.Widgets.FormLayout = this.FormLayout;
            this.buildButtons();
            this.loadInitialValues();
            this.applyConditions();
        end
    end

    methods (Access = private)
        function buildHeader(this)
            header = uigridlayout(this.DialogLayout, [2, 1], ...
                "RowHeight", {"fit", "fit"}, ...
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
            this.Widgets.TitleLabel = titleLabel;
            this.Widgets.DescriptionLabel = descriptionLabel;
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
                fieldLayout = uigridlayout(this.FormLayout, [2, 1], ...
                    "ColumnWidth", {"1x"}, ...
                    "RowHeight", {"fit", "fit"}, ...
                    "RowSpacing", 4, ...
                    "Padding", 0);
                fieldLayout.Layout.Row = index;

                label = uilabel(fieldLayout, ...
                    "Text", presentation.label, ...
                    "Tooltip", presentation.tooltip, ...
                    "HorizontalAlignment", "left", ...
                    "WordWrap", "on");
                label.Layout.Row = 1;
                label.Layout.Column = 1;

                entry = this.createControl( ...
                    fieldLayout, field, presentation);
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
                        "Text", ...
                        kssolv.ui.util.Localizer.message( ...
                        "KSSOLV:modeling:Enabled"), ...
                        "Tooltip", presentation.tooltip);
                    control.Layout.Row = 2;
                    control.Layout.Column = 1;
                    control.ValueChangedFcn = ...
                        @(~, ~)this.applyConditions();
                    entry.controls = {control};
                    entry.container = control;
                case "enum"
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
                        "Tooltip", presentation.tooltip);
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
                            "Tooltip", presentation.tooltip);
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
                        "Tooltip", presentation.tooltip);
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
                        "Tooltip", presentation.tooltip);
                    control.Layout.Row = 2;
                    control.Layout.Column = 1;
                    entry.controls = {control};
                    entry.container = control;
            end
            this.Widgets.(name) = entry.container;
        end

        function buildButtons(this)
            layout = uigridlayout(this.DialogLayout, [2, 4], ...
                "RowHeight", {0, "fit"}, ...
                "ColumnWidth", {"fit", "1x", "fit", "fit"}, ...
                "RowSpacing", 5, ...
                "Padding", 0);
            layout.Layout.Row = 3;

            status = uilabel(layout, ...
                "Text", "", ...
                "FontColor", [0.75, 0.15, 0.10], ...
                "WordWrap", "on", ...
                "Visible", "off");
            status.Layout.Row = 1;
            status.Layout.Column = [1, 4];

            resetButton = uibutton(layout, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Reset"), ...
                "ButtonPushedFcn", @(~, ~)this.loadInitialValues());
            resetButton.Layout.Row = 2;
            resetButton.Layout.Column = 1;
            cancelButton = uibutton(layout, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Cancel"), ...
                "ButtonPushedFcn", @(~, ~)this.cancel());
            cancelButton.Layout.Row = 2;
            cancelButton.Layout.Column = 3;
            applyButton = uibutton(layout, ...
                "Text", kssolv.ui.util.Localizer.message( ...
                "KSSOLV:modeling:Apply"), ...
                "ButtonPushedFcn", @(~, ~)this.apply());
            applyButton.Layout.Row = 2;
            applyButton.Layout.Column = 4;

            this.Widgets.StatusLabel = status;
            this.Widgets.ButtonLayout = layout;
            this.Widgets.ResetButton = resetButton;
            this.Widgets.CancelButton = cancelButton;
            this.Widgets.ApplyButton = applyButton;
        end

        function loadInitialValues(this)
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
            this.FormHeight = min(500, contentHeight);
            if ~isempty(this.FormLayout) && isvalid(this.FormLayout)
                this.FormLayout.Scrollable = ...
                    matlab.lang.OnOffSwitchState(contentHeight > 500);
            end
            layoutHeights = this.DialogLayout.RowHeight;
            layoutHeights{2} = this.FormHeight;
            this.DialogLayout.RowHeight = layoutHeights;

            statusHeight = 0;
            if isfield(this.Widgets, "StatusLabel") && ...
                    strcmp(this.Widgets.StatusLabel.Visible, "on")
                statusHeight = 34;
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
            targetHeight = min(620, max(160, ...
                104 + this.FormHeight + statusHeight));
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
            this.finishClose();
        end

        function cancel(this)
            if this.IsClosing
                return
            end
            this.Parameters = struct();
            this.Cancelled = true;
            this.finishClose();
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
                    value = ...
                        kssolv.ui.features.modeling.ParameterDialog.parseNumeric( ...
                        entry.controls{1}.Value, ...
                        entry.presentation.label);
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
            rows = strings(1, size(value, 1));
            for index = 1:size(value, 1)
                rows(index) = join( ...
                    compose("%.10g", value(index, :)), " ");
            end
            text = join(rows, "; ");
        end
    end
end
