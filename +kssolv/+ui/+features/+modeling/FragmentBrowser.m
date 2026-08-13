classdef FragmentBrowser < handle
    %FRAGMENTBROWSER Search, inspect, import, export, and attach fragments.

    properties (SetAccess = private)
        Figure matlab.ui.Figure
        Widgets struct = struct()
        Entries struct = struct.empty
    end

    properties (Access = private)
        AttachCallback
        SelectedIndex (1,1) double = 0
    end

    methods
        function this = FragmentBrowser(attachCallback, options)
            arguments
                attachCallback = []
                options.Visible (1,1) logical = true
                options.StorePath string = ""
            end
            this.AttachCallback = attachCallback;
            this.Figure = uifigure( ...
                "Name", message("FragmentBrowser"), ...
                "Position", [100, 100, 900, 554], ...
                "Visible", "off");
            this.Figure.CloseRequestFcn = @(~, ~)delete(this);
            this.build(options.StorePath);
            this.runAction(@()this.refresh(), true);
            if options.Visible
                kssolv.ui.util.DialogWindow.showCentered(this.Figure);
            else
                movegui(this.Figure, "center");
            end
        end

        function delete(this)
            if ~isempty(this.Figure) && isvalid(this.Figure)
                this.Figure.CloseRequestFcn = [];
                delete(this.Figure);
            end
        end

        function refresh(this, query)
            if nargin < 2
                query = string(this.Widgets.Search.Value);
            end
            this.Entries = ...
                kssolv.modeling.fragments.FragmentLibrary.list(query, ...
                storePath = string(this.Widgets.StorePath));
            this.Widgets.Status.Text = "";
            count = numel(this.Entries);
            names = strings(count, 1);
            atoms = zeros(count, 1);
            sources = strings(count, 1);
            tags = strings(count, 1);
            for index = 1:count
                entry = this.Entries(index);
                names(index) = string(entry.name);
                atoms(index) = numel(entry.species);
                sources(index) = localizeSource(entry.source);
                tags(index) = join(string(entry.tags), ", ");
            end
            this.Widgets.Table.Data = table(names, atoms, sources, tags, ...
                'VariableNames', {'Name', 'Atoms', 'Source', 'Tags'});
            this.Widgets.Table.ColumnName = [
                string(message("FragmentColumnName"))
                string(message("FragmentColumnAtoms"))
                string(message("FragmentColumnSource"))
                string(message("FragmentColumnTags"))
                ];
            if count == 0
                this.select(0);
            else
                this.select(1);
            end
        end

        function select(this, index)
            if isempty(index) || index < 1 || index > numel(this.Entries)
                this.SelectedIndex = 0;
                this.Widgets.Details.Value = {message("NoFragments")};
                this.Widgets.Port.Enable = "off";
                this.Widgets.Attach.Enable = "off";
                this.clearPreview();
                return
            end
            this.SelectedIndex = index;
            entry = this.Entries(index);
            this.Widgets.Table.Selection = [index, 1];
            this.Widgets.Details.Value = {
                char(string(entry.name) + " — " + string(entry.description))
                char(message("FragmentFormula") + ": " + ...
                    join(string(entry.species), " "))
                char(message("FragmentTags") + ": " + ...
                    join(string(entry.tags), ", "))
                char(message("FragmentPorts") + ": " + ...
                    join(string({entry.ports.label}), ", "))
                };
            this.Widgets.Port.Items = string({entry.ports.label});
            this.Widgets.Port.ItemsData = string({entry.ports.id});
            this.Widgets.Port.Value = string(entry.ports(1).id);
            this.Widgets.Port.Enable = "on";
            this.updatePortState();
        end

        function attachSelected(this)
            if this.SelectedIndex < 1 || isempty(this.AttachCallback)
                return
            end
            entry = this.Entries(this.SelectedIndex);
            portId = string(this.Widgets.Port.Value);
            port = entry.ports(strcmpi(string({entry.ports.id}), portId));
            head = 1;
            if ~isempty(port) && ~isempty(port(1).headIndices)
                head = port(1).headIndices(1);
            end
            this.AttachCallback(string(entry.name), portId, head);
        end
    end

    methods (Access = private)
        function build(this, storePath)
            layout = uigridlayout(this.Figure, [6, 4], ...
                "RowHeight", {28, "2x", 104, 32, 24, 32}, ...
                "ColumnWidth", {120, "1x", 150, 240}, ...
                "Padding", [14, 7, 14, 14], ...
                "RowSpacing", 8, "ColumnSpacing", 8);
            searchLabel = uilabel(layout, "Text", message("Search"));
            searchLabel.Layout.Row = 1;
            searchLabel.Layout.Column = 1;
            search = uieditfield(layout, "text", ...
                "Placeholder", message("FragmentSearchPlaceholder"), ...
                "ValueChangedFcn", ...
                @(~, ~)this.runAction(@()this.refresh(), true));
            search.Layout.Row = 1;
            search.Layout.Column = [2, 4];
            fragmentTable = uitable(layout, ...
                "ColumnEditable", false(1, 4), ...
                "RowName", {}, ...
                "SelectionType", "row", ...
                "SelectionChangedFcn", @(~, event)this.onSelection(event));
            fragmentTable.Layout.Row = 2;
            fragmentTable.Layout.Column = [1, 3];
            preview = uiaxes(layout, ...
                "Box", "on", ...
                "Color", [0.975, 0.980, 0.988], ...
                "XColor", "none", "YColor", "none", "ZColor", "none");
            preview.Layout.Row = 2;
            preview.Layout.Column = 4;
            preview.Toolbar.Visible = "off";
            preview.Interactions = [];
            view(preview, 3);
            details = uitextarea(layout, "Editable", "off");
            details.Layout.Row = 3;
            details.Layout.Column = [1, 4];
            portLabel = uilabel(layout, "Text", message("ConnectionPort"));
            portLabel.Layout.Row = 4;
            portLabel.Layout.Column = 1;
            port = uidropdown(layout, "Items", "", "ItemsData", "", ...
                "ValueChangedFcn", @(~, ~)this.updatePortState());
            port.Layout.Row = 4;
            port.Layout.Column = 2;
            importButton = uibutton(layout, "push", ...
                "Text", message("ImportFragmentLibrary"), ...
                "ButtonPushedFcn", ...
                @(~, ~)this.runAction(@()this.importLibrary()));
            importButton.Layout.Row = 4;
            importButton.Layout.Column = 3;
            exportButton = uibutton(layout, "push", ...
                "Text", message("ExportFragmentLibrary"), ...
                "ButtonPushedFcn", ...
                @(~, ~)this.runAction(@()this.exportLibrary()));
            exportButton.Layout.Row = 4;
            exportButton.Layout.Column = 4;
            status = uilabel(layout,"Text","","WordWrap","on", ...
                "FontColor",[.75,.15,.10]);
            status.Layout.Row = 5;
            status.Layout.Column = [1,4];
            closeButton = uibutton(layout, "push", ...
                "Text", message("Cancel"), ...
                "ButtonPushedFcn", @(~, ~)delete(this));
            closeButton.Layout.Row = 6;
            closeButton.Layout.Column = [1, 3];
            attachButton = uibutton(layout, "push", ...
                "Text", message("AttachSelectedFragment"), ...
                "ButtonPushedFcn", ...
                @(~, ~)this.runAction(@()this.attachSelected()));
            attachButton.Layout.Row = 6;
            attachButton.Layout.Column = 4;
            this.Widgets = struct( ...
                "Search", search, "Table", fragmentTable, ...
                "Preview", preview, "Details", details, "Port", port, ...
                "Import", importButton, "Export", exportButton, ...
                "Attach", attachButton, "Status", status, ...
                "StorePath", storePath);
        end

        function onSelection(this, event)
            selection = event.Selection;
            if isempty(selection), this.select(0);
            else, this.select(selection(1)); end
        end

        function updatePortState(this)
            if this.SelectedIndex < 1 || ...
                    this.SelectedIndex > numel(this.Entries)
                this.Widgets.Attach.Enable = "off";
                this.clearPreview();
                return
            end
            entry = this.Entries(this.SelectedIndex);
            portId = string(this.Widgets.Port.Value);
            which = find(strcmpi(string({entry.ports.id}), portId), 1);
            this.Widgets.Attach.Enable = "on";
            if isempty(which) || entry.ports(which).mode == "noncovalent"
                this.Widgets.Attach.Enable = "off";
            end
            this.renderPreview();
        end

        function renderPreview(this)
            axesHandle = this.Widgets.Preview;
            cla(axesHandle);
            if this.SelectedIndex < 1 || ...
                    this.SelectedIndex > numel(this.Entries)
                return
            end
            entry = this.Entries(this.SelectedIndex);
            coordinates = double(entry.coordinates);
            hold(axesHandle, "on");
            bonds = double(entry.bonds);
            for bondIndex = 1:size(bonds, 1)
                pair = bonds(bondIndex, 1:2);
                if any(pair < 1) || any(pair > size(coordinates, 1))
                    continue
                end
                points = coordinates(pair, :);
                plot3(axesHandle, points(:, 1), points(:, 2), ...
                    points(:, 3), "-", "Color", [0.42, 0.47, 0.55], ...
                    "LineWidth", 2.5);
            end
            species = string(entry.species);
            for atomIndex = 1:size(coordinates, 1)
                scatter3(axesHandle, coordinates(atomIndex, 1), ...
                    coordinates(atomIndex, 2), coordinates(atomIndex, 3), ...
                    150, elementColor(species(atomIndex)), "filled", ...
                    "MarkerEdgeColor", [0.25, 0.28, 0.34], ...
                    "LineWidth", 0.8);
            end
            portId = string(this.Widgets.Port.Value);
            which = find(strcmpi(string({entry.ports.id}), portId), 1);
            if ~isempty(which)
                heads = double(entry.ports(which).headIndices);
                heads = heads(heads >= 1 & heads <= size(coordinates, 1));
                for head = reshape(heads, 1, [])
                    scatter3(axesHandle, coordinates(head, 1), ...
                        coordinates(head, 2), coordinates(head, 3), ...
                        260, "o", "MarkerEdgeColor", [0.12, 0.48, 0.82], ...
                        "LineWidth", 2.2);
                end
            end
            hold(axesHandle, "off");
            axis(axesHandle, "equal");
            axis(axesHandle, "vis3d");
            axis(axesHandle, "off");
            view(axesHandle, 3);
            axesHandle.Projection = "perspective";
        end

        function clearPreview(this)
            if isfield(this.Widgets, "Preview") && ...
                    ~isempty(this.Widgets.Preview) && ...
                    isvalid(this.Widgets.Preview)
                cla(this.Widgets.Preview);
            end
        end

        function importLibrary(this)
            [name, folder] = uigetfile("*.json", ...
                message("ImportFragmentLibrary"));
            if isequal(name, 0), return, end
            kssolv.modeling.fragments.FragmentLibrary.importStore( ...
                fullfile(folder, name), ...
                storePath = string(this.Widgets.StorePath));
            this.refresh();
        end

        function exportLibrary(this)
            [name, folder] = uiputfile("*.json", ...
                message("ExportFragmentLibrary"), ...
                "kssolv-fragments.json");
            if isequal(name, 0), return, end
            kssolv.modeling.fragments.FragmentLibrary.exportStore( ...
                fullfile(folder, name), ...
                storePath = string(this.Widgets.StorePath));
        end

        function runAction(this,action,resetOnFailure)
            if nargin < 3
                resetOnFailure = false;
            end
            try
                action();
            catch exception
                if resetOnFailure
                    this.Entries=struct.empty;
                    this.Widgets.Table.Data=table();
                    this.select(0);
                end
                this.Widgets.Status.Text=string(exception.message);
            end
        end
    end
end

function value = message(key)
value = kssolv.ui.util.Localizer.message("KSSOLV:modeling:" + key);
end

function value=localizeSource(source)
switch string(source)
    case "builtin"
        value=string(message("FragmentSourceBuiltIn"));
    case "user"
        value=string(message("FragmentSourceUser"));
    otherwise
        value=string(source);
end
end

function color = elementColor(symbol)
switch upper(string(symbol))
    case "H"
        color = [0.90, 0.92, 0.95];
    case "C"
        color = [0.25, 0.28, 0.32];
    case "N"
        color = [0.20, 0.38, 0.78];
    case "O"
        color = [0.86, 0.20, 0.18];
    case "S"
        color = [0.92, 0.72, 0.16];
    case {"F", "CL"}
        color = [0.24, 0.68, 0.35];
    case "BR"
        color = [0.58, 0.22, 0.12];
    case "I"
        color = [0.42, 0.22, 0.62];
    otherwise
        color = [0.48, 0.58, 0.70];
end
end
