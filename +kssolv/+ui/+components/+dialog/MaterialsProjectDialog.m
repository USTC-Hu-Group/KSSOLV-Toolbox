classdef MaterialsProjectDialog < controllib.ui.internal.dialog.AbstractDialog
    %MATERIALSPROJECTDIALOG Search and import Materials Project crystals.

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    properties (SetAccess = private)
        widgets = struct()
    end

    properties (Access = private)
        width = 1020
        height = 710
        importFcn = []
        apiKey (1, 1) string = ""
        results = struct([])
        selectedResultIndex (1, 1) double = 0
        requestFuture = []
        completionFuture = []
        requestToken (1, 1) uint64 = uint64(0)
        currentPage (1, 1) double = 1
        pageSize (1, 1) double = 10
        totalResults (1, 1) double = 0
        searchCriteria = struct()
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
                "RowHeight", {28, 26, 360, "1x", 26}, ...
                "ColumnWidth", {"1x"}, ...
                "RowSpacing", 2, ...
                "Padding", [10, 8, 10, 8]);
            this.widgets.MainLayout = layout;

            this.buildSearchHeader(layout);
            this.buildSearchMode(layout);
            this.buildPeriodicTable(layout);
            this.buildResultsTable(layout);
            this.buildFooter(layout);
            this.updateSearchInputForMode("only");
            this.updateSelectedElements();
        end
    end

    methods (Access = private)
        function buildSearchHeader(this, parent)
            import kssolv.ui.util.Localizer.message

            layout = uigridlayout(parent, [1, 3], ...
                "RowHeight", {28}, ...
                "ColumnWidth", {105, "1x", 88}, ...
                "ColumnSpacing", 6, "Padding", 0);
            layout.Layout.Row = 1;

            queryLabel = uilabel(layout, "Text", ...
                message("KSSOLV:dialogs:MaterialsProjectQuery"));
            queryLabel.Layout.Row = 1;
            queryLabel.Layout.Column = 1;
            searchCallback = @(~, ~) this.startSearch();
            queryField = uieditfield(layout, "text", ...
                "Placeholder", message( ...
                "KSSOLV:dialogs:MaterialsProjectFormulaPlaceholder"), ...
                "ValueChangedFcn", searchCallback);
            queryField.Layout.Row = 1;
            queryField.Layout.Column = 2;
            searchButton = uibutton(layout, ...
                "Text", message("KSSOLV:dialogs:MaterialsProjectSearch"), ...
                "ButtonPushedFcn", searchCallback, ...
                "Interruptible", "off");
            searchButton.Layout.Row = 1;
            searchButton.Layout.Column = 3;

            this.widgets.QueryLabel = queryLabel;
            this.widgets.QueryField = queryField;
            this.widgets.SearchButton = searchButton;
        end

        function buildSearchMode(this, parent)
            import kssolv.ui.util.Localizer.message

            group = uibuttongroup(parent, ...
                "BorderType", "none", ...
                "SelectionChangedFcn", @(~, event) ...
                this.searchModeChanged(event));
            group.Layout.Row = 2;
            only = uiradiobutton(group, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectOnlyElements"), ...
                "Tag", "only", "Position", [8, 1, 155, 24]);
            atLeast = uiradiobutton(group, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectAtLeastElements"), ...
                "Tag", "at-least", "Position", [170, 1, 170, 24]);
            formula = uiradiobutton(group, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectFormulaOrId"), ...
                "Tag", "formula", "Position", [350, 1, 155, 24]);
            group.SelectedObject = only;

            this.widgets.SearchModeGroup = group;
            this.widgets.OnlyElementsButton = only;
            this.widgets.AtLeastElementsButton = atLeast;
            this.widgets.FormulaButton = formula;
        end

        function buildPeriodicTable(this, parent)
            panel = uipanel(parent, "BorderType", "line");
            panel.Layout.Row = 3;
            grid = uigridlayout(panel, [9, 20], ...
                "RowHeight", repmat({36}, 1, 9), ...
                "ColumnWidth", [{"1x"}, repmat({36}, 1, 18), {"1x"}], ...
                "RowSpacing", 3, "ColumnSpacing", 3, ...
                "Padding", [6, 6, 6, 6]);
            this.widgets.PeriodicTableGrid = grid;

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
                        "FontColor", [74, 74, 74] ./ 255, ...
                        "BackgroundColor", this.elementColor(symbol), ...
                        "Enable", this.elementEnabledState(symbol), ...
                        "UserData", symbol, ...
                        "ValueChangedFcn", @(~, ~) ...
                        this.updateSelectedElements());
                    button.Layout.Row = row;
                    button.Layout.Column = column + 1;
                    elementButtons.(char(symbol)) = button;
                end
            end
            this.widgets.ElementButtons = elementButtons;
        end

        function buildResultsTable(this, parent)
            import kssolv.ui.util.Localizer.message

            resultsTable = uitable(parent, ...
                "Data", cell(0, 11), ...
                "ColumnName", { ...
                message("KSSOLV:dialogs:MaterialsProjectIdColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectFormulaColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectCrystalSystemColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectSpaceGroupColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectSitesColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectVolumeColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectDensityColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectBandGapColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectFormationEnergyColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectHullColumn"), ...
                message("KSSOLV:dialogs:MaterialsProjectStableColumn")}, ...
                "ColumnWidth", {125, 85, 105, 140, 70, 95, ...
                110, 100, 145, 135, 60}, ...
                "ColumnFormat", {'char', 'char', 'char', 'char', ...
                'numeric', 'numeric', 'numeric', 'numeric', 'numeric', ...
                'numeric', 'char'}, ...
                "ColumnSortable", true(1, 11), ...
                "RowName", {}, ...
                "CellSelectionCallback", @(~, event) ...
                this.resultSelected(event));
            resultsTable.Layout.Row = 4;
            this.widgets.ResultsTable = resultsTable;
        end

        function buildFooter(this, parent)
            import kssolv.ui.util.Localizer.message

            layout = uigridlayout(parent, [1, 7], ...
                "ColumnWidth", {"1x", "fit", 82, "fit", "fit", ...
                "fit", "fit"}, ...
                "Padding", 0);
            layout.Layout.Row = 5;
            this.widgets.FooterLayout = layout;
            status = uilabel(layout, "Text", ...
                message("KSSOLV:dialogs:MaterialsProjectReady"), ...
                "FontColor", [0.35, 0.35, 0.35]);
            status.Layout.Column = 1;
            experimentalLegend = uilabel(layout, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectExperimentalLegend"), ...
                "FontColor", [0.25, 0.25, 0.25], ...
                "HorizontalAlignment", "right");
            experimentalLegend.Layout.Column = 2;
            pageSizeDropDown = uidropdown(layout, ...
                "Items", ["10/page", "15/page", "20/page", "30/page"], ...
                "ItemsData", [10, 15, 20, 30], ...
                "Value", this.pageSize, ...
                "Tooltip", message( ...
                "KSSOLV:dialogs:MaterialsProjectPageSizeTooltip"), ...
                "ValueChangedFcn", @(source, ~) ...
                this.pageSizeChanged(source));
            pageSizeDropDown.Layout.Column = 3;
            pagination = uigridlayout(layout, [1, 5], ...
                "ColumnWidth", {28, 28, 82, 28, 28}, ...
                "ColumnSpacing", 3, "Padding", 0);
            pagination.Layout.Column = 4;
            firstPage = uibutton(pagination, "Text", "|<", ...
                "Tooltip", message( ...
                "KSSOLV:dialogs:MaterialsProjectFirstPage"), ...
                "ButtonPushedFcn", @(~, ~) this.goToPage(1));
            previousPage = uibutton(pagination, "Text", "<", ...
                "Tooltip", message( ...
                "KSSOLV:dialogs:MaterialsProjectPreviousPage"), ...
                "ButtonPushedFcn", @(~, ~) ...
                this.goToPage(this.currentPage - 1));
            pageLabel = uilabel(pagination, ...
                "HorizontalAlignment", "center");
            nextPage = uibutton(pagination, "Text", ">", ...
                "Tooltip", message( ...
                "KSSOLV:dialogs:MaterialsProjectNextPage"), ...
                "ButtonPushedFcn", @(~, ~) ...
                this.goToPage(this.currentPage + 1));
            lastPage = uibutton(pagination, "Text", ">|", ...
                "Tooltip", message( ...
                "KSSOLV:dialogs:MaterialsProjectLastPage"), ...
                "ButtonPushedFcn", @(~, ~) this.goToPage( ...
                max(1, ceil(this.totalResults / this.pageSize))));

            clearButton = uibutton(layout, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectClearElements"), ...
                "ButtonPushedFcn", @(~, ~) this.clearElements());
            clearButton.Layout.Column = 5;
            importButton = uibutton(layout, ...
                "Text", message( ...
                "KSSOLV:dialogs:MaterialsProjectImportSelected"), ...
                "Enable", "off", ...
                "ButtonPushedFcn", @(~, ~) this.startImport(), ...
                "Interruptible", "off");
            importButton.Layout.Column = 6;
            closeButton = uibutton(layout, ...
                "Text", message("KSSOLV:dialogs:DialogCloseButton"), ...
                "ButtonPushedFcn", @(~, ~) close(this));
            closeButton.Layout.Column = 7;

            this.widgets.StatusLabel = status;
            this.widgets.ExperimentalLegend = experimentalLegend;
            this.widgets.PageSizeDropDown = pageSizeDropDown;
            this.widgets.FirstPageButton = firstPage;
            this.widgets.PreviousPageButton = previousPage;
            this.widgets.PageLabel = pageLabel;
            this.widgets.NextPageButton = nextPage;
            this.widgets.LastPageButton = lastPage;
            this.widgets.ClearElementsButton = clearButton;
            this.widgets.ImportButton = importButton;
            this.updatePaginationControls();
        end

        function searchModeChanged(this, event)
            mode = string(event.NewValue.Tag);
            formulaMode = mode == "formula";
            names = fieldnames(this.widgets.ElementButtons);
            for index = 1:numel(names)
                if formulaMode
                    this.widgets.ElementButtons.(names{index}).Enable = "off";
                else
                    symbol = string(this.widgets.ElementButtons. ...
                        (names{index}).UserData);
                    this.widgets.ElementButtons.(names{index}).Enable = ...
                        this.elementEnabledState(symbol);
                end
            end
            this.updateSearchInputForMode(mode);
            this.updateSelectedElements();
        end

        function updateSearchInputForMode(this, mode)
            import kssolv.ui.util.Localizer.message

            if ~isfield(this.widgets, "QueryField")
                return
            end
            if mode == "formula"
                elements = this.selectedElements();
                if isempty(elements)
                    elementQuery = "";
                else
                    elementQuery = join(elements, "-");
                end
                if string(this.widgets.QueryField.Value) == elementQuery
                    this.widgets.QueryField.Value = "";
                end
                this.widgets.QueryLabel.Text = message( ...
                    "KSSOLV:dialogs:MaterialsProjectQuery");
                this.widgets.QueryField.Editable = "on";
                this.widgets.QueryField.Placeholder = message( ...
                    "KSSOLV:dialogs:MaterialsProjectFormulaPlaceholder");
                this.widgets.QueryField.Tooltip = message( ...
                    "KSSOLV:dialogs:MaterialsProjectFormulaTooltip");
            else
                this.widgets.QueryLabel.Text = message( ...
                    "KSSOLV:dialogs:MaterialsProjectElementsQuery");
                this.widgets.QueryField.Editable = "off";
                this.widgets.QueryField.Placeholder = message( ...
                    "KSSOLV:dialogs:MaterialsProjectElementsPlaceholder");
                if mode == "only"
                    tooltipKey = ...
                        "KSSOLV:dialogs:MaterialsProjectOnlyElementsTooltip";
                else
                    tooltipKey = ...
                        "KSSOLV:dialogs:MaterialsProjectAtLeastElementsTooltip";
                end
                this.widgets.QueryField.Tooltip = message(tooltipKey);
            end
        end

        function updateSelectedElements(this)
            if ~isfield(this.widgets, "ElementButtons")
                return
            end
            elements = this.selectedElements();
            if isfield(this.widgets, "QueryField") && ...
                    string(this.widgets.SearchModeGroup. ...
                    SelectedObject.Tag) ~= "formula"
                if isempty(elements)
                    query = "";
                else
                    query = join(elements, "-");
                end
                this.widgets.QueryField.Value = char(query);
            end
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

            this.apiKey = kssolv.analysis.matgenlab.ext.matproj. ...
                MPRester.default_api_key();
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

            this.currentPage = 1;
            this.totalResults = 0;
            this.searchCriteria = struct( ...
                "APIKey", keyValue, "Query", query, ...
                "Elements", elements, "Mode", mode);
            this.startSearchRequest();
        end

        function goToPage(this, page)
            if isempty(fieldnames(this.searchCriteria))
                return
            end
            pageCount = max(1, ceil(this.totalResults / this.pageSize));
            page = min(max(1, round(page)), pageCount);
            if page == this.currentPage
                return
            end
            this.currentPage = page;
            this.startSearchRequest();
        end

        function pageSizeChanged(this, dropDown)
            newPageSize = double(dropDown.Value);
            if newPageSize == this.pageSize
                return
            end
            this.pageSize = newPageSize;
            this.currentPage = 1;
            this.updatePaginationControls();
            if ~isempty(fieldnames(this.searchCriteria))
                this.startSearchRequest();
            end
        end

        function startSearchRequest(this)
            import kssolv.ui.util.Localizer.message

            criteria = this.searchCriteria;
            offset = (this.currentPage - 1) * this.pageSize;

            this.stopRequest();
            this.requestToken = this.requestToken + 1;
            token = this.requestToken;
            this.selectedResultIndex = 0;
            this.results = struct([]);
            this.widgets.ResultsTable.Data = cell(0, 11);
            this.widgets.ImportButton.Enable = "off";
            this.setBusy(true, ...
                message("KSSOLV:dialogs:MaterialsProjectSearching"));
            drawnow;

            future = [];
            try
                future = parfeval(backgroundPool, ...
                    @kssolv.ui.components.dialog.MaterialsProjectDialog.fetchSummaries, ...
                    2, criteria.APIKey, criteria.Query, criteria.Elements, ...
                    criteria.Mode, this.pageSize, offset);
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
            this.totalResults = double(future.OutputArguments{2});
            this.widgets.ResultsTable.Data = ...
                this.resultsTableData(this.results);
            if isempty(this.results)
                status = message( ...
                    "KSSOLV:dialogs:MaterialsProjectNoResults");
            else
                first = (this.currentPage - 1) * this.pageSize + 1;
                last = first + numel(this.results) - 1;
                status = sprintf(message( ...
                    "KSSOLV:dialogs:MaterialsProjectResultsFoundPaged"), ...
                    this.totalResults, first, last);
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
            if row < 1 || row > size(this.widgets.ResultsTable.Data, 1)
                return
            end
            materialId = erase( ...
                string(this.widgets.ResultsTable.Data{row, 1}), "★ ");
            resultIds = string({this.results.MaterialId});
            index = find(resultIds == materialId, 1);
            if isempty(index)
                return
            end
            this.selectedResultIndex = index;
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
            this.widgets.PageSizeDropDown.Enable = state;
            if busy || this.selectedResultIndex == 0
                this.widgets.ImportButton.Enable = "off";
            else
                this.widgets.ImportButton.Enable = "on";
            end
            this.widgets.StatusLabel.Text = status;
            if busy
                this.setPaginationButtons("off");
            else
                this.updatePaginationControls();
            end
        end

        function updatePaginationControls(this)
            import kssolv.ui.util.Localizer.message

            if ~isfield(this.widgets, "PageLabel")
                return
            end
            pageCount = max(1, ceil(this.totalResults / this.pageSize));
            this.widgets.PageLabel.Text = sprintf(message( ...
                "KSSOLV:dialogs:MaterialsProjectPageStatus"), ...
                this.currentPage, pageCount);
            if this.currentPage > 1
                previousState = "on";
            else
                previousState = "off";
            end
            if this.currentPage < pageCount
                nextState = "on";
            else
                nextState = "off";
            end
            this.widgets.FirstPageButton.Enable = previousState;
            this.widgets.PreviousPageButton.Enable = previousState;
            this.widgets.NextPageButton.Enable = nextState;
            this.widgets.LastPageButton.Enable = nextState;
        end

        function setPaginationButtons(this, state)
            this.widgets.FirstPageButton.Enable = state;
            this.widgets.PreviousPageButton.Enable = state;
            this.widgets.NextPageButton.Enable = state;
            this.widgets.LastPageButton.Enable = state;
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
            if contains(value, "temporarily blocked") || ...
                    contains(value, "ip address or asn") || ...
                    contains(value, "inefficient or abusive traffic") || ...
                    contains(value, '"version":"blocked"')
                detail = message( ...
                    "KSSOLV:dialogs:MaterialsProjectAccessBlocked");
            elseif contains(value, "401") || contains(value, "403") || ...
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
        function [records, total] = fetchSummaries(apiKey, query, elements, ...
                mode, limit, offset)
            import kssolv.analysis.matgenlab.ext.matproj.MPRester

            if nargin < 6
                offset = 0;
            end

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
                "nsites", "volume", "density", "band_gap", ...
                "formation_energy_per_atom", "energy_above_hull", ...
                "is_stable", "theoretical"];
            arguments = [arguments, {"_fields", fields, ...
                "_limit", limit, "_skip", offset, ...
                "_sort_fields", "material_id", ...
                "id_format", "legacy"}];
            [docs, metadata] = rester.summary_search(arguments{:});
            records = ...
                kssolv.ui.components.dialog.MaterialsProjectDialog. ...
                summaryRecords(docs);
            total = double(fieldOr(metadata, "total_doc", ...
                offset + numel(records)));
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
                "ExperimentallyObserved", false, ...
                "CrystalSystem", "", ...
                "SpaceGroup", "", ...
                "Sites", NaN, ...
                "Volume", NaN, ...
                "Density", NaN, ...
                "BandGap", NaN, ...
                "FormationEnergy", NaN, ...
                "EnergyAboveHull", NaN, ...
                "Stable", false);
            records = repmat(template, numel(docs), 1);
            for index = 1:numel(docs)
                doc = docs{index};
                records(index).MaterialId = string( ...
                    fieldOr(doc, "material_id", ""));
                records(index).Formula = string( ...
                    fieldOr(doc, "formula_pretty", ""));
                theoretical = fieldOr(doc, "theoretical", true);
                if isempty(theoretical)
                    theoretical = true;
                end
                records(index).ExperimentallyObserved = ...
                    ~logical(theoretical);
                symmetry = fieldOr(doc, "symmetry", struct());
                if isstruct(symmetry)
                    records(index).CrystalSystem = string( ...
                        fieldOr(symmetry, "crystal_system", ""));
                    symbol = string(fieldOr(symmetry, "symbol", ""));
                    number = fieldOr(symmetry, "number", []);
                    if ~isempty(number)
                        records(index).SpaceGroup = ...
                            symbol + " (" + string(number) + ")";
                    else
                        records(index).SpaceGroup = symbol;
                    end
                end
                records(index).Sites = double( ...
                    fieldOr(doc, "nsites", NaN));
                records(index).Volume = double( ...
                    fieldOr(doc, "volume", NaN));
                records(index).Density = double( ...
                    fieldOr(doc, "density", NaN));
                records(index).BandGap = double( ...
                    fieldOr(doc, "band_gap", NaN));
                records(index).FormationEnergy = double( ...
                    fieldOr(doc, "formation_energy_per_atom", NaN));
                records(index).EnergyAboveHull = double( ...
                    fieldOr(doc, "energy_above_hull", NaN));
                records(index).Stable = logical( ...
                    fieldOr(doc, "is_stable", false));
            end
        end

        function data = resultsTableData(records)
            import kssolv.ui.util.Localizer.message

            data = cell(numel(records), 11);
            for index = 1:numel(records)
                materialId = records(index).MaterialId;
                if records(index).ExperimentallyObserved
                    materialId = "★ " + materialId;
                end
                data{index, 1} = char(materialId);
                data{index, 2} = char(records(index).Formula);
                data{index, 3} = char(records(index).CrystalSystem);
                data{index, 4} = char(records(index).SpaceGroup);
                data{index, 5} = records(index).Sites;
                data{index, 6} = records(index).Volume;
                data{index, 7} = records(index).Density;
                data{index, 8} = records(index).BandGap;
                data{index, 9} = records(index).FormationEnergy;
                data{index, 10} = records(index).EnergyAboveHull;
                if records(index).Stable
                    data{index, 11} = char(message( ...
                        "KSSOLV:dialogs:MaterialsProjectYes"));
                else
                    data{index, 11} = char(message( ...
                        "KSSOLV:dialogs:MaterialsProjectNo"));
                end
            end
            stringCells = cellfun(@isstring, data);
            data(stringCells) = cellfun(@char, data(stringCells), ...
                "UniformOutput", false);
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
            noble = ["He", "Ne", "Ar", "Kr", "Xe", "Rn"];
            halogen = ["F", "Cl", "Br", "I", "At"];
            lanthanide = ["La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", ...
                "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"];
            actinide = ["Ac", "Th", "Pa", "U", "Np", "Pu", "Am", ...
                "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr"];
            if any(symbol == alkali)
                color = [186, 208, 70] ./ 255;
            elseif any(symbol == alkaline)
                color = [112, 202, 159] ./ 255;
            elseif any(symbol == noble)
                color = [145, 145, 205] ./ 255;
            elseif any(symbol == halogen)
                color = [194, 161, 88] ./ 255;
            elseif any(symbol == lanthanide)
                color = [255, 235, 17] ./ 255;
            elseif any(symbol == actinide)
                color = [255, 188, 30] ./ 255;
            elseif any(symbol == ["B", "Si", "Ge", "As", "Sb", "Te", ...
                    "Bi", "Po"])
                color = [222, 104, 104] ./ 255;
            elseif any(symbol == ["Al", "Zn", "Ga", "Cd", "In", "Sn", ...
                    "Hg", "Tl", "Pb"])
                color = [178, 178, 178] ./ 255;
            elseif any(symbol == ["H", "C", "N", "O", "P", "S", ...
                    "Se", "Po"])
                color = [142, 159, 166] ./ 255;
            elseif any(symbol == ["Nh", "Fl", "Mc", "Lv", "Ts", "Og"])
                color = [239, 239, 239] ./ 255;
            else
                color = [136, 203, 254] ./ 255;
            end
        end

        function state = elementEnabledState(symbol)
            disabled = ["Po", "At", "Rn", "Fr", "Ra", ...
                "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr", ...
                "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds", "Rg", "Cn", ...
                "Nh", "Fl", "Mc", "Lv", "Ts", "Og"];
            if any(symbol == disabled)
                state = "off";
            else
                state = "on";
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
