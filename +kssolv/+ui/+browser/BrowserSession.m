classdef BrowserSession
    % File-based handoff between the Runtime event loop and its local proxy.
    methods (Static)
        function pending = hasPendingRequest(filename)
            % Ignore incomplete/invalid requests without cancelling user input.
            pending = false;
            request = string(filename) + ".request";
            if ~isfile(request), return, end
            try
                identity = strip(fileread(request));
                pending = ~isempty(regexp(identity, '^[a-f0-9]{32}$', 'once'));
            catch
                % The broker may remove an expired request between checks.
            end
        end

        function publish(filename, url, requestId)
            arguments
                filename (1,1) string
                url (1,1) string
                requestId (1,1) string = ""
            end
            data = struct('protocol', 1, 'url', url, 'request_id', requestId);
            temporary = string(tempname(fileparts(filename)));
            cleanup = onCleanup(@() removeFile(temporary));
            writelines(jsonencode(data), temporary, Encoding="UTF-8");
            movefile(temporary, filename, 'f');
        end

        function published = respond(filename, createURL)
            arguments
                filename (1,1) string
                createURL (1,1) function_handle
            end
            published = false;
            request = filename + ".request";
            if ~isfile(request)
                return
            end
            claimed = string(tempname(fileparts(filename)));
            [ok, ~] = movefile(request, claimed);
            if ~ok
                return
            end
            cleanup = onCleanup(@() removeFile(claimed));
            requestId = strip(fileread(claimed));
            if isempty(regexp(requestId, '^[a-f0-9]{32}$', 'once'))
                return
            end
            kssolv.ui.browser.BrowserSession.publish(filename, createURL(), requestId);
            published = true;
        end
    end
end

function removeFile(filename)
if isfile(filename)
    delete(filename);
end
end
