classdef MaterialsProjectDialog < controllib.ui.internal.dialog.AbstractDialog
    %MATERIALSPROJECTDIALOG Search and import Materials Project crystals.

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    properties (SetAccess = private)
        widgets = struct()
    end

    properties (Access = private)
        width = 1180
        height = 780
        importFcn = []
        apiKey (1, 1) string = ""
        apiKeyVisible (1, 1) logical = false
        results = struct([])
        selectedResultIndex (1, 1) double = 0
        requestFuture = []
        completionFuture = []
        requestToken (1, 1) uint64 = uint64(0)
    end

    methods
        function this = MaterialsProjectDialog(importFcn)
            import kssolv.ui.util.Localizer.message

            if nargin >= 1
                if ~isa(importFcn, "function_handle")
                    error("KSSOLV:MaterialsProjectDialog:ImportCallback", ...
                        "Import callback must be a function handle.");
                end
                this.importFcn = importFcn;
            end
            this.Title = message( ...
                "KSSOLV:dialogs:MaterialsProjectDialogTitle");
            this.CloseMode = "hide";
            this.apiKey = kssolv.analysis.matgenlab.ext.matproj. ...
                MPRester.default_api_key();

            figure = this.getWidget();
            figure.CloseRequestFcn = @(~, ~) close(this);
        end

        function close(this)
            import kssolv.ui.util.Localizer.message

            this.stopRequest();
            if isfield(this.widgets, "StatusLabel")
                this.setBusy(false, message( ...
                    "KSSOLV:dialogs:MaterialsProjectReady"));
            end
            close@controllib.ui.internal.dialog.AbstractDialog(this);
        end

    end

    methods (Access = protected)
        function buildUI(this)
            import kssolv.ui.util.Localizer.message

            figure = this.getWidget();
            figure.Position(3:4) = [this.width, this.height];
            layout = uigridlayout(figure, [5, 1], ...
                "RowHeight", {76, 48, 340, "1x", 36}, ...
                "ColumnWidth", {"1x"}, ...
                "RowSpacing", 10, ...
                "Padding", [14, 14, 14, 12]);

            this.buildSearchHeader(layout);
            this.buildSearchMode(layout);
            this.buildPeriodicTable(layout);
            this.buildResultsTable(layout);
            this.buildFooter(layout);
            this.updateAPIKeyDisplay();
            this.updateSelectedElements();
        end
    end

    methods (Access = private)
        function buildSearchHeader(this, parent)
            import kssolv.ui.util.Localizer.message

            layout = uigridlayout(parent, [2, 5], ...
                "RowHeight", {30, 30}, ...
                "ColumnWidth", {105, "1x", 34, 145, 95}, ...
                "RowSpacing", 6, "ColumnSpacing", 7, "Padding", 0);
            layout.Layout.Row = 1;

            keyLabel = uilabel(layout, "Text", ...
                message("KSSOLV:dialogs:MaterialsProjectAPIKey"));
            keyLabel.Layout.Row = 1;
            keyLabel.Layout.Column = 1;
            keyField = uieditfield(layout, "text", ...
                "Placeholder", "32-character API key", ...
                "ValueChangedFcn", @(source, ~) ...
                this.apiKeyChanged(source));
            keyField.Layout.Row = 1;
            keyField.Layout.Column = 2;
            keyVisibility = uibutton(layout, ...
                "Text", "", ...
                "Icon", kssolv.ui.util.GetIcon("eye.svg"), ...
                "ButtonPushedFcn", @(~, ~) this.toggleAPIKeyVisibility());
            keyVisibility.Layout.Row = 1;
            keyVisibility.Layout.Column = 3;
            dashboardButton = uibutton(layout, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectDashboard"), ...
                "ButtonPushedFcn", @(~, ~) web( ...
                "https://materialsproject.org/dashboard", "-browser"));
            dashboardButton.Layout.Row = 1;
            dashboardButton.Layout.Column = 4;

            queryLabel = uilabel(layout, "Text", ...
                message("KSSOLV:dialogs:MaterialsProjectQuery"));
            queryLabel.Layout.Row = 2;
            queryLabel.Layout.Column = 1;
            queryField = uieditfield(layout, "text", ...
                "Placeholder", "LiFePO4 or mp-19017");
            queryField.Layout.Row = 2;
            queryField.Layout.Column = [2, 4];
            searchButton = uibutton(layout, ...
                "Text", message("KSSOLV:dialogs:MaterialsProjectSearch"), ...
                "ButtonPushedFcn", @(~, ~) this.startSearch(), ...
                "Interruptible", "off");
            searchButton.Layout.Row = 2;
            searchButton.Layout.Column = 5;

            this.widgets.APIKeyField = keyField;
            this.widgets.APIKeyVisibilityButton = keyVisibility;
            this.widgets.QueryField = queryField;
            this.widgets.SearchButton = searchButton;
        end

        function buildSearchMode(this, parent)
            import kssolv.ui.util.Localizer.message

            layout = uigridlayout(parent, [1, 2], ...
                "ColumnWidth", {510, "1x"}, "Padding", 0);
            layout.Layout.Row = 2;
            group = uibuttongroup(layout, ...
                "BorderType", "none", ...
                "SelectionChangedFcn", @(~, event) ...
                this.searchModeChanged(event));
            group.Layout.Column = 1;
            only = uiradiobutton(group, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectOnlyElements"), ...
                "Tag", "only", "Position", [8, 8, 155, 26]);
            atLeast = uiradiobutton(group, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectAtLeastElements"), ...
                "Tag", "at-least", "Position", [170, 8, 170, 26]);
            formula = uiradiobutton(group, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectFormulaOrId"), ...
                "Tag", "formula", "Position", [350, 8, 155, 26]);
            group.SelectedObject = only;

            selected = uilabel(layout, ...
                "Text", "", "HorizontalAlignment", "right", ...
                "FontColor", [0.35, 0.35, 0.35]);
            selected.Layout.Column = 2;

            this.widgets.SearchModeGroup = group;
            this.widgets.OnlyElementsButton = only;
            this.widgets.AtLeastElementsButton = atLeast;
            this.widgets.FormulaButton = formula;
            this.widgets.SelectedElementsLabel = selected;
        end

        function buildPeriodicTable(this, parent)
            panel = uipanel(parent, "BorderType", "line");
            panel.Layout.Row = 3;
            grid = uigridlayout(panel, [9, 18], ...
                "RowHeight", repmat({"1x"}, 1, 9), ...
                "ColumnWidth", repmat({"1x"}, 1, 18), ...
                "RowSpacing", 3, "ColumnSpacing", 3, ...
                "Padding", [8, 8, 8, 8]);

            map = this.periodicTableMap();
            elementButtons = struct();
            for row = 1:size(map, 1)
                for column = 1:size(map, 2)
                    symbol = map(row, column);
                    if symbol == ""
                        continue
                    end
                    button = uibutton(grid, "state", ...
                        "Text", char(symbol), ...
                        "FontWeight", "bold", ...
                        "BackgroundColor", this.elementColor(symbol), ...
                        "UserData", symbol, ...
                        "ValueChangedFcn", @(~, ~) ...
                        this.updateSelectedElements());
                    button.Layout.Row = row;
                    button.Layout.Column = column;
                    elementButtons.(char(symbol)) = button;
                end
            end
            this.widgets.ElementButtons = elementButtons;
        end

        function buildResultsTable(this, parent)
            import kssolv.ui.util.Localizer.message

            resultsTable = uitable(parent, ...
                "Data", cell(0, 7), ...
                "ColumnName", { ...
                message("KSSOLV:dialogs:MaterialsProjectIdColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectFormulaColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectSpaceGroupColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectBandGapColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectHullColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectStableColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectSitesColumn")}, ...
                "ColumnWidth", {110, 120, "1x", 105, 125, 70, 70}, ...
                "RowName", {}, ...
                "CellSelectionCallback", @(~, event) ...
                this.resultSelected(event));
            resultsTable.Layout.Row = 4;
            this.widgets.ResultsTable = resultsTable;
        end

        function buildFooter(this, parent)
            import kssolv.ui.util.Localizer.message

            layout = uigridlayout(parent, [1, 4], ...
                "ColumnWidth", {"1x", "fit", "fit", "fit"}, ...
                "Padding", 0);
            layout.Layout.Row = 5;
            status = uilabel(layout, "Text", ...
                message("KSSOLV:dialogs:MaterialsProjectReady"), ...
                "FontColor", [0.35, 0.35, 0.35]);
            status.Layout.Column = 1;
            clearButton = uibutton(layout, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectClearElements"), ...
                "ButtonPushedFcn", @(~, ~) this.clearElements());
            clearButton.Layout.Column = 2;
            importButton = uibutton(layout, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectImportSelected"), ...
                "Enable", "off", ...
                "ButtonPushedFcn", @(~, ~) this.startImport(), ...
                "Interruptible", "off");
            importButton.Layout.Column = 3;
            closeButton = uibutton(layout, ...
                "Text", message("KSSOLV:dialogs:DialogCloseButton"), ...
                "ButtonPushedFcn", @(~, ~) close(this));
            closeButton.Layout.Column = 4;

            this.widgets.StatusLabel = status;
            this.widgets.ClearElementsButton = clearButton;
            this.widgets.ImportButton = importButton;
        end

        function apiKeyChanged(this, editField)
            value = strip(string(editField.Value));
            if ~this.apiKeyVisible && value == this.maskedAPIKey() && ...
                    strlength(this.apiKey) > 0
                return
            end
            this.apiKey = value;
            this.apiKeyVisible = false;
            this.updateAPIKeyDisplay();
        end

        function toggleAPIKeyVisibility(this)
            this.apiKeyVisible = ~this.apiKeyVisible;
            this.updateAPIKeyDisplay();
        end

        function updateAPIKeyDisplay(this)
            import kssolv.ui.util.Localizer.message

            if ~isfield(this.widgets, "APIKeyField")
                return
            end
            if this.apiKeyVisible
                value = this.apiKey;
                icon = "eyeOff.svg";
                tooltip = message( ...
                    "KSSOLV:dialogs:MaterialsProjectHideAPIKey");
            else
                value = "";
                if strlength(this.apiKey) > 0
                    value = this.maskedAPIKey();
                end
                icon = "eye.svg";
                tooltip = message( ...
                    "KSSOLV:dialogs:MaterialsProjectShowAPIKey");
            end
            this.widgets.APIKeyField.Value = char(value);
            this.widgets.APIKeyVisibilityButton.Icon = ...
                kssolv.ui.util.GetIcon(icon);
            this.widgets.APIKeyVisibilityButton.Tooltip = tooltip;
        end

        function searchModeChanged(this, event)
            formulaMode = string(event.NewValue.Tag) == "formula";
            names = fieldnames(this.widgets.ElementButtons);
            for index = 1:numel(names)
                if formulaMode
                    this.widgets.ElementButtons.(names{index}).Enable = "off";
                else
                    this.widgets.ElementButtons.(names{index}).Enable = "on";
                end
            end
            this.updateSelectedElements();
        end

        function updateSelectedElements(this)
            import kssolv.ui.util.Localizer.message

            if ~isfield(this.widgets, "ElementButtons")
                return
            end
            elements = this.selectedElements();
            if isempty(elements)
                text = message( ...
                    "KSSOLV:dialogs:MaterialsProjectNoElementsSelected");
            else
                text = sprintf(message( ...
                    "KSSOLV:dialogs:MaterialsProjectSelectedElements"), ...
                    char(join(elements, ", ")));
            end
            this.widgets.SelectedElementsLabel.Text = text;
        end

        function elements = selectedElements(this)
            names = fieldnames(this.widgets.ElementButtons);
            elements = strings(1, 0);
            for index = 1:numel(names)
                button = this.widgets.ElementButtons.(names{index});
                if button.Value
                    elements(end + 1) = string(button.UserData); %#ok<AGROW>
                end
            end
        end

        function clearElements(this)
            names = fieldnames(this.widgets.ElementButtons);
            for index = 1:numel(names)
                this.widgets.ElementButtons.(names{index}).Value = false;
            end
            this.updateSelectedElements();
        end

        function startSearch(this)
            import kssolv.ui.util.Localizer.message

            keyValue = strip(this.apiKey);
            query = strip(string(this.widgets.QueryField.Value));
            mode = string(this.widgets.SearchModeGroup.SelectedObject.Tag);
            elements = this.selectedElements();
            try
                this.validateSearch(keyValue, query, elements, mode);
            catch exception
                uialert(this.getWidget(), exception.message, ...
                    message("KSSOLV:dialogs:MaterialsProjectInvalidSearch"));
                return
            end

            this.stopRequest();
            this.requestToken = this.requestToken + 1;
            token = this.requestToken;
            this.selectedResultIndex = 0;
            this.results = struct([]);
            this.widgets.ResultsTable.Data = cell(0, 7);
            this.widgets.ImportButton.Enable = "off";
            this.setBusy(true, ...
                message("KSSOLV:dialogs:MaterialsProjectSearching"));
            drawnow;

            future = [];
            try
                future = parfeval(backgroundPool, ...
                    @kssolv.ui.components.dialog.MaterialsProjectDialog.fetchSummaries, ...
                    1, keyValue, query, elements, mode, 100);
                this.requestFuture = future;
                this.completionFuture = afterEach(future, ...
                    @(completed) this.searchFinished(completed, token), ...
                    0, PassFuture = true);
            catch exception
                this.cancelFuture(future);
                this.requestFuture = [];
                this.completionFuture = [];
                this.setBusy(false, this.localizedError(exception));
            end
        end

        function searchFinished(this, future, token)
            import kssolv.ui.util.Localizer.message

            if token ~= this.requestToken
                return
            end
            this.requestFuture = [];
            this.completionFuture = [];
            if ~isempty(future.Error)
                exception = future.Error;
                if iscell(exception)
                    exception = exception{1};
                end
                this.setBusy(false, this.localizedError(exception));
                return
            end

            this.results = future.OutputArguments{1};
            this.widgets.ResultsTable.Data = ...
                this.resultsTableData(this.results);
            if isempty(this.results)
                status = message( ...
                    "KSSOLV:dialogs:MaterialsProjectNoResults");
            else
                status = sprintf(message( ...
                    "KSSOLV:dialogs:MaterialsProjectResultsFound"), ...
                    numel(this.results));
            end
            this.setBusy(false, status);
        end

        function resultSelected(this, event)
            if isempty(event.Indices)
                this.selectedResultIndex = 0;
                this.widgets.ImportButton.Enable = "off";
                return
            end
            row = event.Indices(1, 1);
            if row < 1 || row > numel(this.results)
                return
            end
            this.selectedResultIndex = row;
            this.widgets.ImportButton.Enable = "on";
        end

        function startImport(this)
            import kssolv.ui.util.Localizer.message

            index = this.selectedResultIndex;
            if index < 1 || index > numel(this.results)
                return
            end
            record = this.results(index);
            this.stopRequest();
            this.requestToken = this.requestToken + 1;
            token = this.requestToken;
            this.setBusy(true, sprintf(message( ...
                "KSSOLV:dialogs:MaterialsProjectDownloading"), ...
                char(record.MaterialId)));
            drawnow;

            future = [];
            try
                future = parfeval(backgroundPool, ...
                    @kssolv.ui.components.dialog.MaterialsProjectDialog.fetchStructure, ...
                    1, this.apiKey, record.MaterialId);
                this.requestFuture = future;
                this.completionFuture = afterEach(future, ...
                    @(completed) this.importFinished( ...
                    completed, token, record), ...
                    0, PassFuture = true);
            catch exception
                this.cancelFuture(future);
                this.requestFuture = [];
                this.completionFuture = [];
                this.setBusy(false, this.localizedError(exception));
            end
        end

        function importFinished(this, future, token, record)
            import kssolv.ui.util.Localizer.message

            if token ~= this.requestToken
                return
            end
            this.requestFuture = [];
            this.completionFuture = [];
            if ~isempty(future.Error)
                exception = future.Error;
                if iscell(exception)
                    exception = exception{1};
                end
                this.setBusy(false, this.localizedError(exception));
                return
            end

            try
                model = kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(future.OutputArguments{1});
                if ~isempty(this.importFcn)
                    this.importFcn(record, model);
                end
                this.setBusy(false, sprintf(message( ...
                    "KSSOLV:dialogs:MaterialsProjectImported"), ...
                    char(record.MaterialId)));
            catch exception
                this.setBusy(false, this.localizedError(exception));
            end
        end

        function setBusy(this, busy, status)
            if busy
                state = "off";
            else
                state = "on";
            end
            this.widgets.SearchButton.Enable = state;
            this.widgets.ClearElementsButton.Enable = state;
            if busy || this.selectedResultIndex == 0
                this.widgets.ImportButton.Enable = "off";
            else
                this.widgets.ImportButton.Enable = "on";
            end
            this.widgets.StatusLabel.Text = status;
        end

        function stopRequest(this)
            request = this.requestFuture;
            completion = this.completionFuture;
            this.requestToken = this.requestToken + 1;
            this.requestFuture = [];
            this.completionFuture = [];
            this.cancelFuture(completion);
            this.cancelFuture(request);
        end

        function detail = localizedError(~, exception)
            import kssolv.ui.util.Localizer.message

            value = lower(string(exception.identifier) + " " + ...
                string(exception.message));
            if contains(value, "401") || contains(value, "403") || ...
                    contains(value, "api key")
                detail = message( ...
                    "KSSOLV:dialogs:MaterialsProjectAuthenticationFailed");
            elseif contains(value, "timeout") || contains(value, "timed out")
                detail = message( ...
                    "KSSOLV:dialogs:MaterialsProjectTimedOut");
            elseif any(contains(value, ["network", "connection", ...
                    "resolve", "ssl", "tls", "certificate"]))
                detail = message( ...
                    "KSSOLV:dialogs:MaterialsProjectNetworkFailed");
            else
                detail = sprintf(message( ...
                    "KSSOLV:dialogs:MaterialsProjectUnexpectedError"), ...
                    char(exception.message));
            end
        end
    end

    methods (Static)
        function records = fetchSummaries(apiKey, query, elements, ...
                mode, limit)
            import kssolv.analysis.matgenlab.ext.matproj.MPRester

            rester = MPRester(apiKey, false);
            cleanup = onCleanup(@() rester.close());
            if mode == "formula"
                if startsWith(lower(query), "mp-")
                    arguments = {"material_ids", query};
                else
                    arguments = {"formula", query};
                end
            else
                arguments = {"elements", elements};
                if mode == "only"
                    arguments = [arguments, ...
                        {"nelements", numel(elements)}];
                end
            end
            fields = ["material_id", "formula_pretty", "symmetry", ...
                "band_gap", "energy_above_hull", "is_stable", "nsites"];
            arguments = [arguments, {"_fields", fields, ...
                "_limit", limit, "_sort_fields", "energy_above_hull", ...
                "id_format", "legacy"}];
            docs = rester.summary_search(arguments{:});
            records = ...
                kssolv.ui.components.dialog.MaterialsProjectDialog. ...
                summaryRecords(docs);
            clear cleanup
        end

        function value = fetchStructure(apiKey, materialId)
            import kssolv.analysis.matgenlab.ext.matproj.MPRester

            rester = MPRester(apiKey, false);
            cleanup = onCleanup(@() rester.close());
            structure = rester.get_structure_by_material_id(materialId);
            value = structure.as_dict();
            clear cleanup
        end
    end

    methods (Static, Access = private)
        function validateSearch(apiKey, query, elements, mode)
            import kssolv.ui.util.Localizer.message

            if strlength(apiKey) ~= 32
                error("KSSOLV:MaterialsProjectDialog:APIKey", ...
                    message("KSSOLV:dialogs:MaterialsProjectAPIKeyRequired"));
            end
            if mode == "formula" && query == ""
                error("KSSOLV:MaterialsProjectDialog:Query", ...
                    message("KSSOLV:dialogs:MaterialsProjectQueryRequired"));
            end
            if mode ~= "formula" && isempty(elements)
                error("KSSOLV:MaterialsProjectDialog:Elements", ...
                    message( ...
                    "KSSOLV:dialogs:MaterialsProjectElementsRequired"));
            end
        end

        function records = summaryRecords(docs)
            template = struct( ...
                "MaterialId", "", ...
                "Formula", "", ...
                "SpaceGroup", "", ...
                "BandGap", NaN, ...
                "EnergyAboveHull", NaN, ...
                "Stable", false, ...
                "Sites", NaN);
            records = repmat(template, numel(docs), 1);
            for index = 1:numel(docs)
                doc = docs{index};
                records(index).MaterialId = string( ...
                    fieldOr(doc, "material_id", ""));
                records(index).Formula = string( ...
                    fieldOr(doc, "formula_pretty", ""));
                symmetry = fieldOr(doc, "symmetry", struct());
                if isstruct(symmetry)
                    symbol = string(fieldOr(symmetry, "symbol", ""));
                    number = fieldOr(symmetry, "number", []);
                    if ~isempty(number)
                        records(index).SpaceGroup = ...
                            symbol + " (" + string(number) + ")";
                    else
                        records(index).SpaceGroup = symbol;
                    end
                end
                records(index).BandGap = double( ...
                    fieldOr(doc, "band_gap", NaN));
                records(index).EnergyAboveHull = double( ...
                    fieldOr(doc, "energy_above_hull", NaN));
                records(index).Stable = logical( ...
                    fieldOr(doc, "is_stable", false));
                records(index).Sites = double( ...
                    fieldOr(doc, "nsites", NaN));
            end
        end

        function data = resultsTableData(records)
            import kssolv.ui.util.Localizer.message

            data = cell(numel(records), 7);
            for index = 1:numel(records)
                data{index, 1} = char(records(index).MaterialId);
                data{index, 2} = char(records(index).Formula);
                data{index, 3} = char(records(index).SpaceGroup);
                data{index, 4} = displayNumber(records(index).BandGap);
                data{index, 5} = ...
                    displayNumber(records(index).EnergyAboveHull);
                if records(index).Stable
                    data{index, 6} = message( ...
                        "KSSOLV:dialogs:MaterialsProjectYes");
                else
                    data{index, 6} = message( ...
                        "KSSOLV:dialogs:MaterialsProjectNo");
                end
                data{index, 7} = displayNumber(records(index).Sites);
            end
        end

        function value = maskedAPIKey()
            value = "********";
        end

        function map = periodicTableMap()
            map = strings(9, 18);
            map(1, [1, 18]) = ["H", "He"];
            map(2, [1, 2, 13:18]) = ...
                ["Li", "Be", "B", "C", "N", "O", "F", "Ne"];
            map(3, [1, 2, 13:18]) = ...
                ["Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar"];
            map(4, :) = ["K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", ...
                "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", ...
                "Se", "Br", "Kr"];
            map(5, :) = ["Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", ...
                "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", ...
                "Te", "I", "Xe"];
            map(6, [1, 2, 4:18]) = ["Cs", "Ba", "Hf", "Ta", "W", ...
                "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", ...
                "Bi", "Po", "At", "Rn"];
            map(7, [1, 2, 4:18]) = ["Fr", "Ra", "Rf", "Db", "Sg", ...
                "Bh", "Hs", "Mt", "Ds", "Rg", "Cn", "Nh", "Fl", ...
                "Mc", "Lv", "Ts", "Og"];
            map(8, 3:17) = ["La", "Ce", "Pr", "Nd", "Pm", "Sm", ...
                "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"];
            map(9, 3:17) = ["Ac", "Th", "Pa", "U", "Np", "Pu", ...
                "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr"];
        end

        function color = elementColor(symbol)
            alkali = ["Li", "Na", "K", "Rb", "Cs", "Fr"];
            alkaline = ["Be", "Mg", "Ca", "Sr", "Ba", "Ra"];
            noble = ["He", "Ne", "Ar", "Kr", "Xe", "Rn", "Og"];
            halogen = ["F", "Cl", "Br", "I", "At", "Ts"];
            lanthanide = ["La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", ...
                "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"];
            actinide = ["Ac", "Th", "Pa", "U", "Np", "Pu", "Am", ...
                "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr"];
            if any(symbol == alkali)
                color = [0.78, 0.88, 0.28];
            elseif any(symbol == alkaline)
                color = [0.45, 0.82, 0.63];
            elseif any(symbol == noble)
                color = [0.63, 0.62, 0.86];
            elseif any(symbol == halogen)
                color = [0.82, 0.68, 0.36];
            elseif any(symbol == lanthanide)
                color = [1.00, 0.88, 0.25];
            elseif any(symbol == actinide)
                color = [1.00, 0.68, 0.22];
            elseif any(symbol == ["B", "Si", "Ge", "As", "Sb", "Te"])
                color = [0.90, 0.42, 0.42];
            elseif any(symbol == ["Al", "Ga", "In", "Sn", "Tl", "Pb", ...
                    "Bi", "Nh", "Fl", "Mc", "Lv"])
                color = [0.70, 0.70, 0.70];
            elseif any(symbol == ["H", "C", "N", "O", "P", "S", ...
                    "Se", "Po"])
                color = [0.62, 0.69, 0.71];
            else
                color = [0.48, 0.76, 0.93];
            end
        end

        function cancelFuture(future)
            if isempty(future)
                return
            end
            try
                if isvalid(future) && ~strcmp(future.State, "finished")
                    cancel(future);
                end
            catch
                % Future may already have been released by backgroundPool.
            end
        end
    end
end

function value = fieldOr(input, name, defaultValue)
if isstruct(input) && isfield(input, name)
    value = input.(name);
else
    value = defaultValue;
end
end

function value = displayNumber(input)
if isempty(input) || ~isfinite(input)
    value = "—";
elseif abs(input - round(input)) < eps(max(1, abs(input)))
    value = sprintf("%d", round(input));
else
    value = sprintf("%.4g", input);
end
end
