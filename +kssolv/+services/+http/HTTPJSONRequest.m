classdef HTTPJSONRequest < handle
    %HTTPJSONREQUEST Cancellable HTTP jobs without JVM-dependent scheduling.
    % Docker uses the supervisor's authenticated, loopback-only Python worker.
    % Desktop sessions retain native MATLAB HTTP on their background pool.
    properties (SetAccess = private)
        State = 'queued'
        Error = []
        OutputArguments = {}
    end
    properties (Access = private)
        URL
        Headers
        Decode
        Complete
        WorkerURL
        WorkerToken
        Job = ""
        Future = []
        Monitor = []
        Started
    end
    methods
        function this = HTTPJSONRequest(url, headers, decode, complete)
            this.URL = url;
            this.Headers = headers;
            this.Decode = decode;
            this.Complete = complete;
            this.WorkerURL = string(getenv('KSSOLV_HTTP_WORKER_URL'));
            this.WorkerToken = string(getenv('KSSOLV_HTTP_WORKER_TOKEN'));
        end

        function start(this)
            this.Started = tic;
            if this.WorkerURL ~= ""
                data = struct('url', this.URL, 'headers', this.Headers);
                reply = webwrite(this.WorkerURL + "/requests", data, this.workerOptions());
                this.Job = string(reply.id);
            else
                if isdeployed && isKSSOLVOnline()
                    error('KSSOLV:HTTP:WorkerUnavailable', ...
                        'The Online HTTP worker is unavailable.');
                end
                this.Future = parfeval(backgroundPool, ...
                    @kssolv.services.http.HTTPJSONRequest.fetch, 1, this.URL, this.Headers);
            end
            this.Headers = [];
            this.State = 'running';
            this.Monitor = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.1, 'StartDelay', 0.05, 'BusyMode', 'drop', ...
                'Tag', 'KSSOLVSettingsConnection', ...
                'TimerFcn', @(~, ~) this.poll());
            start(this.Monitor);
        end

        function cancel(this)
            this.Complete = [];
            this.cleanup();
            this.State = 'finished';
        end

        function delete(this)
            this.cancel();
        end
    end
    methods (Access = protected)
        function restoreLegacyConfiguration(this, configuration)
            % Called only by the previous util.HTTPJSONRequest class name.
            % In-flight futures/timers cannot be resumed from a MAT file.
            names = intersect(fieldnames(configuration), ...
                {'URL', 'Headers', 'Decode', 'Complete', 'WorkerURL', ...
                'WorkerToken', 'State', 'Error', 'OutputArguments'});
            for index = 1:numel(names)
                this.(names{index}) = configuration.(names{index});
            end
            if strcmp(this.State, 'running')
                this.State = 'finished';
                this.Error = MException('KSSOLV:HTTP:InterruptedRequest', ...
                    'A running HTTP request cannot be resumed from a saved file. Start a new request.');
                this.OutputArguments = {};
            end
        end
    end
    methods (Access = private)
        function options = workerOptions(this)
            options = weboptions('Timeout', 2, 'MediaType', 'application/json', ...
                'ContentType', 'json', 'HeaderFields', ...
                {'Authorization', char("Bearer " + this.WorkerToken)});
        end

        function poll(this)
            try
                if toc(this.Started) >= 20
                    error('KSSOLV:HTTP:Timeout', 'The connection test timed out.');
                end
                if this.Job ~= ""
                    reply = webread(this.WorkerURL + "/requests/" + this.Job, this.workerOptions());
                    if string(reply.state) ~= "finished", return; end
                    if isfield(reply, 'error')
                        detail = reply.error;
                        switch string(detail.kind)
                            case "http"
                                error(sprintf('KSSOLV:HTTP:HTTP%dStatusCodeError', detail.status), ...
                                    'The service returned HTTP %d.', detail.status);
                            case "timeout"
                                error('KSSOLV:HTTP:Timeout', 'The connection test timed out.');
                            case "json"
                                error('KSSOLV:HTTP:InvalidJSON', 'Invalid model-list response.');
                            case "tls"
                                error('KSSOLV:HTTP:TLS', 'Secure connection failed.');
                            otherwise
                                error('KSSOLV:HTTP:ConnectionFailed', 'Connection failed.');
                        end
                    end
                    response = reply.response;
                else
                    wait(this.Future, 'finished', 0.001);
                    if ~strcmp(this.Future.State, 'finished'), return; end
                    if ~isempty(this.Future.Error), throw(this.Future.Error); end
                    response = this.Future.OutputArguments{1};
                end
                this.OutputArguments = {this.Decode(response)};
            catch exception
                this.Error = exception;
            end
            this.State = 'finished';
            this.cleanup();
            complete = this.Complete;
            this.Complete = [];
            if ~isempty(complete), complete(this); end
        end

        function cleanup(this)
            monitor = this.Monitor;
            this.Monitor = [];
            if ~isempty(monitor) && isvalid(monitor)
                stop(monitor); delete(monitor);
            end
            job = this.Job;
            this.Job = "";
            if job ~= ""
                try
                    options = this.workerOptions();
                    options.RequestMethod = 'delete';
                    webwrite(this.WorkerURL + "/requests/" + job, struct(), options);
                catch
                    % Worker bounds retained jobs and cancels them on shutdown.
                end
            end
            if ~isempty(this.Future)
                cancel(this.Future);
                this.Future = [];
            end
            this.Headers = [];
        end
    end
    methods (Static, Access = private)
        function response = fetch(url, headers)
            names = fieldnames(headers);
            pairs = cell(numel(names), 2);
            for index = 1:numel(names)
                pairs(index, :) = {names{index}, char(headers.(names{index}))};
            end
            response = webread(url, weboptions('Timeout', 10, ...
                'ContentType', 'json', 'UserAgent', 'KSSOLV-Toolbox', 'HeaderFields', pairs));
        end
    end
end
