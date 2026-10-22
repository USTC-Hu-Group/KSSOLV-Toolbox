classdef OnlineWorkspace
    %ONLINEWORKSPACE Paths confined by the JVM-free Runtime supervisor.
    methods (Static)
        function value = available()
            value = isKSSOLVOnline() && strcmp(getenv('KSSOLV_WORKSPACE_ENABLED'), 'true');
        end

        function reply = request(action, path, writable)
            if nargin < 3, writable = false; end
            if ~kssolv.ui.browser.OnlineWorkspace.available()
                error('KSSOLV:Online:WorkspaceUnavailable', 'Persistent Files requires the Online container.');
            end
            options = weboptions('Timeout', 10, 'MediaType', 'application/json', ...
                'ContentType', 'json', 'HeaderFields', ...
                {'Authorization', ['Bearer ' getenv('KSSOLV_HTTP_WORKER_TOKEN')]});
            reply = webwrite(string(getenv('KSSOLV_HTTP_WORKER_URL')) + '/workspace', ...
                struct('action', char(action), 'path', char(path), 'writable', logical(writable)), options);
        end

        function path = resolve(relative, writable)
            if nargin < 2, writable = false; end
            reply = kssolv.ui.browser.OnlineWorkspace.request('resolve', relative, writable);
            path = string(reply.path);
        end

        function relative = relativePath(path)
            relative = "";
            if strlength(string(path)) == 0, return, end
            root = kssolv.ui.browser.OnlineWorkspace.resolve('');
            path = kssolv.util.Platform.canonicalPath(path);
            prefix = root + filesep;
            if startsWith(path, prefix)
                candidate = extractAfter(path, strlength(prefix));
                kssolv.ui.browser.OnlineWorkspace.resolve(candidate, true);
                relative = replace(candidate, filesep, '/');
            end
        end
    end
end
