classdef UpdateDialog < controllib.ui.internal.dialog.AbstractDialog
    %UPDATEDIALOG 从 GitHub Release 检查 KSSOLV Toolbox 更新。

    % 开发者：杨柳
    % 版权 2026 合肥瀚海量子科技有限公司

    properties (SetAccess = private)
        widgets = struct()
    end

    properties (Access = private)
        width = 560
        height = 330
        checkFuture = []
        completionFuture = []
        checkToken (1, 1) uint64 = uint64(0)
        latestReleaseURL (1, 1) string = ""
    end

    methods
        function this = UpdateDialog()
            import kssolv.ui.util.Localizer.message

            this.Title = message('KSSOLV:dialogs:UpdateDialogTitle');
            this.CloseMode = 'hide';

            fig = this.getWidget();
            fig.CloseRequestFcn = @(~, ~) close(this);
        end

        function show(this, varargin)
            this.stopCheck();
            show@controllib.ui.internal.dialog.AbstractDialog( ...
                this, varargin{:});
            this.startCheck();
        end

        function close(this)
            this.stopCheck();
            close@controllib.ui.internal.dialog.AbstractDialog(this);
        end
    end

    methods (Access = protected)
        function buildUI(this)
            import kssolv.ui.util.Localizer.message

            fig = this.getWidget();
            fig.Position(3:4) = [this.width this.height];

            layout = uigridlayout(fig, [4 1], ...
                'Scrollable', 'off', ...
                'RowHeight', {'fit', 'fit', '1x', 'fit'}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 12, ...
                'Padding', [18 18 18 14]);

            versionLayout = uigridlayout(layout, [2 2], ...
                'RowHeight', {'fit', 'fit'}, ...
                'ColumnWidth', {'fit', '1x'}, ...
                'RowSpacing', 6, ...
                'Padding', 0);
            versionLayout.Layout.Row = 1;
            currentVersionLabel = uilabel(versionLayout, ...
                'Text', message( ...
                'KSSOLV:dialogs:UpdateDialogCurrentVersionLabel'), ...
                'FontWeight', 'bold');
            currentVersionLabel.Layout.Row = 1;
            currentVersionLabel.Layout.Column = 1;
            currentVersion = uilabel(versionLayout, ...
                'Text', char(KSSOLV_Toolbox.Version));
            currentVersion.Layout.Row = 1;
            currentVersion.Layout.Column = 2;
            latestVersionLabel = uilabel(versionLayout, ...
                'Text', message( ...
                'KSSOLV:dialogs:UpdateDialogLatestVersionLabel'), ...
                'FontWeight', 'bold');
            latestVersionLabel.Layout.Row = 2;
            latestVersionLabel.Layout.Column = 1;
            latestVersion = uilabel(versionLayout, 'Text', '—');
            latestVersion.Layout.Row = 2;
            latestVersion.Layout.Column = 2;

            statusLayout = uigridlayout(layout, [1 2], ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {32, '1x'}, ...
                'Padding', 0);
            statusLayout.Layout.Row = 2;
            statusIcon = uiimage(statusLayout, ...
                'ScaleMethod', 'fit');
            statusIcon.Layout.Column = 1;
            statusHeadline = uilabel(statusLayout, ...
                'Text', '', ...
                'FontSize', 15, ...
                'FontWeight', 'bold');
            statusHeadline.Layout.Column = 2;

            statusDetail = uilabel(layout, ...
                'Text', '', ...
                'VerticalAlignment', 'top', ...
                'WordWrap', 'on');
            statusDetail.Layout.Row = 3;

            buttonLayout = uigridlayout(layout, [1 4], ...
                'RowHeight', {'fit'}, ...
                'ColumnWidth', {'fit', 'fit', '1x', 'fit'}, ...
                'Padding', 0);
            buttonLayout.Layout.Row = 4;
            retryButton = uibutton(buttonLayout, ...
                'Text', message('KSSOLV:dialogs:UpdateDialogRetryButton'), ...
                'ButtonPushedFcn', @(~, ~) this.startCheck());
            retryButton.Layout.Column = 1;
            releaseButton = uibutton(buttonLayout, ...
                'Text', message( ...
                'KSSOLV:dialogs:UpdateDialogViewReleaseButton'), ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~, ~) this.openLatestRelease());
            releaseButton.Layout.Column = 2;
            closeButton = uibutton(buttonLayout, ...
                'Text', message('KSSOLV:dialogs:DialogCloseButton'), ...
                'ButtonPushedFcn', @(~, ~) close(this));
            closeButton.Layout.Column = 4;

            this.widgets.CurrentVersion = currentVersion;
            this.widgets.LatestVersion = latestVersion;
            this.widgets.StatusIcon = statusIcon;
            this.widgets.StatusHeadline = statusHeadline;
            this.widgets.StatusDetail = statusDetail;
            this.widgets.RetryButton = retryButton;
            this.widgets.ReleaseButton = releaseButton;
            this.widgets.CloseButton = closeButton;
        end
    end

    methods (Access = private)
        function startCheck(this)
            import kssolv.ui.util.Localizer.message

            this.stopCheck();
            this.checkToken = this.checkToken + 1;
            token = this.checkToken;
            this.latestReleaseURL = "";
            this.widgets.LatestVersion.Text = '—';
            this.widgets.RetryButton.Enable = 'off';
            this.widgets.ReleaseButton.Enable = 'off';
            this.setStatus('checking', ...
                message('KSSOLV:dialogs:UpdateDialogChecking'), ...
                message('KSSOLV:dialogs:UpdateDialogCheckingDetail'));
            drawnow;

            future = [];
            try
                future = parfeval(backgroundPool, ...
                    @kssolv.ui.components.dialog.UpdateDialog.fetchLatestRelease, ...
                    1);
                this.checkFuture = future;
                this.completionFuture = afterEach(future, ...
                    @(completedFuture) this.checkFinished( ...
                    completedFuture, token), ...
                    0, PassFuture = true);
            catch exception
                this.cancelFuture(future);
                this.checkFuture = [];
                this.completionFuture = [];
                this.widgets.RetryButton.Enable = 'on';
                this.setStatus('failure', ...
                    message('KSSOLV:dialogs:UpdateDialogCheckFailed'), ...
                    this.localizedNetworkError(exception));
            end
        end

        function checkFinished(this, future, token)
            import kssolv.ui.util.Localizer.message

            if token ~= this.checkToken
                return
            end

            this.checkFuture = [];
            this.completionFuture = [];
            this.widgets.RetryButton.Enable = 'on';

            if ~isempty(future.Error)
                exception = future.Error;
                if iscell(exception)
                    exception = exception{1};
                end
                this.setStatus('failure', ...
                    message('KSSOLV:dialogs:UpdateDialogCheckFailed'), ...
                    this.localizedNetworkError(exception));
                return
            end

            try
                release = future.OutputArguments{1};
                if ~release.Exists
                    this.setStatus('neutral', ...
                        message('KSSOLV:dialogs:UpdateDialogNoRelease'), ...
                        message( ...
                        'KSSOLV:dialogs:UpdateDialogNoReleaseDetail'));
                    return
                end

                latestVersion = this.normalizedVersion(release.TagName);
                this.widgets.LatestVersion.Text = char(latestVersion);
                this.latestReleaseURL = string(release.URL);
                this.widgets.ReleaseButton.Enable = 'on';

                if this.isNewerVersion( ...
                        latestVersion, KSSOLV_Toolbox.Version)
                    this.setStatus('success', ...
                        message( ...
                        'KSSOLV:dialogs:UpdateDialogUpdateAvailable'), ...
                        sprintf(message( ...
                        'KSSOLV:dialogs:UpdateDialogUpdateAvailableDetail'), ...
                        char(latestVersion)));
                else
                    this.setStatus('success', ...
                        message( ...
                        'KSSOLV:dialogs:UpdateDialogUpToDate'), ...
                        message( ...
                        'KSSOLV:dialogs:UpdateDialogUpToDateDetail'));
                end
            catch exception
                this.widgets.ReleaseButton.Enable = 'off';
                this.setStatus('failure', ...
                    message('KSSOLV:dialogs:UpdateDialogCheckFailed'), ...
                    this.localizedNetworkError(exception));
            end
        end

        function stopCheck(this)
            requestFuture = this.checkFuture;
            completion = this.completionFuture;
            this.checkToken = this.checkToken + 1;
            this.checkFuture = [];
            this.completionFuture = [];
            this.cancelFuture(completion);
            this.cancelFuture(requestFuture);
        end

        function openLatestRelease(this)
            if strlength(this.latestReleaseURL) > 0
                web(char(this.latestReleaseURL));
            end
        end

        function setStatus(this, state, headline, detail)
            switch state
                case 'checking'
                    iconName = 'refresh.svg';
                case 'success'
                    iconName = 'greenCheck.svg';
                case 'failure'
                    iconName = 'warning.svg';
                otherwise
                    iconName = 'orangeQuestionMark.svg';
            end
            this.widgets.StatusIcon.ImageSource = ...
                kssolv.ui.util.GetIcon(iconName);
            this.widgets.StatusHeadline.Text = headline;
            this.widgets.StatusDetail.Text = detail;
        end

        function detail = localizedNetworkError(~, exception)
            import kssolv.ui.util.Localizer.message

            identifiers = string(exception.identifier);
            causes = exception.cause;
            for i = 1:numel(causes)
                identifiers(end + 1) = string(causes{i}.identifier); %#ok<AGROW>
            end
            identifiers = lower(identifiers);

            if any(contains(identifiers, ["timeout", "timedout"]))
                detail = message( ...
                    'KSSOLV:dialogs:UpdateDialogTimedOut');
            elseif any(contains(identifiers, ...
                    ["connection", "resolvehost", "resolvehostname", ...
                    "network", "couldntresolve", "ssl", "tls", ...
                    "certificate"]))
                detail = message( ...
                    'KSSOLV:dialogs:UpdateDialogNetworkUnavailable');
            elseif startsWith(exception.identifier, ...
                    'KSSOLV:UpdateDialog:')
                detail = message( ...
                    'KSSOLV:dialogs:UpdateDialogInvalidResponse');
            else
                detail = message( ...
                    'KSSOLV:dialogs:UpdateDialogUnexpectedError');
            end
        end
    end

    methods (Static)
        function release = fetchLatestRelease()
            endpoint = [KSSOLV_Toolbox.CodeRepository, ...
                '/releases/latest'];
            endpoint = strrep(endpoint, ...
                'https://github.com/', 'https://api.github.com/repos/');
            options = weboptions( ...
                'Timeout', 10, ...
                'ContentType', 'json', ...
                'UserAgent', 'KSSOLV-Toolbox');

            release = struct( ...
                'Exists', false, ...
                'TagName', "", ...
                'Name', "", ...
                'URL', "", ...
                'PublishedAt', "");
            try
                response = webread(endpoint, options);
            catch exception
                identifiers = string(exception.identifier);
                causes = exception.cause;
                for i = 1:numel(causes)
                    identifiers(end + 1) = ...
                        string(causes{i}.identifier); %#ok<AGROW>
                end
                if any(contains(lower(identifiers), ...
                        ["http404", "statuscode:404"]))
                    return
                end
                rethrow(exception);
            end

            requiredFields = {'tag_name', 'html_url'};
            if ~isstruct(response) || ...
                    ~all(isfield(response, requiredFields))
                error('KSSOLV:UpdateDialog:InvalidResponse', ...
                    'GitHub returned an invalid release response.');
            end

            release.Exists = true;
            release.TagName = string(response.tag_name);
            release.URL = string(response.html_url);
            if isfield(response, 'name')
                release.Name = string(response.name);
            end
            if isfield(response, 'published_at')
                release.PublishedAt = string(response.published_at);
            end
        end

        function newer = isNewerVersion(candidate, installed)
            candidateParts = ...
                kssolv.ui.components.dialog.UpdateDialog.versionParts( ...
                candidate);
            installedParts = ...
                kssolv.ui.components.dialog.UpdateDialog.versionParts( ...
                installed);

            difference = candidateParts - installedParts;
            firstDifference = find(difference ~= 0, 1);
            newer = ~isempty(firstDifference) && ...
                difference(firstDifference) > 0;
        end
    end

    methods (Static, Access = private)
        function version = normalizedVersion(value)
            version = strip(string(value));
            version = regexprep(version, '^[vV]', '');
            kssolv.ui.components.dialog.UpdateDialog.versionParts(version);
        end

        function parts = versionParts(value)
            value = char(strip(string(value)));
            value = regexprep(value, '^[vV]', '');
            value = regexprep(value, '[-+].*$', '');
            if isempty(regexp(value, ...
                    '^\d+(?:\.\d+){0,3}$', 'once'))
                error('KSSOLV:UpdateDialog:InvalidVersion', ...
                    'The release version "%s" is invalid.', value);
            end

            parts = zeros(1, 4);
            components = strsplit(value, '.');
            parts(1:numel(components)) = ...
                cellfun(@str2double, components);
        end

        function cancelFuture(future)
            if isempty(future)
                return
            end
            try
                if isvalid(future) && ~strcmp(future.State, 'finished')
                    cancel(future);
                end
            catch
                % 对话框关闭过程中，Future 可能已被后台池回收。
            end
        end
    end
end
