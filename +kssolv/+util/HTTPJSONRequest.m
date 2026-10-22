classdef HTTPJSONRequest < kssolv.services.http.HTTPJSONRequest
    %HTTPJSONREQUEST Compatibility name for saved objects and external callers.
    properties (Access = private)
        % MATLAB binds private saved properties to their declaring class.
        % Retain only the old configuration slots so legacy MAT objects can
        % transfer them to the implementation; no HTTP logic lives here.
        URL
        Headers
        Decode
        Complete
        WorkerURL
        WorkerToken
    end
    methods
        function this = HTTPJSONRequest(url, headers, decode, complete)
            this@kssolv.services.http.HTTPJSONRequest(url, headers, decode, complete);
        end
    end

    methods (Static)
        function this = loadobj(state)
            if isstruct(state)
                this = kssolv.util.HTTPJSONRequest(state.URL, state.Headers, ...
                    state.Decode, state.Complete);
                this.restoreLegacyConfiguration(state);
            else
                this = state;
                if ~isempty(this.URL)
                    configuration = struct('URL', this.URL, 'Headers', this.Headers, ...
                        'Decode', this.Decode, 'Complete', this.Complete, ...
                        'WorkerURL', this.WorkerURL, 'WorkerToken', this.WorkerToken);
                    this.restoreLegacyConfiguration(configuration);
                else
                    this.restoreLegacyConfiguration(struct());
                end
            end
            % Keep credentials/callbacks only in the implementation. These
            % slots exist solely to recognize pre-move MAT object layouts.
            this.URL = [];
            this.Headers = [];
            this.Decode = [];
            this.Complete = [];
            this.WorkerURL = [];
            this.WorkerToken = [];
        end
    end
end
