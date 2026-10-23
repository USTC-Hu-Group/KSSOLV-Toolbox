classdef StartupSplash
    %STARTUPSPLASH Deployment-only handshake with the native HTML startup host.
    methods (Static)
        function requested = isRequested()
            requested = isdeployed && ...
                strlength(getenv('KSSOLV_STARTUP_SIGNAL')) > 0 && ...
                strlength(getenv('KSSOLV_STARTUP_NONCE')) > 0;
        end

        function handled = tryShow(app)
            % Return immediately in source mode or without a native host.
            handled = kssolv.ui.util.StartupSplash.isRequested();
            if ~handled || app.HostInBrowser
                handled = false;
                return
            end
            completion = struct('file', string(getenv('KSSOLV_STARTUP_COMPLETION')), ...
                'nonce', string(getenv('KSSOLV_STARTUP_NONCE')));
            bounds = [100 100 1200 800];
            container = app.getAppContainer();
            window = kssolv.ui.util.StartupSplash.prepareHiddenWindow(app);
            % Hand off the native shell immediately. Project HTML and the other
            % panels continue loading in the visible, busy Toolbox window.
            kssolv.ui.util.StartupSplash.publish('shell-ready');
            acknowledgement = string(getenv('KSSOLV_STARTUP_SIGNAL')) + ".reveal";
            started = tic;
            while true
                if isfile(acknowledgement)
                    data = jsondecode(fileread(acknowledgement));
                    assert(isfield(data, 'nonce') && ...
                        string(data.nonce) == string(getenv('KSSOLV_STARTUP_NONCE')), ...
                        'KSSOLV:Startup:InvalidHost', 'Invalid startup host acknowledgement.');
                    break
                end
                if toc(started) > 30
                    error('KSSOLV:Startup:HostTimeout', ...
                        'The startup host stopped responding before the window was shown.');
                end
                pause(0.05);
            end
            container.WindowBounds = bounds;
            window.show();
            started = tic;
            while ~window.isVisible()
                if toc(started) > 10
                    error('KSSOLV:Startup:RevealTimeout', ...
                        'The application window did not become visible.');
                end
                pause(0.05);
            end
            drawnow;
            kssolv.ui.util.StartupSplash.publish('visible');
            % The host has fulfilled its job; remaining views load in Toolbox.
            setenv('KSSOLV_STARTUP_SIGNAL', '');
            setenv('KSSOLV_STARTUP_NONCE', '');
            app.waitUntilReady();
            container.Busy = false;
            kssolv.ui.util.StartupSplash.markLoaded(completion);
        end

        function fail(exception)
            if kssolv.ui.util.StartupSplash.isRequested()
                kssolv.ui.util.StartupSplash.publish('failed', exception.message);
            end
        end

        function window = prepareHiddenWindow(app)
            % AppContainer.Visible initializes the CEF view and calls show.
            % Keep that first native window outside every monitor, then hide
            % it before processing any render callbacks. The client remains
            % active so prewarm can wait for real Figure and HTML readiness.
            container = app.getAppContainer();
            oldUnits = get(groot, 'Units');
            unitsCleanup = onCleanup(@() set(groot, 'Units', oldUnits));
            set(groot, 'Units', 'pixels');
            monitors = get(groot, 'MonitorPositions');
            container.WindowBounds = [max(monitors(:,1) + monitors(:,3)) + 200, ...
                100, 1200, 800];
            clear unitsCleanup
            container.HostInBrowser = false;
            container.Busy = true;
            container.Visible = true;
            warningState = warning('off', 'MATLAB:structOnObject');
            warningCleanup = onCleanup(@() warning(warningState));
            internals = struct(container);
            window = internals.Window;
            clear warningCleanup
            window.hide();
        end
    end

    methods (Static, Access = private)
        function markLoaded(completion)
            % A diagnostic separate from the early-window handoff. Keep one
            % atomic, nonce-qualified result per user/build, without accumulating
            % per-launch signal files or keeping the startup host alive.
            if ~isdeployed || strlength(completion.file) == 0
                return
            end
            data = struct('protocol', 1, 'status', 'loaded', ...
                'nonce', completion.nonce, 'completedUtc', ...
                string(datetime('now', TimeZone='UTC', ...
                Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")));
            temporary = string(tempname(fileparts(completion.file)));
            writelines(jsonencode(data), temporary, Encoding="UTF-8");
            movefile(temporary, completion.file, 'f');
        end

        function publish(status, detail)
            arguments
                status
                detail = ''
            end
            path = string(getenv('KSSOLV_STARTUP_SIGNAL'));
            data = struct('protocol', 1, 'status', status, ...
                'nonce', getenv('KSSOLV_STARTUP_NONCE'), 'error', detail);
            temporaryFile = path + ".tmp";
            writelines(jsonencode(data), temporaryFile, Encoding="UTF-8");
            [moved, message] = movefile(temporaryFile, path, 'f');
            if ~moved
                error('KSSOLV:Startup:SignalFailed', '%s', message);
            end
        end
    end
end
